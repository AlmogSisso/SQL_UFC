use UFC;
go



-- ### סעיף מספר 1 ###
CREATE VIEW V_CurentCamp AS
SELECT 
    c.WeightClassName, f.FighterID, FirstName, f.NickName, f.LastName,
    DATEDIFF(DAY, c.ChampionStartDate, ISNULL(c.ChampionEndDate, '2023-11-11')) AS DaysAsChampion
FROM Championships c
JOIN Fighters f ON c.FighterID = f.FighterID
WHERE c.ChampionEndDate IS NULL;
go


-- ### סעיף מספר 2 ###
-- הכנה לסעיף 2
-- פונקציה שמקבל שם שם ושם משפחה של לוחם ומחזירה את המספר לוחם שלו
CREATE or alter FUNCTION Fn_GetFighterID
(
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50)
)
RETURNS INT
AS
BEGIN
    DECLARE @FighterID INT;
    
    SELECT TOP 1 @FighterID = FighterID 
    FROM Fighters 
    WHERE FirstName = @FirstName AND LastName = @LastName;
    
    RETURN ISNULL(@FighterID, -1);
END
GO

-- האם לוחם הוא אלוף
CREATE or alter FUNCTION fn_IsCurrentChampion(
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
	@WeightClassFight NVARCHAR(50)

)
RETURNS BIT
AS
BEGIN
    DECLARE @IsChampion BIT;
    DECLARE @FighterID INT;

    SET @FighterID = dbo.Fn_GetFighterID(@FirstName, @LastName);

    SELECT @IsChampion = CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM V_CurentCamp vc
            JOIN Fighters f ON vc.FighterID = f.FighterID
            WHERE vc.FighterID = @FighterID and @WeightClassFight = vc.WeightClassName
        ) THEN 1
        ELSE 0
    END;

    RETURN @IsChampion;
END;
GO

--בדיקה
SELECT dbo.fn_IsCurrentChampion('Islam', 'Makhachev', 'Lightweight') AS IsChampion;


-- ### סעיף מספר 3 ###
CREATE or alter PROCEDURE GetFightersByNationality
@Nationality NVARCHAR(100)
AS
    SELECT count(*) as NumbeOfFighters
    FROM Fighters
    WHERE Nationality = @Nationality;
GO


--נבדוק כמה לוחמים באים מארהב
EXECUTE GetFightersByNationality @Nationality = 'USA'
GO






-- ### סעיף מספר 4 ###
--- הכנסה של לוחם
CREATE OR ALTER PROCEDURE Pr_InsertNewFighter
    @FighterID INT,
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @NickName NVARCHAR(50),
    @DateOfBirth DATE,
    @JoinToUFC INT,
    @Nationality NVARCHAR(50),
    @HeightCm INT,
    @ReachCm INT,
    @WeightLbs INT,
    @NumOfWins INT = 0,
    @NumOfLosses INT = 0,
    @NumOfDraws INT = 0,
    @NumOfNoContests INT = 0,
    @Knockouts INT = 0,
    @Submissions INT = 0
AS
BEGIN
    INSERT INTO Fighters (FighterID, FirstName, LastName, NickName, DateOfBirth, JoinToUFC, Nationality, HeightCm, ReachCm, WeightLbs, NumOfWins, NumOfLosses, NumOfDraws, NumOfNoContests, Knockouts, Submissions)
    VALUES (@FighterID, @FirstName, @LastName, @NickName, @DateOfBirth, @JoinToUFC, @Nationality, @HeightCm, @ReachCm, @WeightLbs, @NumOfWins, @NumOfLosses, @NumOfDraws, @NumOfNoContests, @Knockouts, @Submissions)
END
GO

-- ### סעיף מספר 5 ###
-- הכנסה של אירוע חדש
CREATE or alter PROCEDURE InsertNewEvent
    @EventID INT,
    @EventName NVARCHAR(100),
    @EventDate DATE,
    @EventLocation NVARCHAR(100),
    @Country NVARCHAR(50)
AS
BEGIN
    INSERT INTO Events (EventID, EventName, EventDate, EventLocation, Country)
    VALUES (@EventID, @EventName, @EventDate, @EventLocation, @Country)
END
GO


