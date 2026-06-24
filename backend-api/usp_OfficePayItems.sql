-- =============================================================================
-- Stored Procedures: OfficePayItems
-- Repository: MSSQLOfficePayItemRepository
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. usp_CreateOfficePayItem
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateOfficePayItem', 'P') IS NOT NULL DROP PROCEDURE usp_CreateOfficePayItem;
GO
CREATE PROCEDURE usp_CreateOfficePayItem
    @OfficePayItemId VARCHAR(50),
    @JobId           VARCHAR(50),
    @Description     NVARCHAR(500),
    @ActualCost      DECIMAL(18,2),
    @PaidBy          VARCHAR(50),
    @HasBill         BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO OfficePayItems (
        officePayItemId, jobId, description, actualCost,
        paidBy, hasBill, paymentDate, createdDate, updatedDate
    )
    VALUES (
        @OfficePayItemId, @JobId, @Description, @ActualCost,
        @PaidBy, @HasBill, GETDATE(), GETDATE(), GETDATE()
    );
END;
GO

-- -----------------------------------------------------------------------------
-- 2. usp_GetOfficePayItemById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOfficePayItemById', 'P') IS NOT NULL DROP PROCEDURE usp_GetOfficePayItemById;
GO
CREATE PROCEDURE usp_GetOfficePayItemById
    @OfficePayItemId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT opi.*, u.fullName AS paidByName
    FROM OfficePayItems opi
    LEFT JOIN Users u ON opi.paidBy = u.userId
    WHERE opi.officePayItemId = @OfficePayItemId;
END;
GO

-- -----------------------------------------------------------------------------
-- 3. usp_GetOfficePayItemsByJob
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
-- 4. usp_GetAllOfficePayItems
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllOfficePayItems', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllOfficePayItems;
GO
CREATE PROCEDURE usp_GetAllOfficePayItems
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        opi.*,
        u.fullName  AS paidByName,
        j.customerId,
        c.name      AS customerName
    FROM OfficePayItems opi
    LEFT JOIN Users     u ON opi.paidBy      = u.userId
    LEFT JOIN Jobs      j ON opi.jobId       = j.jobId
    LEFT JOIN Customers c ON j.customerId    = c.customerId
    ORDER BY opi.paymentDate DESC;
END;
GO

-- -----------------------------------------------------------------------------
-- 5. usp_UpdateOfficePayItem
--    Only updates fields that are passed as non-NULL (ISNULL pattern)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateOfficePayItem', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateOfficePayItem;
GO
CREATE PROCEDURE usp_UpdateOfficePayItem
    @OfficePayItemId VARCHAR(50),
    @Description     NVARCHAR(500),
    @ActualCost      DECIMAL(18,2),
    @BillingAmount   DECIMAL(18,2),
    @HasBill         BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE OfficePayItems
    SET description   = ISNULL(@Description,   description),
        actualCost    = ISNULL(@ActualCost,     actualCost),
        billingAmount = ISNULL(@BillingAmount,  billingAmount),
        hasBill       = ISNULL(@HasBill,        hasBill),
        updatedDate   = GETDATE()
    WHERE officePayItemId = @OfficePayItemId;
END;
GO

-- -----------------------------------------------------------------------------
-- 6. usp_DeleteOfficePayItem
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteOfficePayItem', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteOfficePayItem;
GO
CREATE PROCEDURE usp_DeleteOfficePayItem
    @OfficePayItemId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM OfficePayItems WHERE officePayItemId = @OfficePayItemId;
END;
GO

-- -----------------------------------------------------------------------------
-- 7. usp_GenerateNextOfficePayItemId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextOfficePayItemId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextOfficePayItemId;
GO
CREATE PROCEDURE usp_GenerateNextOfficePayItemId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(officePayItemId, 4, LEN(officePayItemId) - 3) AS INT))
    FROM OfficePayItems WHERE officePayItemId LIKE 'OPI%';
    SELECT 'OPI' + RIGHT('000000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(6)), 6) AS NextOfficePayItemId;
END;
GO
