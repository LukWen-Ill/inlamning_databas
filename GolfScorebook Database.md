# 1. Beskrivning av domänen / systemet

Databasen "GolfScorebook" är en exempeldatabase som modellerar ett digitalt golfscorekort. Databasen är normaliserad enligt tredje normalformen, med ett dokumenterat avsteg för att förbättra prestanda och integritet. Databasen hanterar spelarregistreringar, speldata och statistiksammanställning. All data är AI-genererad och modellerar verkliga rundor. Databasen är skapad i syfte att demonstrera praktiska tillämpningar av normaliseringsteori, data validering och integritet via foreign keys, constraints samt avancerade SQL-tekniker som vyer, CASE-uttryck, HAVING och stored procedures.

# 2. Översikt av databasen

Databasen är designad som ett OLTP-system (Online Transaction Processing) och är optimerat för frekventa INSERT/UPDATE-operationer och består av 9 tabeller organiserade i tre lager: 

1. **Information/Entities:** _Venues, Courses, Holes, HoleNotes._
2. **Metadata:** _Players, TeeSets._
3. **Transaktionsdata:** _Rounds, PlayerRounds, Scores._

## 2.1 Beskrivning av databasen _"GolfScorebook"_

**Venues:** Representerar golfanläggningar med geografisk placering. Separeras för att en anläggning kan ha flera Courses.
- _VenueID_ - tabellens primärnyckel.
- _VenueName
- _Country
- _Region
- _City

**Courses:** Representerar golfbanor som tillhör en specifik Venue.
- _CourseID_ - tabellens primärnyckel.
- _VenueID_ - foreign key.
- _CourseName
 
**Holes:** Beskriver varje hål på en Course, inklusive par, längd och index(svårighet).
- _CourseID_ - del av komposit primärnyckel + foreign key.
- _HoleNumber_ - del av komposit primärnyckel.
- _Par
- _Length
- _HoleIndex

**Players:** Innehåller information om spelare, hemmaklubb och handicap. Handicap används för att räkna ut hur många extra slag en Player har.

- _PlayerID_ - tabellens primärnyckel.
- _PlayerName
- _HomeVenueID_ - foreign key.
- _Handicap

**TeeSets:** Representerar tee-positioner med slope- och course rating. Används för att räkna ut hur många extra slag en Player har. 

- _TeeSetID_ - tabellens primärnyckel.
- _CourseID_ - foreign key.
- _TeeName
- _CourseRating
- _SlopeRating

**Rounds:** Representerar en spelad runda på en specifik bana och ett specifikt datum.

- _RoundID_ - tabellens primärnyckel.
- _CourseID_ - foreign key.
- _RoundName
- _RoundPlayed

**PlayerRounds:** Kopplar spelare till rundor och anger vilken tee som användes.

- _PlayerRoundID_ - tabellens primärnyckel.
- _RoundID_ - foreign key.
- _PlayerID_ - foreign key.
- _TeeSetID_ - foreign key.

**Scores:**  Innehåller slag, puttar och fairway-träffar per hål. Används för statistik-vyer.

- _ScoreID_ - tabellens primärnyckel.
- _PlayerRoundID_ - foreign key.
- _CourseID_ - del av foreign key mot Holes.
- _HoleNumber_ - del av foreign key mot Holes.
- _Strokes
- _Putts
- _FairwayHit

**HoleNotes:** Lagrar spelarens anteckningar kopplade till specifika hål.

- _HoleNoteID_ - tabellens primärnyckel.
- _PlayerID_ - foreign key.
- _CourseID_ - del av foreign key mot Holes.
- _HoleNumber_ - del av foreign key mot Holes.
- _NoteText

# 3. Relationer mellan tabellerna  
- En _Venue_ kan ha flera _Courses_. (1:M)
- En _Course_ har flera _Holes_.  (1:M)
- Flera _Players_ kan ha samma _Venue_ som hemmaklubb. (1:M)  
- En _Course_ har flera _TeeSets_ alternativ. (1:M) 
- På en _Course_ spelas flera _Rounds_. (1:M)  
- Ett _TeeSet_ kan användas av flera _PlayerRounds_. (1:M)
- En _Player_ kan delta i flera _Rounds_, och en _Round_ kan ha flera _Players_. Kombinationen _Player + Round + TeeSet_ lagras i _PlayerRounds_, där varje _PlayerRound_ kopplas till exakt ett _TeeSet_. (M:M)
- En _PlayerRound_ har flera _Scores_. (1:M) 
- Ett _Hole_ kan ha flera _Scores_. (1:M)
- Ett _Hole_ kan ha flera _HoleNotes_.  (1:M)
- En _Player_ kan ha flera  _HoleNotes_.  (1:M)