-- ### סעיף מספר 6 ###
---- הכנסת קרב חדש 
CREATE OR ALTER PROCEDURE InsertNewFight
    @FightID NVARCHAR(50),
    @EventID INT,
    @Fighter1FirstName NVARCHAR(50),
    @Fighter1LastName NVARCHAR(50),
    @Fighter2FirstName NVARCHAR(50),
    @Fighter2LastName NVARCHAR(50),
    @WeightClassFight NVARCHAR(50),
    @WinnerFirstName NVARCHAR(50),
    @WinnerLastName NVARCHAR(50),
    @WinMethod NVARCHAR(50),
    @RoundNumber INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Fighter1ID INT, @Fighter2ID INT, @WinnerID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- השגת מזהה הלוחמים
        SET @Fighter1ID = dbo.Fn_GetFighterID(@Fighter1FirstName, @Fighter1LastName);
        SET @Fighter2ID = dbo.Fn_GetFighterID(@Fighter2FirstName, @Fighter2LastName);
        SET @WinnerID = dbo.Fn_GetFighterID(@WinnerFirstName, @WinnerLastName);

        -- בדיקה אם כל הלוחמים נמצאו
        IF @Fighter1ID = -1 OR @Fighter2ID = -1 OR @WinnerID = -1
        BEGIN
            THROW 50000, 'One or more of the fighters were not found in the system', 1;
        END

        -- הכנסת הקרב החדש
        INSERT INTO Fights (FightID, EventID, Fighter1ID, Fighter2ID, WeightClassFight, Winner, WinMethod, RoundNumber)
        VALUES (@FightID, @EventID, @Fighter1ID, @Fighter2ID, @WeightClassFight, @WinnerID, @WinMethod, @RoundNumber);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

-----טריגר לעידכון רקורד
CREATE OR ALTER TRIGGER UpdateFighterRecords
ON Fights
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WinnerID INT, @WinMethod NVARCHAR(50);
    DECLARE @Fighter1ID INT, @Fighter2ID INT;
    DECLARE @WinnerFirstName NVARCHAR(50), @WinnerLastName NVARCHAR(50);
    DECLARE @Fighter1FirstName NVARCHAR(50), @Fighter1LastName NVARCHAR(50);
    DECLARE @Fighter2FirstName NVARCHAR(50), @Fighter2LastName NVARCHAR(50);
    DECLARE @WeightClassFight NVARCHAR(50);

    SELECT @WinnerID = inserted.Winner,
           @WinMethod = inserted.WinMethod,
           @Fighter1ID = inserted.Fighter1ID,
           @Fighter2ID = inserted.Fighter2ID,
           @WeightClassFight = inserted.WeightClassFight,
           @WinnerFirstName = f1.FirstName,
           @WinnerLastName = f1.LastName,
           @Fighter1FirstName = f2.FirstName,
           @Fighter1LastName = f2.LastName,
           @Fighter2FirstName = f3.FirstName,
           @Fighter2LastName = f3.LastName
    FROM inserted
    JOIN Fighters f1 ON f1.FighterID = inserted.Winner
    JOIN Fighters f2 ON f2.FighterID = inserted.Fighter1ID
    JOIN Fighters f3 ON f3.FighterID = inserted.Fighter2ID;

    -- עדכון נתוני הלוחם המנצח
    UPDATE Fighters
    SET NumOfWins = NumOfWins + 1,
        Knockouts = CASE WHEN @WinMethod = 'KO/TKO' THEN Knockouts + 1 ELSE Knockouts END,
        Submissions = CASE WHEN @WinMethod = 'Submission' THEN Submissions + 1 ELSE Submissions END
    WHERE FighterID = @WinnerID;

    -- עדכון נתוני הלוחמים המפסידים
    UPDATE Fighters
    SET NumOfLosses = NumOfLosses + 1
    WHERE FighterID IN (@Fighter1ID, @Fighter2ID) AND FighterID != @WinnerID;

    -- הודעה על סיכום הקרב
    PRINT CONCAT(@WinnerFirstName, ' ', @WinnerLastName, ' defeated ', 
                 CASE WHEN @WinnerID = @Fighter1ID THEN CONCAT(@Fighter2FirstName, ' ', @Fighter2LastName) 
                      ELSE CONCAT(@Fighter1FirstName, ' ', @Fighter1LastName) END,                 
                 CASE WHEN dbo.fn_IsCurrentChampion(@Fighter1FirstName, @Fighter1LastName, @WeightClassFight) = 1 
                      OR dbo.fn_IsCurrentChampion(@Fighter2FirstName, @Fighter2LastName, @WeightClassFight) = 1 
                      THEN ' in a Championship Match' 
                      ELSE ' in a Regular Match' END,
                 ' via ', @WinMethod);
END;
GO

