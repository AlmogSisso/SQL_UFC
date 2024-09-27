CREATE database UFC
go

Use UFC 
go




-- Create Fighters table
CREATE TABLE Fighters (
    FighterID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    NickName NVARCHAR(50),
    DateOfBirth DATE,
    JoinToUFC INT,
    Nationality NVARCHAR(50),
    HeightCm INT,
    ReachCm INT,
    WeightLbs INT,
    NumOfWins INT,
    NumOfLosses INT,
    NumOfDraws INT,
    NumOfNoContests INT,
	Knockouts INT,
    Submissions INT
)
GO

-- Create Events table
CREATE TABLE Events (
    EventID INT PRIMARY KEY,
    EventName NVARCHAR(100),
    EventDate DATE,
    EventLocation NVARCHAR(100),
    Country NVARCHAR(50)
)
GO


-- Create WeightClass table
CREATE TABLE WeightClass (
    WeightClassName NVARCHAR(50) PRIMARY KEY,
    MinWeight INT,
    MaxWeight INT,
)
GO

-- Create Championships table
CREATE TABLE Championships (
    WeightClassName NVARCHAR(50),
    FighterID INT,
    ChampionStartDATE DATE,
    ChampionEndDATE DATE,
    PRIMARY KEY (WeightClassName, FighterID, ChampionStartDATE)
)
GO

-- Create Fights table
CREATE TABLE Fights (
    FightID NVARCHAR(50) PRIMARY KEY,
    EventID INT,
    Fighter1ID INT,
    Fighter2ID INT,
    WeightClassFight NVARCHAR(50),
    Winner INT,
    WinMethod NVARCHAR(50),
    RoundNumber INT
)
GO




-- Create MartialArts table
CREATE TABLE MartialArts (
    FighterID INT,
    WarriorStyles NVARCHAR(50),
    PRIMARY KEY (FighterID, WarriorStyles)
)
GO

-- Add foreign key constraints


ALTER TABLE Championships
ADD CONSTRAINT FK_Championships_WeightClass FOREIGN KEY (WeightClassName) REFERENCES WeightClass(WeightClassName),
    CONSTRAINT FK_Championships_Fighter FOREIGN KEY (FighterID) REFERENCES Fighters(FighterID)
GO

ALTER TABLE Fights
ADD CONSTRAINT FK_Fights_Event FOREIGN KEY (EventID) REFERENCES Events(EventID),
    CONSTRAINT FK_Fights_Fighter1 FOREIGN KEY (Fighter1ID) REFERENCES Fighters(FighterID),
    CONSTRAINT FK_Fights_Fighter2 FOREIGN KEY (Fighter2ID) REFERENCES Fighters(FighterID),
    CONSTRAINT FK_Fights_WeightClass FOREIGN KEY (WeightClassFight) REFERENCES WeightClass(WeightClassName),
    CONSTRAINT FK_Fights_Winner FOREIGN KEY (Winner) REFERENCES Fighters(FighterID)
GO


ALTER TABLE MartialArts
ADD CONSTRAINT FK_MartialArts_Fighter FOREIGN KEY (FighterID) REFERENCES Fighters(FighterID)
GO

-- Add date check constraint
ALTER TABLE Fighters
ADD CONSTRAINT CHK_DateOfBirth CHECK (DateOfBirth < GETDATE())
GO