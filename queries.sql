-- Updatera Handicap
CALL UpdatePlayerHandicap(3012, @calculated_hcp);

-- Två olika sätt att checka
SELECT @calculated_hcp AS CalculatedHandicap;

-- Två olika sätt att checka
SELECT 
    ROUND(AVG(TotalStrokes), 2) AS AVGbestScore
FROM (
    SELECT prs.TotalStrokes
    FROM PlayerRoundStats AS prs
    WHERE prs.PlayerID = 3012
    ORDER BY prs.TotalStrokes ASC
    LIMIT 8
) AS BestRounds;

SELECT 
    PlayerName,
    Handicap AS OldHandicap,
    ROUND(@calculated_hcp/8, 1) AS NewHandicap,
    ROUND((@calculated_hcp/8 - Handicap), 1) AS Difference
FROM Players 
WHERE PlayerID = 3012;

-- LIMIT 
SELECT 
    ROUND(AVG(TotalStrokes), 2) AS AVGbestScore
FROM (
    SELECT prs.TotalStrokes
    FROM PlayerRoundStats AS prs
    WHERE prs.PlayerID = 3012
    ORDER BY prs.TotalStrokes ASC
    LIMIT 8
) AS BestRounds;