----טריגר לעידכון טבלה של אלופים
CREATE OR ALTER TRIGGER UpdateChampionships
ON Fights
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WinnerID INT, @WeightClass NVARCHAR(50), @EventDate DATE;
    DECLARE @WinnerFirstName NVARCHAR(50), @WinnerLastName NVARCHAR(50);
    DECLARE @Fighter1FirstName NVARCHAR(50), @Fighter1LastName NVARCHAR(50);
    DECLARE @Fighter2FirstName NVARCHAR(50), @Fighter2LastName NVARCHAR(50);
    DECLARE @IsChampionFight BIT = 0;
    DECLARE @CurrentChampionID INT;
    DECLARE @ChampionshipMessage NVARCHAR(200);

    SELECT @WinnerID = inserted.Winner,
           @WeightClass = inserted.WeightClassFight,
           @EventDate = e.EventDate,
           @WinnerFirstName = f1.FirstName,
           @WinnerLastName = f1.LastName,
           @Fighter1FirstName = f2.FirstName,
           @Fighter1LastName = f2.LastName,
           @Fighter2FirstName = f3.FirstName,
           @Fighter2LastName = f3.LastName
    FROM inserted
    JOIN Events e ON e.EventID = inserted.EventID
    JOIN Fighters f1 ON f1.FighterID = inserted.Winner
    JOIN Fighters f2 ON f2.FighterID = inserted.Fighter1ID
    JOIN Fighters f3 ON f3.FighterID = inserted.Fighter2ID;

    -- בדיקה אם אחד המשתתפים הוא האלוף הנוכחי במשקל המדובר
    IF dbo.fn_IsCurrentChampion(@Fighter1FirstName, @Fighter1LastName, @WeightClass) = 1
    BEGIN
        SET @IsChampionFight = 1;
        SET @CurrentChampionID = dbo.Fn_GetFighterID(@Fighter1FirstName, @Fighter1LastName);
    END
    ELSE IF dbo.fn_IsCurrentChampion(@Fighter2FirstName, @Fighter2LastName, @WeightClass) = 1
    BEGIN
        SET @IsChampionFight = 1;
        SET @CurrentChampionID = dbo.Fn_GetFighterID(@Fighter2FirstName, @Fighter2LastName);
    END

    IF @IsChampionFight = 1
    BEGIN
        -- האלוף הגן בהצלחה על התואר
        IF @CurrentChampionID = @WinnerID
        BEGIN
            SET @ChampionshipMessage = CONCAT(@WinnerFirstName, ' ', @WinnerLastName, 
                ' successfully defended the ', @WeightClass, ' championship');
        END
        ELSE -- מתמודד חדש זכה באליפות
        BEGIN
            -- עדכון תאריך סיום האליפות של האלוף הקודם
            UPDATE Championships
            SET ChampionEndDate = @EventDate
            WHERE WeightClassName = @WeightClass AND ChampionEndDate IS NULL;

            -- הכנסת רשומת אלוף חדשה
            INSERT INTO Championships (WeightClassName, FighterID, ChampionStartDate)
            VALUES (@WeightClass, @WinnerID, @EventDate);

            SET @ChampionshipMessage = CONCAT(@WinnerFirstName, ' ', @WinnerLastName, 
                ' is the new ', @WeightClass, ' champion!');
        END

        -- הדפסת ההודעה למסך
        PRINT @ChampionshipMessage;
    END;
END;
GO

--####################הכנסה של נתונים#########################
--################ הכנסה 2 לוחמים חדשים ######################
	---- הכנסה של בורה
EXEC Pr_InsertNewFighter
    @FighterID = 2001, 
    @FirstName = 'Almog', 
    @LastName = 'Bura', 
    @NickName = 'The Tribal Chief', 
    @DateOfBirth = '1995-01-09', 
    @JoinToUFC = 2024, 
    @Nationality = 'Israel', 
    @HeightCm = 173, 
    @ReachCm = 183, 
    @WeightLbs = 140,
    @NumOfWins = 10,
    @NumOfLosses = 1,
    @NumOfDraws = 2,
    @NumOfNoContests = 2,
    @Knockouts = 2,
    @Submissions = 4
GO

-- הכנסה של סיסו
EXEC Pr_InsertNewFighter
    @FighterID = 2000, 
    @FirstName = 'Almog', 
    @LastName = 'Sisso', 
    @NickName = 'The Calculator', 
    @DateOfBirth = '1994-03-15', 
    @JoinToUFC = 2024, 
    @Nationality = 'Israel', 
    @HeightCm = 170, 
    @ReachCm = 175, 
    @WeightLbs = 160,
    @NumOfWins = 15,
    @NumOfLosses = 2,
    @NumOfDraws = 0,
    @NumOfNoContests = 0,
    @Knockouts = 2,
    @Submissions = 8
go

---################ יצירה של  אירועים חדשים###################
-- לצורך יצירה קרב  חדש , נדרש ליצור קודם אירוע
EXEC InsertNewEvent 
    @EventID = 500, 
    @EventName = 'UFC 500: Sisso Vs Makhachev', 
    @EventDate = '2024-12-31', 
    @EventLocation = 'Menora', 
    @Country = 'Israel'
go

EXEC InsertNewEvent 
    @EventID = 502, 
    @EventName = 'UFC 502: Sisso Vs Bura', 
    @EventDate = '2025-01-01', 
    @EventLocation = 'Menora', 
    @Country = 'Israel'
go


---############הכנסה של קרבות ###############
--קרב מול אלוף, נהיה אלוף חדש
EXEC InsertNewFight 
	@FightID = '500A', 
    @EventID = 500, 
    @Fighter1FirstName = 'Almog', 
    @Fighter1LastName = 'Sisso',
    @Fighter2FirstName = 'Islam', 
    @Fighter2LastName = 'Makhachev',
    @WeightClassFight = 'Lightweight',
    @WinnerFirstName = 'Almog', 
    @WinnerLastName = 'Sisso',
    @WinMethod = 'Submission',
    @RoundNumber = 3
