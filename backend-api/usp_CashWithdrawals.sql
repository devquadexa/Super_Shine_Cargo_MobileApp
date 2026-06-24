-- =============================================================================
-- Stored Procedures: CashWithdrawals
-- Repository: MSSQLCashWithdrawalRepository
-- =============================================================================

IF OBJECT_ID('usp_CreateCashWithdrawal', 'P') IS NOT NULL DROP PROCEDURE usp_CreateCashWithdrawal;
GO
CREATE PROCEDURE usp_CreateCashWithdrawal
    @WithdrawalId    VARCHAR(50),
    @Amount          DECIMAL(18,2),
    @BankName        NVARCHAR(200),
    @WithdrawalDate  DATETIME,
    @Notes           NVARCHAR(500),
    @TransactionType NVARCHAR(50),
    @CreatedBy       VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO CashWithdrawals (withdrawalId, amount, bankName, withdrawalDate, notes, transactionType, createdBy)
    VALUES (@WithdrawalId, @Amount, @BankName, @WithdrawalDate, @Notes, @TransactionType, @CreatedBy);
END;
GO

IF OBJECT_ID('usp_GetAllCashWithdrawals', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllCashWithdrawals;
GO
CREATE PROCEDURE usp_GetAllCashWithdrawals
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cw.*, u.fullName AS createdByName
    FROM CashWithdrawals cw
    LEFT JOIN Users u ON cw.createdBy = u.userId
    ORDER BY cw.withdrawalDate DESC, cw.createdAt DESC;
END;
GO

IF OBJECT_ID('usp_GetCashWithdrawalById', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashWithdrawalById;
GO
CREATE PROCEDURE usp_GetCashWithdrawalById
    @WithdrawalId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashWithdrawals WHERE withdrawalId = @WithdrawalId;
END;
GO

IF OBJECT_ID('usp_GetCashWithdrawalsByDateRange', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashWithdrawalsByDateRange;
GO
CREATE PROCEDURE usp_GetCashWithdrawalsByDateRange
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cw.*, u.fullName AS createdByName
    FROM CashWithdrawals cw
    LEFT JOIN Users u ON cw.createdBy = u.userId
    WHERE CAST(cw.withdrawalDate AS DATE) BETWEEN @FromDate AND @ToDate
    ORDER BY cw.withdrawalDate DESC, cw.createdAt DESC;
END;
GO

IF OBJECT_ID('usp_GenerateNextCashWithdrawalId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextCashWithdrawalId;
GO
CREATE PROCEDURE usp_GenerateNextCashWithdrawalId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(withdrawalId, 3, 10) AS INT))
    FROM CashWithdrawals WHERE withdrawalId LIKE 'CW%';
    SELECT 'CW' + RIGHT('000000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(6)), 6) AS NextWithdrawalId;
END;
GO
