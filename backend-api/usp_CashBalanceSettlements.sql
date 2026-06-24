-- =============================================================================
-- Stored Procedures: CashBalanceSettlements
-- Repository: MSSQLCashBalanceSettlementRepository
-- =============================================================================

IF OBJECT_ID('usp_CreateCashBalanceSettlement', 'P') IS NOT NULL DROP PROCEDURE usp_CreateCashBalanceSettlement;
GO
CREATE PROCEDURE usp_CreateCashBalanceSettlement
    @SettlementId       VARCHAR(50),
    @UserId             VARCHAR(50),
    @UserName           NVARCHAR(255),
    @ManagerId          VARCHAR(50),
    @ManagerName        NVARCHAR(255),
    @SettlementType     NVARCHAR(100),
    @Amount             DECIMAL(18,2),
    @Status             NVARCHAR(50),
    @RequestDate        DATETIME,
    @Notes              NVARCHAR(MAX),
    @RelatedAssignments NVARCHAR(MAX),
    @CreatedBy          VARCHAR(50),
    @CreatedDate        DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO CashBalanceSettlements (
        settlementId, userId, userName, managerId, managerName,
        settlementType, amount, status, requestDate, notes,
        relatedAssignments, createdBy, createdDate
    )
    VALUES (
        @SettlementId, @UserId, @UserName, @ManagerId, @ManagerName,
        @SettlementType, @Amount, @Status, @RequestDate, @Notes,
        @RelatedAssignments, @CreatedBy, @CreatedDate
    );
END;
GO