go

-- קרב רגיל
EXEC InsertNewFight 
	@FightID = '500B', 
    @EventID = 500, 
    @Fighter1FirstName = 'Almog', 
    @Fighter1LastName = 'Bura',
    @Fighter2FirstName = 'Khabib', 
    @Fighter2LastName = 'Nurmagomedov',
    @WeightClassFight = 'Lightweight',
    @WinnerFirstName = 'Almog', 
    @WinnerLastName = 'Bura',
    @WinMethod = 'KO/TKO',
    @RoundNumber = 4


-- קרב מול אלוף , האלוף הגן על התואר
EXEC InsertNewFight 
	@FightID = '502A', 
    @EventID = 502, 
    @Fighter1FirstName = 'Almog', 
    @Fighter1LastName = 'Bura',
    @Fighter2FirstName = 'Almog', 
    @Fighter2LastName = 'Sisso',
    @WeightClassFight = 'Lightweight',
    @WinnerFirstName = 'Almog', 
    @WinnerLastName = 'Sisso',
    @WinMethod = 'KO/TKO',
    @RoundNumber = 4

-- קרב מול אלוף בקטגורית משקל שונה מחגורת האליפות, האלוף מפסיד אבל לא מאבד את התואר, ולכן נשאר אלוף	
EXEC InsertNewFight 
	@FightID = '502B', 
    @EventID = 502, 
    @Fighter1FirstName = 'Jon', 
    @Fighter1LastName = 'Jones',
    @Fighter2FirstName = 'Islam', 
    @Fighter2LastName = 'Makhachev',
    @WeightClassFight = 'Lightweight',
    @WinnerFirstName = 'Islam', 
    @WinnerLastName = 'Makhachev',
    @WinMethod = 'KO/TKO',
    @RoundNumber = 2	

-- סיף סעיף 6


