CREATE DATABASE lukas_wennstrom_inmaning;

USE lukas_wennstrom_inmaning;

CREATE TABLE Venues (
    VenueID INT AUTO_INCREMENT PRIMARY KEY,
    VenueName VARCHAR(100) NOT NULL,
    Country VARCHAR(50) NOT NULL,
    Region VARCHAR(50) NOT NULL,
    City VARCHAR(50) NOT NULL
);

CREATE TABLE Courses (
	CourseID INT AUTO_INCREMENT PRIMARY KEY,
	VenueID INT NOT NULL,
	CourseName VARCHAR(100) NOT NULL,
	FOREIGN KEY (VenueID) REFERENCES Venues(VenueID)
);

-- Gör så att man inte kan lägga in dubletter av samma Venue/Course
ALTER TABLE Venues
ADD UNIQUE KEY unique_venue_location (VenueName, City);

ALTER TABLE Courses
ADD UNIQUE KEY unique_course_venue (VenueID, CourseName);

CREATE TABLE Holes (
    CourseID INT NOT NULL,
    HoleNumber TINYINT NOT NULL,
    Par INT NOT NULL,
    Length INT NOT NULL,
    HoleIndex INT NOT NULL,
    PRIMARY KEY (CourseID, HoleNumber),
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID)
);

CREATE TABLE Players (
    PlayerID INT NOT NULL PRIMARY KEY,
    PlayerName VARCHAR(100) NOT NULL,
    Handicap DECIMAL(5,1) NOT NULL DEFAULT 0,
    HomeVenueID INT NOT NULL,
    FOREIGN KEY (HomeVenueID) REFERENCES Venues(VenueID)
);

CREATE TABLE Rounds (
    RoundID INT AUTO_INCREMENT PRIMARY KEY,
    CourseID INT NOT NULL,
    RoundName VARCHAR(100),
    RoundPlayed DATETIME NOT NULL,
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID)
);
CREATE TABLE TeeSets (
	TeeSetID INT AUTO_INCREMENT PRIMARY KEY,
	CourseID INT NOT NULL,
	TeeName VARCHAR(100) NOT NULL,
	CourseRating DECIMAL(4,1) NOT NULL,
	SlopeRating SMALLINT NOT NULL,
	FOREIGN KEY (CourseID) REFERENCES Courses(CourseID),
	UNIQUE (CourseID, TeeName)
);

CREATE TABLE PlayerRounds (
	PlayerRoundID INT AUTO_INCREMENT PRIMARY KEY,
	RoundID INT NOT NULL,
	PlayerID INT NOT NULL,
	TeeSetID INT NOT NULL,
	UNIQUE (RoundID, PlayerID),
	FOREIGN KEY (RoundID)  REFERENCES Rounds(RoundID),
	FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID),
	FOREIGN KEY (TeeSetID) REFERENCES TeeSets(TeeSetID)
);

CREATE TABLE Scores (
	ScoreID INT AUTO_INCREMENT PRIMARY KEY,
	PlayerRoundID INT NOT NULL,
    CourseID INT NOT NULL,
	HoleNumber TINYINT NOT NULL,
	Strokes TINYINT NOT NULL,
	Putts TINYINT NOT NULL,
	FairwayHit BOOLEAN NOT NULL,
	FOREIGN KEY (PlayerRoundID) REFERENCES PlayerRounds (PlayerRoundID),
	FOREIGN KEY (CourseID, HoleNumber) REFERENCES Holes(CourseID, HoleNumber),
	UNIQUE (PlayerRoundID, HoleNumber)
);

CREATE TABLE HoleNotes (
	HoleNoteID INT AUTO_INCREMENT PRIMARY KEY,
	CourseID INT NOT NULL,
	HoleNumber TINYINT NOT NULL,
	PlayerID INT NOT NULL,
	NoteText TEXT,
	FOREIGN KEY (CourseID, HoleNumber) REFERENCES Holes(CourseID, HoleNumber),
	FOREIGN KEY (PlayerID) REFERENCES Players(PlayerID),
	UNIQUE (CourseID, HoleNumber, PlayerID) 
);

