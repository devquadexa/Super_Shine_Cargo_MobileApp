-- =============================================================================
-- Stored Procedures: Jobs + JobAdvancePayments + PayItems
-- Repository: MSSQLJobRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_CreateJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateJob', 'P') IS NOT NULL DROP PROCEDURE usp_CreateJob;
GO
CREATE PROCEDURE usp_CreateJob
    @JobId                 VARCHAR(50),
    @CustomerId            VARCHAR(50),
    @BLNumber              NVARCHAR(100),
    @CUSDECNumber          NVARCHAR(100),
    @CUSDECDate            DATE,
    @OpenDate              DATE,
    @ShipmentCategory      NVARCHAR(100),
    @ChassisNumber         NVARCHAR(100),
    @Exporter              NVARCHAR(200),
    @Transporter           NVARCHAR(200),
    @LCNumber              NVARCHAR(100),
    @ContainerNumber       NVARCHAR(100),
    @TransportDeliveryDate DATE,
    @Status                VARCHAR(50),
    @AssignedTo            VARCHAR(50),
    @CreatedDate           DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Jobs (
        JobId, CustomerId, BLNumber, CUSDECNumber, CUSDECDate, OpenDate,
        ShipmentCategory, chassisNumber, Exporter, Transporter, LCNumber,
        ContainerNumber, transportDeliveryDate, Status, AssignedTo, CreatedDate
    )
    VALUES (
        @JobId, @CustomerId, @BLNumber, @CUSDECNumber, @CUSDECDate, @OpenDate,
        @ShipmentCategory, @ChassisNumber, @Exporter, @Transporter, @LCNumber,
        @ContainerNumber, @TransportDeliveryDate, @Status, @AssignedTo, @CreatedDate
    );
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetJobById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobById', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobById;
GO
CREATE PROCEDURE usp_GetJobById
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Jobs WHERE jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetAllJobs
--    @Status and @CustomerId are optional — pass NULL to skip
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllJobs', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllJobs;
GO
CREATE PROCEDURE usp_GetAllJobs
    @Status     VARCHAR(50) = NULL,
    @CustomerId VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT
        j.*,
        (SELECT TOP 1 b.netTotal   FROM Bills b WHERE b.jobId = j.jobId ORDER BY b.CreatedDate DESC) AS billTotalAmount,
        (SELECT TOP 1 b.paidAmount FROM Bills b WHERE b.jobId = j.jobId ORDER BY b.CreatedDate DESC) AS billPaidAmount
    FROM Jobs j
    WHERE (@Status     IS NULL OR j.status     = @Status)
      AND (@CustomerId IS NULL OR j.customerId = @CustomerId)
    ORDER BY j.jobId ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetJobsByAssignedUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobsByAssignedUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobsByAssignedUser;