-- ### סעיף מספר 7 ###
-- מקבל מספר מזהה, מחזירה שם פרטי
CREATE OR ALTER FUNCTION Fn_GetFighterFirstName
(
    @FighterID INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @FirstName NVARCHAR(50);
    
    SELECT @FirstName = FirstName
    FROM Fighters
    WHERE FighterID = @FighterID;
    
    RETURN ISNULL(@FirstName, N'Unknown');
END;
GO

-- מקבל מספר מזהה, מחזירה שם משפחה
CREATE OR ALTER FUNCTION Fn_GetFighterLastName
(
    @FighterID INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @LastName NVARCHAR(50);
    
    SELECT @LastName = LastName
    FROM Fighters
    WHERE FighterID = @FighterID;
    
    RETURN ISNULL(@LastName, N'Unknown');
END;
GO

-- יצירה של קרב רנדומלי  
CREATE OR ALTER PROCEDURE InsertRandomFight
    @FightID NVARCHAR(50),
    @EventID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Fighter1ID INT, @Fighter2ID INT, @WinnerID INT;
    DECLARE @Fighter1FirstName NVARCHAR(50), @Fighter1LastName NVARCHAR(50);
    DECLARE @Fighter2FirstName NVARCHAR(50), @Fighter2LastName NVARCHAR(50);
    DECLARE @WinnerFirstName NVARCHAR(50), @WinnerLastName NVARCHAR(50);
    DECLARE @RoundNumber INT;
    DECLARE @WinMethod NVARCHAR(50);
    DECLARE @WeightClass NVARCHAR(50);

    -- בחירת מספר סיבוב רנדומלי (בין 1 ל-5)
    SET @RoundNumber = FLOOR(RAND() * 5) + 1;

    -- בחירת שיטת ניצחון רנדומלית
    SET @WinMethod = CASE 
        WHEN RAND() < 0.5 THEN 'KO/TKO'
        ELSE 'Submission'
    END;

    -- בחירת לוחם ראשון רנדומלי
    SET @Fighter1ID = FLOOR(RAND() * (1068 - 1000) + 1000);
    SET @Fighter1FirstName = dbo.Fn_GetFighterFirstName(@Fighter1ID);
    SET @Fighter1LastName = dbo.Fn_GetFighterLastName(@Fighter1ID);

    -- בחירת לוחם שני רנדומלי (שונה מהראשון)
    SET @Fighter2ID = @Fighter1ID;
    WHILE @Fighter2ID = @Fighter1ID
    BEGIN
        SET @Fighter2ID = FLOOR(RAND() * (1068 - 1000) + 1000);
    END
    SET @Fighter2FirstName = dbo.Fn_GetFighterFirstName(@Fighter2ID);
    SET @Fighter2LastName = dbo.Fn_GetFighterLastName(@Fighter2ID);

    -- בחירת קטגוריית משקל רנדומלית
    SET @WeightClass = CASE FLOOR(RAND() * 8)
        WHEN 0 THEN 'Flyweight'
        WHEN 1 THEN 'Bantamweight'
        WHEN 2 THEN 'Featherweight'
        WHEN 3 THEN 'Lightweight'
        WHEN 4 THEN 'Welterweight'
        WHEN 5 THEN 'Middleweight'
        WHEN 6 THEN 'Light Heavyweight'
        ELSE 'Heavyweight'
    END;

    -- בחירת מנצח רנדומלי בין שני הלוחמים
    IF RAND() < 0.5
    BEGIN
        SET @WinnerID = @Fighter1ID;
        SET @WinnerFirstName = @Fighter1FirstName;
        SET @WinnerLastName = @Fighter1LastName;
    END
    ELSE
    BEGIN
        SET @WinnerID = @Fighter2ID;
        SET @WinnerFirstName = @Fighter2FirstName;
        SET @WinnerLastName = @Fighter2LastName;
    END

    -- הכנסת הקרב החדש
    EXEC InsertNewFight 
        @FightID = @FightID, 
        @EventID = @EventID, 
        @Fighter1FirstName = @Fighter1FirstName, 
        @Fighter1LastName = @Fighter1LastName,
        @Fighter2FirstName = @Fighter2FirstName, 
        @Fighter2LastName = @Fighter2LastName,
        @WeightClassFight = @WeightClass,
        @WinnerFirstName = @WinnerFirstName, 
        @WinnerLastName = @WinnerLastName,
        @WinMethod = @WinMethod,
        @RoundNumber = @RoundNumber;

    -- הדפסת פרטי הקרב שנוצר
    PRINT 'New fight created:';
    PRINT 'Fight ID: ' + @FightID;
    PRINT 'Event ID: ' + CAST(@EventID AS NVARCHAR(10));
    PRINT 'Fighter 1: ' + @Fighter1FirstName + ' ' + @Fighter1LastName;
    PRINT 'Fighter 2: ' + @Fighter2FirstName + ' ' + @Fighter2LastName;
    PRINT 'Winner: ' + @WinnerFirstName + ' ' + @WinnerLastName;
    PRINT 'Win Method: ' + @WinMethod;
    PRINT 'Round: ' + CAST(@RoundNumber AS NVARCHAR(2));
END;
GO

--הרצה לבדיקה
EXEC InsertRandomFight @FightID = 'F1002', @EventID = 500;
GO
-- סוף סעיף 7


-- ### סעיף מספר 8 ###
--- סטטיסטיקה של הלוחמים
CREATE or alter VIEW V_FightersStats AS
SELECT 
    f.FighterID, 
    f.FirstName, 
    f.LastName,
    -- חישוב אחוז הניצחונות עם טיפול במקרה של אפס קרבות
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfWins * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS WinRate,
    -- חישוב אחוז ההפסדים
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfLosses * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS LossRate,
    -- חישוב אחוז התיקו
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfDraws * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS DrawRate,
    -- חישוב אחוז הנוקאאוטים מתוך הניצחונות
    CASE 
        WHEN NumOfWins = 0 THEN '0.0'
        ELSE FORMAT(ROUND((Knockouts * 100.0) / NULLIF(NumOfWins, 0), 1), 'N1')
    END AS KORate,
    -- חישוב אחוז הכניעות מתוך הניצחונות
    CASE 
        WHEN NumOfWins = 0 THEN '0.0'
        ELSE FORMAT(ROUND((Submissions * 100.0) / NULLIF(NumOfWins, 0), 1), 'N1')
    END AS SubmissionsRate
FROM Fighters f
go



-- CTE לחיבור נתוני הלוחמים עם קטגוריות המשקל והסטטיסטיקות
WITH FighterStats AS (
    SELECT 
        f.FighterID,
        f.FirstName,
        f.LastName,
        f.WeightLbs,
        -- בחירת קטגוריית המשקל המתאימה ביותר
        (SELECT TOP 1 WeightClassName
         FROM WeightClass wc
         WHERE f.WeightLbs <= wc.MaxWeight
         ORDER BY wc.MaxWeight) AS WeightClassName,
        CAST(NULLIF(vs.WinRate, 'N/A') AS FLOAT) AS WinRate
    FROM Fighters f
    LEFT JOIN V_FightersStats vs ON f.FighterID = vs.FighterID
),
-- דירוג הלוחמים בכל קטגוריית משקל ובכלל
RankedFighters AS (
    SELECT 
        WeightClassName,
        FirstName,
        LastName,
        RANK() OVER (PARTITION BY WeightClassName ORDER BY WinRate DESC) AS RankInWeightClass,
        RANK() OVER (ORDER BY WinRate DESC) AS PoundForPoundRank
    FROM FighterStats
    WHERE WinRate IS NOT NULL
),
-- בחירת 5 הלוחמים המובילים בכל קטגוריית משקל
TopFighters AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY WeightClassName ORDER BY RankInWeightClass) AS RowNum
    FROM RankedFighters
    WHERE RankInWeightClass <= 5
)
-- תוצאה סופית
SELECT 
    WeightClassName,
    RankInWeightClass,
    PoundForPoundRank,
    FirstName,
    LastName
