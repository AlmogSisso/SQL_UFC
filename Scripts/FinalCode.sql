use UFC;
go



-- ### ���� ���� 1 ###
CREATE VIEW V_CurentCamp AS
SELECT 
    c.WeightClassName, f.FighterID, FirstName, f.NickName, f.LastName,
    DATEDIFF(DAY, c.ChampionStartDate, ISNULL(c.ChampionEndDate, '2023-11-11')) AS DaysAsChampion
FROM Championships c
JOIN Fighters f ON c.FighterID = f.FighterID
WHERE c.ChampionEndDate IS NULL;
go


-- ### ���� ���� 2 ###
-- ���� ����� 2
-- ������� ����� �� �� ��� ����� �� ���� ������� �� ����� ���� ���
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

-- ��� ���� ��� ����
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

--�����
SELECT dbo.fn_IsCurrentChampion('Islam', 'Makhachev', 'Lightweight') AS IsChampion;


-- ### ���� ���� 3 ###
CREATE or alter PROCEDURE GetFightersByNationality
@Nationality NVARCHAR(100)
AS
    SELECT count(*) as NumbeOfFighters
    FROM Fighters
    WHERE Nationality = @Nationality;
GO


--����� ��� ������ ���� �����
EXECUTE GetFightersByNationality @Nationality = 'USA'
GO






-- ### ���� ���� 4 ###
--- ����� �� ����
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

-- ### ���� ���� 5 ###
-- ����� �� ����� ���
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


-- ### ���� ���� 6 ###
---- ����� ��� ��� 
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

        -- ���� ���� �������
        SET @Fighter1ID = dbo.Fn_GetFighterID(@Fighter1FirstName, @Fighter1LastName);
        SET @Fighter2ID = dbo.Fn_GetFighterID(@Fighter2FirstName, @Fighter2LastName);
        SET @WinnerID = dbo.Fn_GetFighterID(@WinnerFirstName, @WinnerLastName);

        -- ����� �� �� ������� �����
        IF @Fighter1ID = -1 OR @Fighter2ID = -1 OR @WinnerID = -1
        BEGIN
            THROW 50000, 'One or more of the fighters were not found in the system', 1;
        END

        -- ����� ���� ����
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

-----����� ������� �����
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

    -- ����� ����� ����� �����
    UPDATE Fighters
    SET NumOfWins = NumOfWins + 1,
        Knockouts = CASE WHEN @WinMethod = 'KO/TKO' THEN Knockouts + 1 ELSE Knockouts END,
        Submissions = CASE WHEN @WinMethod = 'Submission' THEN Submissions + 1 ELSE Submissions END
    WHERE FighterID = @WinnerID;

    -- ����� ����� ������� ��������
    UPDATE Fighters
    SET NumOfLosses = NumOfLosses + 1
    WHERE FighterID IN (@Fighter1ID, @Fighter2ID) AND FighterID != @WinnerID;

    -- ����� �� ����� ����
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

----����� ������� ���� �� ������
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

    -- ����� �� ��� �������� ��� ����� ������ ����� ������
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
        -- ����� ��� ������ �� �����
        IF @CurrentChampionID = @WinnerID
        BEGIN
            SET @ChampionshipMessage = CONCAT(@WinnerFirstName, ' ', @WinnerLastName, 
                ' successfully defended the ', @WeightClass, ' championship');
        END
        ELSE -- ������ ��� ��� �������
        BEGIN
            -- ����� ����� ���� ������� �� ����� �����
            UPDATE Championships
            SET ChampionEndDate = @EventDate
            WHERE WeightClassName = @WeightClass AND ChampionEndDate IS NULL;

            -- ����� ����� ���� ����
            INSERT INTO Championships (WeightClassName, FighterID, ChampionStartDate)
            VALUES (@WeightClass, @WinnerID, @EventDate);

            SET @ChampionshipMessage = CONCAT(@WinnerFirstName, ' ', @WinnerLastName, 
                ' is the new ', @WeightClass, ' champion!');
        END

        -- ����� ������ ����
        PRINT @ChampionshipMessage;
    END;
END;
GO

--####################����� �� ������#########################
--################ ����� 2 ������ ����� ######################
	---- ����� �� ����
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

-- ����� �� ����
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

---################ ����� ��  ������� �����###################
-- ����� ����� ���  ��� , ���� ����� ���� �����
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


---############����� �� ����� ###############
--��� ��� ����, ���� ���� ���
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

-- ��� ����
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


-- ��� ��� ���� , ����� ��� �� �����
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

-- ��� ��� ���� �������� ���� ���� ������ �������, ����� ����� ��� �� ���� �� �����, ���� ���� ����	
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

-- ��� ���� 6


-- ### ���� ���� 7 ###
-- ���� ���� ����, ������ �� ����
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