IF OBJECT_ID('usp_GetCashBalanceSettlementById', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashBalanceSettlementById;
GO
CREATE PROCEDURE usp_GetCashBalanceSettlementById
    @SettlementId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE settlementId = @SettlementId;
END;
GO

IF OBJECT_ID('usp_GetAllCashBalanceSettlements', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllCashBalanceSettlements;
GO
CREATE PROCEDURE usp_GetAllCashBalanceSettlements
    @UserId         VARCHAR(50)  = NULL,
    @ManagerId      VARCHAR(50)  = NULL,
    @Status         NVARCHAR(50) = NULL,
    @SettlementType NVARCHAR(100)= NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cbs.*,
        (SELECT TOP 1 pa.jobId FROM PettyCashAssignments pa
         WHERE pa.assignmentId = (SELECT TOP 1 value FROM OPENJSON(cbs.relatedAssignments) ORDER BY [key])
        ) AS jobId,
        (SELECT TOP 1 j.CUSDECNumber FROM PettyCashAssignments pa
         JOIN Jobs j ON pa.jobId = j.JobId
         WHERE pa.assignmentId = (SELECT TOP 1 value FROM OPENJSON(cbs.relatedAssignments) ORDER BY [key])
        ) AS cusdecNumber
    FROM CashBalanceSettlements cbs
    WHERE (@UserId         IS NULL OR cbs.userId         = @UserId)
      AND (@ManagerId      IS NULL OR cbs.managerId      = @ManagerId)
      AND (@Status         IS NULL OR cbs.status         = @Status)
      AND (@SettlementType IS NULL OR cbs.settlementType = @SettlementType)
    ORDER BY cbs.requestDate DESC;
END;
GO

IF OBJECT_ID('usp_GetCashBalanceSettlementsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashBalanceSettlementsByUser;
GO
CREATE PROCEDURE usp_GetCashBalanceSettlementsByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE userId = @UserId ORDER BY requestDate DESC;
END;
GO

IF OBJECT_ID('usp_GetCashBalanceSettlementsByManager', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashBalanceSettlementsByManager;
GO
CREATE PROCEDURE usp_GetCashBalanceSettlementsByManager
    @ManagerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE managerId = @ManagerId ORDER BY requestDate DESC;
END;
GO

IF OBJECT_ID('usp_GetPendingCashBalanceSettlements', 'P') IS NOT NULL DROP PROCEDURE usp_GetPendingCashBalanceSettlements;
GO
CREATE PROCEDURE usp_GetPendingCashBalanceSettlements
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE status = 'PENDING' ORDER BY requestDate ASC;
END;
GO

IF OBJECT_ID('usp_GetApprovedCashBalanceSettlements', 'P') IS NOT NULL DROP PROCEDURE usp_GetApprovedCashBalanceSettlements;
GO
CREATE PROCEDURE usp_GetApprovedCashBalanceSettlements
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE status = 'APPROVED' ORDER BY approvedDate ASC;
END;
GO

IF OBJECT_ID('usp_GetRejectedCashBalanceSettlements', 'P') IS NOT NULL DROP PROCEDURE usp_GetRejectedCashBalanceSettlements;
GO
CREATE PROCEDURE usp_GetRejectedCashBalanceSettlements
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CashBalanceSettlements WHERE status = 'REJECTED' ORDER BY updatedDate DESC;
END;
GO

IF OBJECT_ID('usp_UpdateCashBalanceSettlement', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateCashBalanceSettlement;
GO
CREATE PROCEDURE usp_UpdateCashBalanceSettlement
    @SettlementId  VARCHAR(50),
    @ManagerId     VARCHAR(50),
    @ManagerName   NVARCHAR(255),
    @Status        NVARCHAR(50),
    @ApprovedDate  DATETIME,
    @CompletedDate DATETIME,
    @ManagerNotes  NVARCHAR(MAX),
    @UpdatedBy     VARCHAR(50),
    @UpdatedDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CashBalanceSettlements
    SET managerId     = ISNULL(@ManagerId,     managerId),
        managerName   = ISNULL(@ManagerName,   managerName),
        status        = ISNULL(@Status,        status),
        approvedDate  = ISNULL(@ApprovedDate,  approvedDate),
        completedDate = ISNULL(@CompletedDate, completedDate),
        managerNotes  = ISNULL(@ManagerNotes,  managerNotes),
        updatedBy     = ISNULL(@UpdatedBy,     updatedBy),
        updatedDate   = ISNULL(@UpdatedDate,   updatedDate)
    WHERE settlementId = @SettlementId;
END;
GO

IF OBJECT_ID('usp_DeleteCashBalanceSettlement', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteCashBalanceSettlement;
GO
CREATE PROCEDURE usp_DeleteCashBalanceSettlement
    @SettlementId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM CashBalanceSettlements WHERE settlementId = @SettlementId;
END;
GO

IF OBJECT_ID('usp_GenerateNextCashBalanceSettlementId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextCashBalanceSettlementId;
GO
CREATE PROCEDURE usp_GenerateNextCashBalanceSettlementId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(settlementId, 4, 6) AS INT))
    FROM CashBalanceSettlements WHERE settlementId LIKE 'CBS%';
    SELECT 'CBS' + RIGHT('000000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(6)), 6) AS NextSettlementId;
END;
GO

IF OBJECT_ID('usp_GetCashBalanceSettlementsSummary', 'P') IS NOT NULL DROP PROCEDURE usp_GetCashBalanceSettlementsSummary;
GO
CREATE PROCEDURE usp_GetCashBalanceSettlementsSummary
AS
BEGIN
    SET NOCOUNT ON;
    SELECT status, settlementType, COUNT(*) AS count, SUM(amount) AS totalAmount
    FROM CashBalanceSettlements
    GROUP BY status, settlementType
    ORDER BY status, settlementType;
END;
GO

IF OBJECT_ID('usp_GetUserCashBalanceSettlementsSummary', 'P') IS NOT NULL DROP PROCEDURE usp_GetUserCashBalanceSettlementsSummary;
GO
CREATE PROCEDURE usp_GetUserCashBalanceSettlementsSummary
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT status, settlementType, COUNT(*) AS count, SUM(amount) AS totalAmount
    FROM CashBalanceSettlements
    WHERE userId = @UserId
    GROUP BY status, settlementType
    ORDER BY status, settlementType;
END;
GO