FROM TopFighters
WHERE RowNum <= 5
ORDER BY WeightClassName, RankInWeightClass;
-- סוף סעיף 8
go





-- ### סעיף מספר 9 ###
-- פונקציה לחישוב בונוס ללוחמים
CREATE OR ALTER FUNCTION Fn_CalculateFighterEarnings
(
    @KnockoutBonus INT,
    @SubmissionBonus INT,
    @DecisionBonus INT,
    @DrawPenalty INT
)
RETURNS @Results TABLE 
(
    FighterID INT,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Knockouts INT,
    Submissions INT,
    DecisionWins INT,
    Draws INT,
    Losses INT,
    TotalFights INT,
    TotalEarnings INT
)
AS
BEGIN
    INSERT INTO @Results
    SELECT 
        fr.FighterID,
        fr.FirstName,
        fr.LastName,
        fr.Knockouts,
        fr.Submissions,
        fr.DecisionWins,
        fr.Draws,
        fr.Losses,
        fr.TotalFights,
        (fr.Knockouts * @KnockoutBonus + 
         fr.Submissions * @SubmissionBonus + 
         fr.DecisionWins * @DecisionBonus - 
         fr.Draws * @DrawPenalty) AS TotalEarnings
    FROM 
    (
        SELECT 
            f.FighterID,
            f.FirstName,
            f.LastName,
            SUM(CASE WHEN ft.Winner = f.FighterID AND (ft.WinMethod = 'KO' OR ft.WinMethod = 'TKO') THEN 1 ELSE 0 END) AS Knockouts,
            SUM(CASE WHEN ft.Winner = f.FighterID AND ft.WinMethod = 'Submission' THEN 1 ELSE 0 END) AS Submissions,
            SUM(CASE WHEN ft.Winner = f.FighterID AND ft.WinMethod = 'Decision' THEN 1 ELSE 0 END) AS DecisionWins,
            SUM(CASE WHEN ft.WinMethod = '-' THEN 1 ELSE 0 END) AS Draws,
            SUM(CASE WHEN ft.Winner IS NOT NULL AND ft.Winner != f.FighterID THEN 1 ELSE 0 END) AS Losses,
            COUNT(ft.FightID) AS TotalFights
        FROM 
            Fighters f
        LEFT JOIN 
            Fights ft ON f.FighterID = ft.Fighter1ID OR f.FighterID = ft.Fighter2ID
        GROUP BY 
            f.FighterID, f.FirstName, f.LastName
    ) fr
    RETURN
END
GO

-- פונקציה ליצירת טבלת התוצאות
CREATE OR ALTER PROCEDURE Pr_CreateFighterEarningsTable
AS
BEGIN
    CREATE TABLE Tbl_FighterEarnings
    (
        FighterID INT,
        FirstName NVARCHAR(50),
        LastName NVARCHAR(50),
        Knockouts INT,
        Submissions INT,
        DecisionWins INT,
        Draws INT,
        Losses INT,
        TotalFights INT,
        TotalEarnings INT
    )
END
GO

-- פונקציה למחיקת טבלת התוצאות
CREATE  or alter PROCEDURE Pr_DeleteFighterEarningsTable
AS
BEGIN
    IF OBJECT_ID('dbo.Tbl_FighterEarnings', 'U') IS NOT NULL
        DROP TABLE dbo.Tbl_FighterEarnings
END
GO

-- פרוצדורת "על" שמפעילה את כל האחרים
CREATE OR ALTER PROCEDURE Pr_ProcessFighterEarnings
    @KnockoutBonus INT,
    @SubmissionBonus INT,
    @DecisionBonus INT,
    @DrawPenalty INT
AS
BEGIN
    -- 1. מחיקת הטבלה אם היא קיימת
    IF OBJECT_ID('dbo.Tbl_FighterEarnings', 'U') IS NOT NULL
        DROP TABLE dbo.Tbl_FighterEarnings

    -- 2. יצירת הטבלה מחדש
    EXEC dbo.Pr_CreateFighterEarningsTable

    -- 3. הכנסת הנתונים לטבלה
    INSERT INTO dbo.Tbl_FighterEarnings
    SELECT * FROM dbo.Fn_CalculateFighterEarnings(@KnockoutBonus, @SubmissionBonus, @DecisionBonus, @DrawPenalty)
    WHERE TotalEarnings <> 0
    ORDER BY TotalEarnings DESC

    -- הצגת התוצאות
    SELECT * FROM dbo.Tbl_FighterEarnings 
    WHERE TotalEarnings <> 0  
    ORDER BY TotalEarnings DESC

    -- הדפסת שם הטבלה
    PRINT 'Table Name: dbo.Tbl_FighterEarnings'
END
GO

--שימוש בפונקציית ה"על"
EXEC dbo.Pr_ProcessFighterEarnings 200000, 150000, 100000, 50000

-- סוף סעיף 9
go



-- ### סעיף מספר 10 ###
--קונפיגורציה
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
 sp_configure 'xp_cmdshell', '1' 