-- ���� ���� ����, ������ �� �����
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

-- ����� �� ��� �������  
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

    -- ����� ���� ����� ������� (��� 1 �-5)
    SET @RoundNumber = FLOOR(RAND() * 5) + 1;

    -- ����� ���� ������ ��������
    SET @WinMethod = CASE 
        WHEN RAND() < 0.5 THEN 'KO/TKO'
        ELSE 'Submission'
    END;

    -- ����� ���� ����� �������
    SET @Fighter1ID = FLOOR(RAND() * (1068 - 1000) + 1000);
    SET @Fighter1FirstName = dbo.Fn_GetFighterFirstName(@Fighter1ID);
    SET @Fighter1LastName = dbo.Fn_GetFighterLastName(@Fighter1ID);

    -- ����� ���� ��� ������� (���� �������)
    SET @Fighter2ID = @Fighter1ID;
    WHILE @Fighter2ID = @Fighter1ID
    BEGIN
        SET @Fighter2ID = FLOOR(RAND() * (1068 - 1000) + 1000);
    END
    SET @Fighter2FirstName = dbo.Fn_GetFighterFirstName(@Fighter2ID);
    SET @Fighter2LastName = dbo.Fn_GetFighterLastName(@Fighter2ID);

    -- ����� �������� ���� ��������
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

    -- ����� ���� ������� ��� ��� �������
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

    -- ����� ���� ����
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

    -- ����� ���� ���� �����
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

--���� ������
EXEC InsertRandomFight @FightID = 'F1002', @EventID = 500;
GO
-- ��� ���� 7


-- ### ���� ���� 8 ###
--- ��������� �� �������
CREATE or alter VIEW V_FightersStats AS
SELECT 
    f.FighterID, 
    f.FirstName, 
    f.LastName,
    -- ����� ���� ��������� �� ����� ����� �� ��� �����
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfWins * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS WinRate,
    -- ����� ���� �������
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfLosses * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS LossRate,
    -- ����� ���� �����
    CASE 
        WHEN (NumOfWins + NumOfLosses + NumOfDraws) = 0 THEN '0.0'
        ELSE FORMAT(ROUND((NumOfDraws * 100.0) / NULLIF(NumOfWins + NumOfLosses + NumOfDraws, 0), 1), 'N1')
    END AS DrawRate,
    -- ����� ���� ���������� ���� ���������
    CASE 
        WHEN NumOfWins = 0 THEN '0.0'
        ELSE FORMAT(ROUND((Knockouts * 100.0) / NULLIF(NumOfWins, 0), 1), 'N1')
    END AS KORate,
    -- ����� ���� ������� ���� ���������
    CASE 
        WHEN NumOfWins = 0 THEN '0.0'
        ELSE FORMAT(ROUND((Submissions * 100.0) / NULLIF(NumOfWins, 0), 1), 'N1')
    END AS SubmissionsRate
FROM Fighters f
go



-- CTE ������ ����� ������� �� �������� ����� ������������
WITH FighterStats AS (
    SELECT 
        f.FighterID,
        f.FirstName,
        f.LastName,
        f.WeightLbs,
        -- ����� �������� ����� ������� �����
        (SELECT TOP 1 WeightClassName
         FROM WeightClass wc
         WHERE f.WeightLbs <= wc.MaxWeight
         ORDER BY wc.MaxWeight) AS WeightClassName,
        CAST(NULLIF(vs.WinRate, 'N/A') AS FLOAT) AS WinRate
    FROM Fighters f
    LEFT JOIN V_FightersStats vs ON f.FighterID = vs.FighterID
),
-- ����� ������� ��� �������� ���� �����
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
-- ����� 5 ������� �������� ��� �������� ����
TopFighters AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY WeightClassName ORDER BY RankInWeightClass) AS RowNum
    FROM RankedFighters
    WHERE RankInWeightClass <= 5
)
-- ����� �����
SELECT 
    WeightClassName,
    RankInWeightClass,
    PoundForPoundRank,
    FirstName,
    LastName
FROM TopFighters
WHERE RowNum <= 5
ORDER BY WeightClassName, RankInWeightClass;
-- ��� ���� 8
go





-- ### ���� ���� 9 ###
-- ������� ������ ����� �������
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

-- ������� ������ ���� �������
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

-- ������� ������ ���� �������
CREATE  or alter PROCEDURE Pr_DeleteFighterEarningsTable
AS
BEGIN
    IF OBJECT_ID('dbo.Tbl_FighterEarnings', 'U') IS NOT NULL
        DROP TABLE dbo.Tbl_FighterEarnings
END
GO

-- �������� "��" ������� �� �� ������
CREATE OR ALTER PROCEDURE Pr_ProcessFighterEarnings
    @KnockoutBonus INT,
    @SubmissionBonus INT,
    @DecisionBonus INT,
    @DrawPenalty INT