GO
CREATE PROCEDURE usp_GetJobsByAssignedUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT
        j.*,
        (SELECT TOP 1 b.netTotal   FROM Bills b WHERE b.jobId = j.jobId ORDER BY b.CreatedDate DESC) AS billTotalAmount,
        (SELECT TOP 1 b.paidAmount FROM Bills b WHERE b.jobId = j.jobId ORDER BY b.CreatedDate DESC) AS billPaidAmount
    FROM Jobs j
    INNER JOIN JobAssignments ja ON j.jobId = ja.jobId
    WHERE ja.userId = @UserId AND ja.isActive = 1
    ORDER BY j.openDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetJobsByCustomer
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobsByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobsByCustomer;
GO
CREATE PROCEDURE usp_GetJobsByCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Jobs WHERE CustomerId = @CustomerId ORDER BY CreatedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_UpdateJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateJob', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJob;
GO
CREATE PROCEDURE usp_UpdateJob
    @JobId                 VARCHAR(50),
    @BLNumber              NVARCHAR(100),
    @CUSDECNumber          NVARCHAR(100),
    @CUSDECDate            DATE,
    @OpenDate              DATE,
    @ShipmentCategory      NVARCHAR(100),
    @ChassisNumber         NVARCHAR(100),
    @Exporter              NVARCHAR(200),
    @Transporter           NVARCHAR(200),
    @LCNumber              NVARCHAR(100),
    @ContainerNumber       NVARCHAR(100),
    @TransportDeliveryDate DATE,
    @Status                VARCHAR(50),
    @AssignedTo            VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs
    SET BLNumber              = @BLNumber,
        CUSDECNumber          = @CUSDECNumber,
        CUSDECDate            = @CUSDECDate,
        OpenDate              = @OpenDate,
        ShipmentCategory      = @ShipmentCategory,
        chassisNumber         = @ChassisNumber,
        Exporter              = @Exporter,
        Transporter           = @Transporter,
        LCNumber              = @LCNumber,
        ContainerNumber       = @ContainerNumber,
        transportDeliveryDate = @TransportDeliveryDate,
        Status                = @Status,
        AssignedTo            = @AssignedTo
    WHERE JobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_UpdateJobStatus
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateJobStatus', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJobStatus;
GO
CREATE PROCEDURE usp_UpdateJobStatus
    @JobId  VARCHAR(50),
    @Status VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs SET Status = @Status WHERE JobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_AssignJobToUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_AssignJobToUser', 'P') IS NOT NULL DROP PROCEDURE usp_AssignJobToUser;
GO
CREATE PROCEDURE usp_AssignJobToUser
    @JobId  VARCHAR(50),
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO JobAssignments (jobId, userId) VALUES (@JobId, @UserId);
END;
GO


-- -----------------------------------------------------------------------------
-- 9. usp_DeleteJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteJob', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteJob;
GO
CREATE PROCEDURE usp_DeleteJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Jobs WHERE JobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 10. usp_GenerateNextJobId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextJobId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextJobId;
GO
CREATE PROCEDURE usp_GenerateNextJobId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(JobId, 4, 4) AS INT))
    FROM Jobs WHERE JobId LIKE 'JOB[0-9][0-9][0-9][0-9]';
    SELECT 'JOB' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextJobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 11. usp_GetJobAssignedUsers
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobAssignedUsers', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAssignedUsers;
GO
CREATE PROCEDURE usp_GetJobAssignedUsers
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ja.userId, u.fullName AS userName
    FROM JobAssignments ja
    INNER JOIN Users u ON ja.userId = u.userId
    WHERE ja.jobId = @JobId AND ja.isActive = 1
    ORDER BY ja.assignedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 12. usp_GetOfficePayItemsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOfficePayItemsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetOfficePayItemsByJob;
GO
CREATE PROCEDURE usp_GetOfficePayItemsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT opi.*, u.fullName AS paidByName
    FROM OfficePayItems opi
    LEFT JOIN Users u ON opi.paidBy = u.userId
    WHERE opi.jobId = @JobId
    ORDER BY opi.paymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 13. usp_GetCustomerName
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetCustomerName', 'P') IS NOT NULL DROP PROCEDURE usp_GetCustomerName;
GO
CREATE PROCEDURE usp_GetCustomerName
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Name FROM Customers WHERE CustomerId = @CustomerId;
END;
GO


-- -----------------------------------------------------------------------------
-- 14. usp_GetJobPayItemsJson
--     Returns the payItems JSON column from Jobs
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobPayItemsJson', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobPayItemsJson;
GO
CREATE PROCEDURE usp_GetJobPayItemsJson
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT payItems FROM Jobs WHERE jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 15. usp_UpdateJobPayItemsJson
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateJobPayItemsJson', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJobPayItemsJson;
GO
CREATE PROCEDURE usp_UpdateJobPayItemsJson
    @JobId    VARCHAR(50),
    @PayItems NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs SET payItems = @PayItems WHERE jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 16. usp_AddPayItem
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_AddPayItem', 'P') IS NOT NULL DROP PROCEDURE usp_AddPayItem;
GO
CREATE PROCEDURE usp_AddPayItem
    @PayItemId     VARCHAR(50),
    @JobId         VARCHAR(50),
    @Description   VARCHAR(500),
    @ActualCost    DECIMAL(10,2),
    @BillingAmount DECIMAL(10,2),
    @AddedBy       VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PayItems (PayItemId, JobId, Description, ActualCost, BillingAmount, AddedBy, AddedDate)
    VALUES (@PayItemId, @JobId, @Description, @ActualCost, @BillingAmount, @AddedBy, GETDATE());