reconfigure with override
GO




-- שמירה לקובץ אקסל
CREATE or alter PROCEDURE BackupTableToExcel
    @TableName NVARCHAR(50)
AS
BEGIN
    DECLARE @FileName NVARCHAR(255), @TempFileName NVARCHAR(255)
    DECLARE @Command NVARCHAR(500), @DirCommand NVARCHAR(500), @HeaderCommand NVARCHAR(500)
    DECLARE @Columns NVARCHAR(MAX)
    
    -- יצירת תיקיית AlmogSQL
    SET @DirCommand = 'if not exist "c:\AlmogSQL" mkdir "c:\AlmogSQL"'
    EXEC xp_cmdshell @DirCommand

    -- יצירת תת-תיקייה לפי שם מסד הנתונים
    SET @DirCommand = 'if not exist "c:\AlmogSQL\' + 'OutputData' + '" mkdir "c:\AlmogSQL\' + 'OutputData' + '"'
    EXEC xp_cmdshell @DirCommand

    SET @FileName = 'c:\AlmogSQL\' + 'OutputData' + '\' + @TableName + '.csv'
    SET @TempFileName = 'c:\AlmogSQL\' + 'OutputData' + '\' + @TableName + '_temp.csv'
    
    -- קבלת רשימת הכותרות
    SELECT @Columns = STRING_AGG(QUOTENAME(column_name), ',')
    FROM information_schema.columns
    WHERE table_name = @TableName AND table_schema = 'dbo'

    -- יצירת קובץ הכותרות והוספתן לקובץ הסופי
    SET @HeaderCommand = 'echo ' + @Columns + ' > "' + @FileName + '"'
    EXEC xp_cmdshell @HeaderCommand

    -- ייצוא תוכן הטבלה לקובץ CSV זמני
    SET @Command = 'bcp ' + QUOTENAME(DB_NAME()) + '.dbo.' + QUOTENAME(@TableName) + 
                   ' out "' + @TempFileName + '" -c -t, -T -S ' + @@SERVERNAME
    EXEC xp_cmdshell @Command

    -- איחוד קובץ הכותרות וקובץ התוכן
    SET @Command = 'type "' + @TempFileName + '" >> "' + @FileName + '"'
    EXEC xp_cmdshell @Command

    -- מחיקת קובץ התוכן הזמני
    SET @Command = 'del "' + @TempFileName + '"'
    EXEC xp_cmdshell @Command

    PRINT 'Backup completed: ' + @FileName
END
GO

-- הפעלה   
EXEC BackupTableToExcel 'Tbl_FighterEarnings'
go


-- ### סעיף מספר 11 ###
--- קריאה מקובץ CSV 
BULK INSERT [dbo].[Fighters]
	FROM 'C:\AlmogSQL\Insertdata\DataForInsertInQuery.csv'   
	WITH 
       ( 
		CODEPAGE = 'ACP',  -- לאפשר עברית
		FIRSTROW = 2 ,  -- שורת כותרות
		MAXERRORS = 0 , -- לא לאפשר שגיאות
        FIELDTERMINATOR = ',', -- מפריד בין שדות
        ROWTERMINATOR = '\n'  -- new line
       )
GO

--בדיקה
select *
from Fighters