AS
BEGIN
    -- 1. ����� ����� �� ��� �����
    IF OBJECT_ID('dbo.Tbl_FighterEarnings', 'U') IS NOT NULL
        DROP TABLE dbo.Tbl_FighterEarnings

    -- 2. ����� ����� ����
    EXEC dbo.Pr_CreateFighterEarningsTable

    -- 3. ����� ������� �����
    INSERT INTO dbo.Tbl_FighterEarnings
    SELECT * FROM dbo.Fn_CalculateFighterEarnings(@KnockoutBonus, @SubmissionBonus, @DecisionBonus, @DrawPenalty)
    WHERE TotalEarnings <> 0
    ORDER BY TotalEarnings DESC

    -- ���� �������
    SELECT * FROM dbo.Tbl_FighterEarnings 
    WHERE TotalEarnings <> 0  
    ORDER BY TotalEarnings DESC

    -- ����� �� �����
    PRINT 'Table Name: dbo.Tbl_FighterEarnings'
END
GO

--����� ��������� �"��"
EXEC dbo.Pr_ProcessFighterEarnings 200000, 150000, 100000, 50000

-- ��� ���� 9
go



-- ### ���� ���� 10 ###
--�����������
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
 sp_configure 'xp_cmdshell', '1' 
reconfigure with override
GO




-- ����� ����� ����
CREATE or alter PROCEDURE BackupTableToExcel
    @TableName NVARCHAR(50)
AS
BEGIN
    DECLARE @FileName NVARCHAR(255), @TempFileName NVARCHAR(255)
    DECLARE @Command NVARCHAR(500), @DirCommand NVARCHAR(500), @HeaderCommand NVARCHAR(500)
    DECLARE @Columns NVARCHAR(MAX)
    
    -- ����� ������ AlmogSQL
    SET @DirCommand = 'if not exist "c:\AlmogSQL" mkdir "c:\AlmogSQL"'
    EXEC xp_cmdshell @DirCommand

    -- ����� ��-������ ��� �� ��� �������
    SET @DirCommand = 'if not exist "c:\AlmogSQL\' + 'OutputData' + '" mkdir "c:\AlmogSQL\' + 'OutputData' + '"'
    EXEC xp_cmdshell @DirCommand

    SET @FileName = 'c:\AlmogSQL\' + 'OutputData' + '\' + @TableName + '.csv'
    SET @TempFileName = 'c:\AlmogSQL\' + 'OutputData' + '\' + @TableName + '_temp.csv'
    
    -- ���� ����� �������
    SELECT @Columns = STRING_AGG(QUOTENAME(column_name), ',')
    FROM information_schema.columns
    WHERE table_name = @TableName AND table_schema = 'dbo'

    -- ����� ���� ������� ������� ����� �����
    SET @HeaderCommand = 'echo ' + @Columns + ' > "' + @FileName + '"'
    EXEC xp_cmdshell @HeaderCommand

    -- ����� ���� ����� ����� CSV ����
    SET @Command = 'bcp ' + QUOTENAME(DB_NAME()) + '.dbo.' + QUOTENAME(@TableName) + 
                   ' out "' + @TempFileName + '" -c -t, -T -S ' + @@SERVERNAME
    EXEC xp_cmdshell @Command

    -- ����� ���� ������� ����� �����
    SET @Command = 'type "' + @TempFileName + '" >> "' + @FileName + '"'
    EXEC xp_cmdshell @Command

    -- ����� ���� ����� �����
    SET @Command = 'del "' + @TempFileName + '"'
    EXEC xp_cmdshell @Command

    PRINT 'Backup completed: ' + @FileName
END
GO

-- �����   
EXEC BackupTableToExcel 'Tbl_FighterEarnings'
go


-- ### ���� ���� 11 ###
--- ����� ����� CSV 
BULK INSERT [dbo].[Fighters]
	FROM 'C:\AlmogSQL\Insertdata\DataForInsertInQuery.csv'   
	WITH 
       ( 
		CODEPAGE = 'ACP',  -- ����� �����
		FIRSTROW = 2 ,  -- ���� ������
		MAXERRORS = 0 , -- �� ����� ������
        FIELDTERMINATOR = ',', -- ����� ��� ����
        ROWTERMINATOR = '\n'  -- new line
       )
GO

--�����
select *
from Fighters