END;
GO


-- -----------------------------------------------------------------------------
-- 17. usp_DeletePayItemsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeletePayItemsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_DeletePayItemsByJob;
GO
CREATE PROCEDURE usp_DeletePayItemsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM PayItems WHERE JobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 18. usp_GetPayItemsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPayItemsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetPayItemsByJob;
GO
CREATE PROCEDURE usp_GetPayItemsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PayItems WHERE JobId = @JobId ORDER BY AddedDate DESC;
END;
GO


-- =============================================================================
-- JobAdvancePayments Stored Procedures
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 19. usp_CountJobAdvancePayments
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CountJobAdvancePayments', 'P') IS NOT NULL DROP PROCEDURE usp_CountJobAdvancePayments;
GO
CREATE PROCEDURE usp_CountJobAdvancePayments
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS paymentCount FROM JobAdvancePayments WHERE jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 20. usp_GetJobAdvancePaymentLegacyFields
--     Reads the legacy aggregate columns from the Jobs table
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobAdvancePaymentLegacyFields', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAdvancePaymentLegacyFields;
GO
CREATE PROCEDURE usp_GetJobAdvancePaymentLegacyFields
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        advancePayment,
        advancePaymentDate,
        advancePaymentType,
        advancePaymentCheckNo,
        advancePaymentNotes,
        advancePaymentRecordedBy
    FROM Jobs WHERE JobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 21. usp_InsertJobAdvancePayment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_InsertJobAdvancePayment', 'P') IS NOT NULL DROP PROCEDURE usp_InsertJobAdvancePayment;
GO
CREATE PROCEDURE usp_InsertJobAdvancePayment
    @JobId           VARCHAR(50),
    @Amount          DECIMAL(18,2),
    @PaymentMadeDate DATETIME,
    @PaymentType     VARCHAR(50),
    @CheckNo         VARCHAR(100),
    @Notes           NVARCHAR(MAX),
    @RecordedBy      VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO JobAdvancePayments
        (jobId, amount, paymentMadeDate, paymentType, checkNo, notes, recordedBy)
    VALUES
        (@JobId, @Amount, @PaymentMadeDate, @PaymentType, @CheckNo, @Notes, @RecordedBy);
END;
GO


-- -----------------------------------------------------------------------------
-- 22. usp_SyncJobAdvancePaymentAggregate
--     Recalculates the aggregate fields on Jobs from JobAdvancePayments
--     and returns the summary row
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_SyncJobAdvancePaymentAggregate', 'P') IS NOT NULL DROP PROCEDURE usp_SyncJobAdvancePaymentAggregate;
GO
CREATE PROCEDURE usp_SyncJobAdvancePaymentAggregate
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalAmount    DECIMAL(18,2);
    DECLARE @LatestDate     DATETIME;
    DECLARE @LatestType     NVARCHAR(50);
    DECLARE @LatestCheckNo  NVARCHAR(100);
    DECLARE @LatestNotes    NVARCHAR(MAX);
    DECLARE @LatestRecordedBy VARCHAR(50);

    SELECT
        @TotalAmount = ISNULL(SUM(amount), 0),
        @LatestDate  = MAX(paymentMadeDate)
    FROM JobAdvancePayments WHERE jobId = @JobId;

    SELECT TOP 1
        @LatestType       = paymentType,
        @LatestCheckNo    = checkNo,
        @LatestNotes      = notes,
        @LatestRecordedBy = recordedBy
    FROM JobAdvancePayments
    WHERE jobId = @JobId
    ORDER BY paymentMadeDate DESC, advancePaymentId DESC;

    UPDATE Jobs
    SET advancePayment           = @TotalAmount,
        advancePaymentDate       = @LatestDate,
        advancePaymentNotes      = @LatestNotes,
        advancePaymentRecordedBy = @LatestRecordedBy
    WHERE JobId = @JobId;

    -- Update type/checkNo columns (they may use camelCase or PascalCase depending on migration)
    IF COL_LENGTH('Jobs', 'advancePaymentType')    IS NOT NULL UPDATE Jobs SET advancePaymentType    = @LatestType    WHERE JobId = @JobId;
    IF COL_LENGTH('Jobs', 'advancePaymentCheckNo') IS NOT NULL UPDATE Jobs SET advancePaymentCheckNo = @LatestCheckNo WHERE JobId = @JobId;
    IF COL_LENGTH('Jobs', 'AdvancePaymentType')    IS NOT NULL UPDATE Jobs SET AdvancePaymentType    = @LatestType    WHERE JobId = @JobId;
    IF COL_LENGTH('Jobs', 'AdvancePaymentCheckNo') IS NOT NULL UPDATE Jobs SET AdvancePaymentCheckNo = @LatestCheckNo WHERE JobId = @JobId;

    SELECT
        @TotalAmount     AS totalAdvancePayment,
        @LatestDate      AS latestPaymentDate,
        @LatestType      AS latestPaymentType,
        @LatestCheckNo   AS latestCheckNo,
        @LatestNotes     AS latestNotes,
        @LatestRecordedBy AS latestRecordedBy;