-- ### סעיף מספר 12 ###
CREATE OR ALTER PROCEDURE AnalyzeUFCMartialArts
AS
BEGIN
    SET NOCOUNT ON;

    -- מחיקת טבלאות זמניות אם הן קיימות
    IF OBJECT_ID('tempdb..#PopularityResults') IS NOT NULL
        DROP TABLE #PopularityResults;
    
    IF OBJECT_ID('tempdb..#CumulativeCounts') IS NOT NULL
        DROP TABLE #CumulativeCounts;

    -- הגדרת משתנים
    DECLARE @StartYear INT;
    DECLARE @EndYear INT;
    DECLARE @CurrentYear INT;

    -- מציאת שנת ההתחלה (השנה המוקדמת ביותר ב-JoinToUFC)
    SELECT @StartYear = MIN(JoinToUFC)
    FROM Fighters;

    -- מציאת שנת הסיום (השנה המאוחרת ביותר ב-JoinToUFC)
    SELECT @EndYear = MAX(JoinToUFC)
    FROM Fighters;

    SET @CurrentYear = @StartYear;

    -- יצירת טבלה זמנית לאחסון התוצאות
    CREATE TABLE #PopularityResults (
        Year INT,
        MartialArt NVARCHAR(50),
        NewFighterCount INT,
        Percentage DECIMAL(5,2),
        CumulativeFighters INT,
        CumulativePercentage DECIMAL(5,2)
    );

    -- יצירת טבלה זמנית לאחסון הסכומים המצטברים
    CREATE TABLE #CumulativeCounts (
        MartialArt NVARCHAR(50),
        TotalFighters INT
    );

    -- לולאה על פני השנים
    WHILE @CurrentYear <= @EndYear
    BEGIN
        -- מציאת סך כל הלוחמים החדשים בשנה הנוכחית
        DECLARE @NewFighters INT;
        SELECT @NewFighters = COUNT(DISTINCT FighterID)
        FROM Fighters
        WHERE JoinToUFC = @CurrentYear;

        -- הכנסת נתונים לטבלה הזמנית
        INSERT INTO #PopularityResults (Year, MartialArt, NewFighterCount, Percentage)
        SELECT 
            @CurrentYear,
            MA.WarriorStyles,
            COUNT(DISTINCT MA.FighterID) AS NewFighterCount,
            CASE 
                WHEN @NewFighters > 0 THEN CAST(COUNT(DISTINCT MA.FighterID) AS DECIMAL(5,2)) / @NewFighters * 100 
                ELSE 0 
            END AS Percentage
        FROM MartialArts MA
        JOIN Fighters F ON MA.FighterID = F.FighterID
        WHERE F.JoinToUFC = @CurrentYear
        GROUP BY MA.WarriorStyles;

        -- עדכון הסכומים המצטברים
        MERGE INTO #CumulativeCounts AS Target
        USING (SELECT MartialArt, NewFighterCount FROM #PopularityResults WHERE Year = @CurrentYear) AS Source
        ON Target.MartialArt = Source.MartialArt
        WHEN MATCHED THEN
            UPDATE SET Target.TotalFighters = Target.TotalFighters + Source.NewFighterCount
        WHEN NOT MATCHED THEN
            INSERT (MartialArt, TotalFighters) VALUES (Source.MartialArt, Source.NewFighterCount);

        -- עדכון הנתונים המצטברים בטבלת התוצאות
        UPDATE PR
        SET 
            PR.CumulativeFighters = CC.TotalFighters,
            PR.CumulativePercentage = CAST(CC.TotalFighters AS DECIMAL(5,2)) / 
                (SELECT SUM(NewFighterCount) FROM #PopularityResults WHERE Year <= @CurrentYear) * 100
        FROM #PopularityResults PR
        JOIN #CumulativeCounts CC ON PR.MartialArt = CC.MartialArt
        WHERE PR.Year = @CurrentYear;

        -- מעבר לשנה הבאה
        SET @CurrentYear = @CurrentYear + 1;
    END;

    -- הצגת התוצאות
    SELECT * FROM #PopularityResults
    ORDER BY Year, Percentage DESC;


END;

EXEC AnalyzeUFCMartialArts;

-- סוף סעיף 12



-- ### סעיף מספר 13 ###
--קונפיגורציה
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
sp_configure 'xp_cmdshell', '1' 
reconfigure with override
GO

--(גיבוי לפי תיקיה שאני בוחר, גיבוי לפי תאריך של היום(של האירוע
CREATE or ALTER PROC proc_backup_database
 @P_Path nvarchar(50),
 @DateForBackUps date
AS
Declare @Disk_path varchar(100)
-- יצירת תיקיה רצויה
Declare @dir varchar(50)
Set @dir = 'MD ' + @P_Path 
Print @dir
EXEC  xp_cmdshell  @dir
-----
SET @DIsk_path = @p_path  + 'UFC' + convert(char(10),@DateForBackUps ,102) + '.bak'
PRINT @Disk_path
BACKUP DATABASE UFC
TO DISK=@Disk_path
WITH FORMAT
GO

Exec proc_backup_database 'C:\AlmogSQL\BackUps\' ,'2022-02-02'
GO

----שיחזור
CREATE OR ALTER PROC proc_restore_database
    @P_Path nvarchar(255),
    @DateForRestore date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Disk_path nvarchar(500)
    DECLARE @SQL nvarchar(1000)
    DECLARE @ErrorMessage nvarchar(1000)
    
    -- בניית נתיב הקובץ
    SET @Disk_path = @P_Path + 'UFC' + CONVERT(char(10), @DateForRestore, 102) + '.bak'
    
    -- הדפסת הנתיב לבדיקה
    PRINT 'נתיב קובץ הגיבוי: ' + @Disk_path
    
    BEGIN TRY
        -- מחיקת מסד הנתונים אם קיים
        IF EXISTS (SELECT name FROM sys.databases WHERE name = 'UFC')
        BEGIN
            SET @SQL = 'ALTER DATABASE UFC SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                        DROP DATABASE UFC;'
            EXEC sp_executesql @SQL
            PRINT 'מסד הנתונים UFC נמחק'
        END
        
        -- שחזור מסד הנתונים
        SET @SQL = 'RESTORE DATABASE UFC FROM DISK = ''' + @Disk_path + ''' WITH REPLACE'
        EXEC sp_executesql @SQL
        
        PRINT 'מסד הנתונים UFC שוחזר בהצלחה'
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE()
        PRINT 'שגיאה בשחזור מסד הנתונים: ' + @ErrorMessage
        RETURN -1
    END CATCH
END
GO

use master
EXEC proc_restore_database 'C:\AlmogSQL\BackUps\', '2022-02-02'
GO

use ufc
go