-- ### ���� ���� 12 ###
CREATE OR ALTER PROCEDURE AnalyzeUFCMartialArts
AS
BEGIN
    SET NOCOUNT ON;

    -- ����� ������ ������ �� �� ������
    IF OBJECT_ID('tempdb..#PopularityResults') IS NOT NULL
        DROP TABLE #PopularityResults;
    
    IF OBJECT_ID('tempdb..#CumulativeCounts') IS NOT NULL
        DROP TABLE #CumulativeCounts;

    -- ����� ������
    DECLARE @StartYear INT;
    DECLARE @EndYear INT;
    DECLARE @CurrentYear INT;

    -- ����� ��� ������ (���� ������� ����� �-JoinToUFC)
    SELECT @StartYear = MIN(JoinToUFC)
    FROM Fighters;

    -- ����� ��� ����� (���� ������� ����� �-JoinToUFC)
    SELECT @EndYear = MAX(JoinToUFC)
    FROM Fighters;

    SET @CurrentYear = @StartYear;

    -- ����� ���� ����� ������ �������
    CREATE TABLE #PopularityResults (
        Year INT,
        MartialArt NVARCHAR(50),
        NewFighterCount INT,
        Percentage DECIMAL(5,2),
        CumulativeFighters INT,
        CumulativePercentage DECIMAL(5,2)
    );

    -- ����� ���� ����� ������ ������� ��������
    CREATE TABLE #CumulativeCounts (
        MartialArt NVARCHAR(50),
        TotalFighters INT
    );

    -- ����� �� ��� �����
    WHILE @CurrentYear <= @EndYear
    BEGIN
        -- ����� �� �� ������� ������ ���� �������
        DECLARE @NewFighters INT;
        SELECT @NewFighters = COUNT(DISTINCT FighterID)
        FROM Fighters
        WHERE JoinToUFC = @CurrentYear;

        -- ����� ������ ����� ������
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

        -- ����� ������� ��������
        MERGE INTO #CumulativeCounts AS Target
        USING (SELECT MartialArt, NewFighterCount FROM #PopularityResults WHERE Year = @CurrentYear) AS Source
        ON Target.MartialArt = Source.MartialArt
        WHEN MATCHED THEN
            UPDATE SET Target.TotalFighters = Target.TotalFighters + Source.NewFighterCount
        WHEN NOT MATCHED THEN
            INSERT (MartialArt, TotalFighters) VALUES (Source.MartialArt, Source.NewFighterCount);

        -- ����� ������� �������� ����� �������
        UPDATE PR
        SET 
            PR.CumulativeFighters = CC.TotalFighters,
            PR.CumulativePercentage = CAST(CC.TotalFighters AS DECIMAL(5,2)) / 
                (SELECT SUM(NewFighterCount) FROM #PopularityResults WHERE Year <= @CurrentYear) * 100
        FROM #PopularityResults PR
        JOIN #CumulativeCounts CC ON PR.MartialArt = CC.MartialArt
        WHERE PR.Year = @CurrentYear;

        -- ���� ���� ����
        SET @CurrentYear = @CurrentYear + 1;
    END;

    -- ���� �������
    SELECT * FROM #PopularityResults
    ORDER BY Year, Percentage DESC;


END;

EXEC AnalyzeUFCMartialArts;

-- ��� ���� 12



-- ### ���� ���� 13 ###
--�����������
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
sp_configure 'xp_cmdshell', '1' 
reconfigure with override
GO

--(����� ��� ����� ���� ����, ����� ��� ����� �� ����(�� ������
CREATE or ALTER PROC proc_backup_database
 @P_Path nvarchar(50),
 @DateForBackUps date
AS
Declare @Disk_path varchar(100)
-- ����� ����� �����
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

----������
CREATE OR ALTER PROC proc_restore_database
    @P_Path nvarchar(255),
    @DateForRestore date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Disk_path nvarchar(500)
    DECLARE @SQL nvarchar(1000)
    DECLARE @ErrorMessage nvarchar(1000)
    
    -- ����� ���� �����
    SET @Disk_path = @P_Path + 'UFC' + CONVERT(char(10), @DateForRestore, 102) + '.bak'
    
    -- ����� ����� ������
    PRINT '���� ���� ������: ' + @Disk_path
    
    BEGIN TRY
        -- ����� ��� ������� �� ����
        IF EXISTS (SELECT name FROM sys.databases WHERE name = 'UFC')
        BEGIN
            SET @SQL = 'ALTER DATABASE UFC SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                        DROP DATABASE UFC;'
            EXEC sp_executesql @SQL
            PRINT '��� ������� UFC ����'
        END
        
        -- ����� ��� �������
        SET @SQL = 'RESTORE DATABASE UFC FROM DISK = ''' + @Disk_path + ''' WITH REPLACE'
        EXEC sp_executesql @SQL
        
        PRINT '��� ������� UFC ����� ������'
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE()
        PRINT '����� ������ ��� �������: ' + @ErrorMessage
        RETURN -1
    END CATCH
END
GO

use master
EXEC proc_restore_database 'C:\AlmogSQL\BackUps\', '2022-02-02'
GO

use ufc
go