-- (CASE)
-- Rå Score-data för varje hål. 
-- All statistik och scorecards bygger på denna.
CREATE OR REPLACE VIEW ScoreDetails AS
SELECT 
    s.ScoreID,
    s.PlayerRoundID,
    s.CourseID,
    s.HoleNumber,
    s.Strokes,
    s.Putts,
    s.FairwayHit,
    h.Par,
    (s.Strokes - h.Par) AS ScoreToPar,
    CASE 
        WHEN (s.Strokes - s.Putts) <= (h.Par - 2) THEN 1 
        ELSE 0 
    END AS IsGIR,
	 CASE 
		WHEN s.Strokes = 1 THEN 'HIO'
		WHEN s.Strokes = h.Par - 3 THEN 'Albatross'
		WHEN s.Strokes = h.Par - 2 THEN 'Eagle'
		WHEN s.Strokes = h.Par - 1 THEN 'Birdie'
		WHEN s.Strokes = h.Par THEN 'Par'
		WHEN s.Strokes = h.Par + 1 THEN 'Bogey'
		WHEN s.Strokes = h.Par + 2 THEN 'Double Bogey'
		WHEN s.Strokes = h.Par + 3 THEN 'Triple Bogey'
		WHEN s.Strokes >= h.Par + 4 THEN 'Quadruple+ Bogey'
	END AS ScoreType
FROM Scores s
JOIN Holes h ON s.CourseID = h.CourseID AND s.HoleNumber = h.HoleNumber
ORDER BY s.ScoreID;

-- (Förenkadvy för SELECT)
-- (En JOIN som innefattar minst tre tabeller)
-- Samlad join för Players och TeeSets. 
-- Information om VEM som spelade en specifik runda. (Header)
CREATE OR REPLACE VIEW PlayerRoundDetails AS
SELECT 
    pr.PlayerRoundID,
    pr.PlayerID,
    pr.RoundID,
    pr.TeeSetID,
    p.PlayerName,
    p.Handicap,
    ts.TeeName
FROM PlayerRounds pr
JOIN Players p ON pr.PlayerID = p.PlayerID
JOIN TeeSets ts ON pr.TeeSetID = ts.TeeSetID;

-- (HAVING)
-- Aggregering av Spelade hål till en hel runda.
CREATE OR REPLACE VIEW PlayerRoundStats AS
SELECT 
    prd.PlayerRoundID,
    prd.PlayerID,
    prd.RoundID,
    COUNT(sd.ScoreID) AS HolesPlayed, -- Använder sig av SQL Funktioner såsom DATE, COUNT etc
    SUM(sd.Par) AS CoursePar,
    SUM(sd.Strokes) AS TotalStrokes,
    SUM(sd.ScoreToPar) AS StrokesVSPar,
    ROUND(AVG(sd.Strokes), 2) AS AvgStrokesPerHole,
    SUM(sd.Putts) AS TotalPutts,
    ROUND(AVG(sd.Putts), 2) AS AvgPuttsPerHole,
	SUM(sd.FairwayHit) AS FairwaysHit,
    ROUND(AVG(sd.FairwayHit) * 100, 1) AS FairwayHitPercentage,
    SUM(sd.IsGIR) AS GIRCount,
    ROUND(AVG(sd.IsGIR) * 100, 1) AS GIRPercentage,
    -- Om scoretype är X return 1, annars 0
    SUM(CASE WHEN sd.ScoreType = 'HIO' THEN 1 ELSE 0 END) AS HIO,
	SUM(CASE WHEN sd.ScoreType = 'Albatross' THEN 1 ELSE 0 END) AS Albatross,
	SUM(CASE WHEN sd.ScoreType = 'Eagle' THEN 1 ELSE 0 END) AS Eagles,
	SUM(CASE WHEN sd.ScoreType = 'Birdie' THEN 1 ELSE 0 END) AS Birdies,
	SUM(CASE WHEN sd.ScoreType = 'Par' THEN 1 ELSE 0 END) AS Pars,
	SUM(CASE WHEN sd.ScoreType = 'Bogey' THEN 1 ELSE 0 END) AS Bogeys,
	SUM(CASE WHEN sd.ScoreType = 'Double Bogey' THEN 1 ELSE 0 END) AS DoubleBogeys,
	SUM(CASE WHEN sd.ScoreType = 'Triple Bogey' THEN 1 ELSE 0 END) AS TripleBogeys,
	SUM(CASE WHEN sd.ScoreType = 'Quadruple+ Bogey' THEN 1 ELSE 0 END) AS QuadruplePlusBogeys
FROM PlayerRoundDetails prd
LEFT JOIN ScoreDetails sd ON prd.PlayerRoundID = sd.PlayerRoundID
GROUP BY prd.PlayerRoundID
HAVING HolesPlayed = 18;

-- Fritext sökningar (LIKE)
SELECT * FROM HoleNotes
WHERE NoteText
LIKE '%index%';