END;
GO


-- -----------------------------------------------------------------------------
-- 23. usp_GetLatestJobAdvancePayment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetLatestJobAdvancePayment', 'P') IS NOT NULL DROP PROCEDURE usp_GetLatestJobAdvancePayment;
GO
CREATE PROCEDURE usp_GetLatestJobAdvancePayment
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 * FROM JobAdvancePayments
    WHERE jobId = @JobId
    ORDER BY advancePaymentId DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 24. usp_GetJobAdvancePaymentsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobAdvancePaymentsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAdvancePaymentsByJob;
GO
CREATE PROCEDURE usp_GetJobAdvancePaymentsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT jap.*, u.fullName AS recordedByName
    FROM JobAdvancePayments jap
    LEFT JOIN Users u ON jap.recordedBy = u.userId
    WHERE jap.jobId = @JobId
    ORDER BY jap.paymentMadeDate DESC, jap.advancePaymentId DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 25. usp_UpdateJobAdvancePaymentEntry
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateJobAdvancePaymentEntry', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJobAdvancePaymentEntry;
GO
CREATE PROCEDURE usp_UpdateJobAdvancePaymentEntry
    @JobId           VARCHAR(50),
    @PaymentId       INT,
    @Amount          DECIMAL(18,2),
    @PaymentMadeDate DATETIME,
    @PaymentType     VARCHAR(50),
    @CheckNo         VARCHAR(100),
    @Notes           NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE JobAdvancePayments
    SET amount          = @Amount,
        paymentMadeDate = @PaymentMadeDate,
        paymentType     = @PaymentType,
        checkNo         = @CheckNo,
        notes           = @Notes
    WHERE advancePaymentId = @PaymentId AND jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 26. usp_GetJobAdvancePaymentById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetJobAdvancePaymentById', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAdvancePaymentById;
GO
CREATE PROCEDURE usp_GetJobAdvancePaymentById
    @JobId     VARCHAR(50),
    @PaymentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT jap.*, u.fullName AS recordedByName
    FROM JobAdvancePayments jap
    LEFT JOIN Users u ON jap.recordedBy = u.userId
    WHERE jap.advancePaymentId = @PaymentId AND jap.jobId = @JobId;
END;
GO


-- -----------------------------------------------------------------------------
-- 27. usp_DeleteJobAdvancePaymentEntry
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteJobAdvancePaymentEntry', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteJobAdvancePaymentEntry;
GO
CREATE PROCEDURE usp_DeleteJobAdvancePaymentEntry
    @JobId     VARCHAR(50),
    @PaymentId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM JobAdvancePayments
    WHERE advancePaymentId = @PaymentId AND jobId = @JobId;
END;
GO