## 3.1 Motivering
Jag har separerat tabellerna för att undvika duplicerad data, göra strukturen tydlig och kunna bygga vidare på databasen utan att behöva ändra befintliga tabeller.
- _Venues_ och _Courses_ ligger i egna tabeller så att geografisk information om en anläggning inte behöver upprepas för varje bana.
- _Holes_ ligger separat för att varje hål ska kunna ha egna egenskaper som HoleIndex, Length etc.
- _Players_ och _TeeSets_ är separerade från transaktionsdata för att spelare och tee-konfigurationer ska kunna återanvändas.
- Relationen mellan _Players_ och _Rounds_ löses via _PlayerRounds_ för att hantera many-to-many i enlighet med 3NF och samtidigt kunna lagra extra information som vilket _TeeSet_ som användes.
- _Scores_ och _HoleNotes_ ligger i egna tabeller för att hålla den löpande score- och anteckningshistoriken frikopplad från den mer statiska strukturen, vilket gör databasen både mer lättläst och enklare att utöka.

# 4. Normalisering

Databasen följer 1NF genom att alla kolumner innehåller atomiska värden, till exempel lagras varje _Score_ som en egen rad utan listor eller sammanslagna fält. 2NF och 3NF uppfylls genom att alla icke-nyckelkolumner är direkt beroende av tabellens nyckel och inte av andra kolumner, och beräknade värden lagras inte utan räknas ut i vyer. Det enda medvetna undantaget är CourseID i Scores, som behålls för att kunna kopplas direkt till Holes och göra frågor enklare.

## 4.1 Avgränsningar

Jag har valt att inte lagra värden i tabeller som istället kan räknas via vyer. Till skillnad från exemplet “Köksglädje”, där kolumnen _TotalPrice_ lagras direkt i tabellen _TransactionDetails_ (_PriceAtPurchase_ * _Quantity_), beräknas motsvarande värden dynamiskt. Ett konkret exempel är IsGIR (Green in Regulation): i stället för att spara en boolesk kolumn i Scores-tabellen beräknas IsGIR i vyn ScoreDetails med ett CASE-uttryck baserat på Strokes, Putts och hålets Par. På så sätt undviker jag redundans, minskar risken för inkonsistent data och säkerställer att all statistik alltid utgår från den underliggande, normaliserade strukturen. Det följer principen av tredje normalformen "Alla kolumner som inte är nyckelkolumner ska vara direkt beroende av primärnyckeln och inte indirekt beroende av någon annan kolumn.” 


Jag har även gjort ett medvetet avsteg från tredje normalformen genom att behålla _CourseID_ direkt i _Scores_ trots att värdet egentligen kan hämtas via _PlayerRounds_ och _Rounds_. 
Jag använder en kompositnyckel (CourseID, HoleNumber) eftersom ett hål identifieras av både sitt nummer och vilken bana det tillhör. Detta förhindrar att en score av misstag kopplas till hålnummer från en annan bana, och gör foreign key-valideringen korrekt. Det speglar dessutom hur hål fungerar i verkligheten, hål #3 är inte unikt. 
Kompositnyckeln gör också vanliga SELECT-frågor kortare och snabbare, eftersom man slipper flera onödiga JOINs. 
Avsteget är därför både praktiskt och skapar ingen risk för dataredundans.

# 5. Datatyper

BOOLEAN för FairwayHit för att hålla modellen enkel och fokuserad på om fairway träffades eller inte. En ENUM-kolumn för missriktning (vänster/höger) skulle kunna införas i en vidareutvecklad version, men är onödig för de rapporter och vyer som ingår i detta projekt.

TINYINT för små heltal som HoleNumber, Par, Strokes och Putts eftersom dessa alltid ligger inom små intervall och TINYINT sparar lagringsutrymme när tabellen växer.

DECIMAL används för Handicap eftersom den typen ger exakt decimalprecision utan avrundningsfel, till skillnad från FLOAT, vilket är viktigt vid handicap-beräkningar.

TEXT används för NoteText eftersom anteckningar kan vara av varierande längd och TEXT tillåter flexibel lagring utan att en fast maxlängd behöver anges.

DATETIME i stället för DATE eftersom rundor i systemet behöver lagra både datum och tidpunkt, medan DATE endast sparar datumet.

VARCHAR för TeeName eftersom olika klubbar och länder använder både färger, siffror och egna benämningar, vilket kräver en flexibel texttyp.

## 5.1 Integritet och validering

Jag säkerställer datavalidering och integritet genom att använda foreign keys, NOT NULL och UNIQUE-constraints för att förhindra ogiltiga relationer och dubbletter. Foreign keys gör att tabeller som _Courses_, _PlayerRounds_ och _Scores_ bara kan peka på befintliga rader, och jag undviker medvetet ON DELETE CASCADE för att inte radera data av misstag. NOT NULL används för kolumner som alltid måste ha ett värde, och UNIQUE för att hindra dubbla registreringar, till exempel att samma venue inte kan förekomma två gånger i samma stad eller att en player inte kan registreras flera gånger i samma round.