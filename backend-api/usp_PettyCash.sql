-- =============================================================================
-- Stored Procedures: PettyCash
-- Repository: MSSQLPettyCashRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_CreatePettyCashEntry
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreatePettyCashEntry', 'P') IS NOT NULL DROP PROCEDURE usp_CreatePettyCashEntry;
GO
CREATE PROCEDURE usp_CreatePettyCashEntry
    @EntryId      VARCHAR(50),
    @Description  VARCHAR(500),
    @Amount       DECIMAL(10,2),
    @EntryType    VARCHAR(50),
    @JobId        VARCHAR(50),
    @CreatedBy    VARCHAR(50),
    @BalanceAfter DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PettyCash (EntryId, Description, Amount, EntryType, JobId, CreatedBy, BalanceAfter, Date)
    VALUES (@EntryId, @Description, @Amount, @EntryType, @JobId, @CreatedBy, @BalanceAfter, GETDATE());
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetPettyCashEntryById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashEntryById', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashEntryById;
GO
CREATE PROCEDURE usp_GetPettyCashEntryById
    @EntryId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PettyCash WHERE EntryId = @EntryId;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetAllPettyCashEntries
--    @EntryType and @CreatedBy are optional filters — pass NULL to skip
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllPettyCashEntries', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllPettyCashEntries;
GO
CREATE PROCEDURE usp_GetAllPettyCashEntries
    @EntryType VARCHAR(50) = NULL,
    @CreatedBy VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PettyCash
    WHERE (@EntryType IS NULL OR EntryType = @EntryType)
      AND (@CreatedBy IS NULL OR CreatedBy = @CreatedBy)
    ORDER BY Date DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetPettyCashEntriesByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashEntriesByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashEntriesByJob;
GO
CREATE PROCEDURE usp_GetPettyCashEntriesByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PettyCash WHERE JobId = @JobId ORDER BY Date DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetPettyCashEntriesByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashEntriesByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashEntriesByUser;
GO
CREATE PROCEDURE usp_GetPettyCashEntriesByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PettyCash WHERE CreatedBy = @UserId ORDER BY Date DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_GetPettyCashBalance
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPettyCashBalance', 'P') IS NOT NULL DROP PROCEDURE usp_GetPettyCashBalance;
GO
CREATE PROCEDURE usp_GetPettyCashBalance
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Balance FROM PettyCashBalance WHERE Id = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_UpdatePettyCashBalance
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePettyCashBalance', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePettyCashBalance;
GO
CREATE PROCEDURE usp_UpdatePettyCashBalance
    @Amount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PettyCashBalance SET Balance = @Amount, LastUpdated = GETDATE() WHERE Id = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_GenerateNextPettyCashId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextPettyCashId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextPettyCashId;
GO
CREATE PROCEDURE usp_GenerateNextPettyCashId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(EntryId, 3, 4) AS INT))
    FROM PettyCash
    WHERE EntryId LIKE 'PC[0-9][0-9][0-9][0-9]';
    SELECT 'PC' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextEntryId;
END;
GO
