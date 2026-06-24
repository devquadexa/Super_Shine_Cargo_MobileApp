-- =============================================================================
-- Stored Procedures: Payments
-- Repository: MSSQLPaymentRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_CreatePayment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreatePayment', 'P') IS NOT NULL DROP PROCEDURE usp_CreatePayment;
GO
CREATE PROCEDURE usp_CreatePayment
    @PaymentId       VARCHAR(50),
    @JobId           VARCHAR(50),
    @CustomerId      VARCHAR(20),
    @CustomerName    NVARCHAR(255),
    @InvoiceNumber   VARCHAR(100),
    @BillId          VARCHAR(50),
    @PaymentMethod   VARCHAR(50),
    @PaymentDate     DATETIME,
    @Amount          DECIMAL(18,2),
    @Status          VARCHAR(50),
    @ChequeNumber    VARCHAR(100),
    @ChequeDate      DATE,
    @ChequeAmount    DECIMAL(18,2),
    @BankName        NVARCHAR(200),
    @ReferenceNumber VARCHAR(100),
    @Notes           NVARCHAR(MAX),
    @CreatedBy       VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Payments (
        PaymentId, JobId, CustomerId, CustomerName, InvoiceNumber, BillId,
        PaymentMethod, PaymentDate, Amount, Status,
        ChequeNumber, ChequeDate, ChequeAmount, BankName, ReferenceNumber,
        Notes, CreatedBy, CreatedDate
    )
    VALUES (
        @PaymentId, @JobId, @CustomerId, @CustomerName, @InvoiceNumber, @BillId,
        @PaymentMethod, @PaymentDate, @Amount, @Status,
        @ChequeNumber, @ChequeDate, @ChequeAmount, @BankName, @ReferenceNumber,
        @Notes, @CreatedBy, GETDATE()
    );
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetPaymentById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentById', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentById;
GO
CREATE PROCEDURE usp_GetPaymentById
    @PaymentId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, j.CUSDECNumber, j.CUSDECDate
    FROM Payments p
    LEFT JOIN Jobs j ON p.JobId = j.JobId
    WHERE p.PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetAllPayments
--    All filters optional — pass NULL to skip each one
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllPayments', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllPayments;
GO
CREATE PROCEDURE usp_GetAllPayments
    @Status        VARCHAR(50)  = NULL,
    @PaymentMethod VARCHAR(50)  = NULL,
    @CustomerId    VARCHAR(20)  = NULL,
    @JobId         VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, j.CUSDECNumber, j.CUSDECDate
    FROM Payments p
    LEFT JOIN Jobs j ON p.JobId = j.JobId
    WHERE (@Status        IS NULL OR p.Status        = @Status)
      AND (@PaymentMethod IS NULL OR p.PaymentMethod = @PaymentMethod)
      AND (@CustomerId    IS NULL OR p.CustomerId    = @CustomerId)
      AND (@JobId         IS NULL OR p.JobId         = @JobId)
    ORDER BY p.PaymentDate DESC, p.CreatedDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetPaymentsByJob
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByJob;
GO
CREATE PROCEDURE usp_GetPaymentsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Payments WHERE JobId = @JobId ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetPaymentsByCustomer
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByCustomer;
GO
CREATE PROCEDURE usp_GetPaymentsByCustomer
    @CustomerId VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Payments WHERE CustomerId = @CustomerId ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_GetPaymentsByBillId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByBillId', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByBillId;
GO
CREATE PROCEDURE usp_GetPaymentsByBillId
    @BillId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, j.CUSDECNumber, j.CUSDECDate
    FROM Payments p
    LEFT JOIN Jobs j ON p.JobId = j.JobId
    WHERE p.BillId = @BillId
    ORDER BY p.PaymentDate ASC, p.CreatedDate ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_GetPaymentsByChequeNumber
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByChequeNumber', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByChequeNumber;
GO
CREATE PROCEDURE usp_GetPaymentsByChequeNumber
    @ChequeNumber VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Payments
    WHERE ChequeNumber = @ChequeNumber AND PaymentMethod = 'Cheque'
    ORDER BY PaymentDate ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_GetPaymentsByStatus
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByStatus', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByStatus;
GO
CREATE PROCEDURE usp_GetPaymentsByStatus
    @Status VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Payments WHERE Status = @Status ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 9. usp_GetPaymentsByMethod
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPaymentsByMethod', 'P') IS NOT NULL DROP PROCEDURE usp_GetPaymentsByMethod;
GO
CREATE PROCEDURE usp_GetPaymentsByMethod
    @PaymentMethod VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Payments WHERE PaymentMethod = @PaymentMethod ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 10. usp_UpdatePaymentStatus
--     Sets ClearedDate when status = 'Cleared', BouncedDate when 'Bounced'
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePaymentStatus', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePaymentStatus;
GO
CREATE PROCEDURE usp_UpdatePaymentStatus
    @PaymentId  VARCHAR(50),
    @Status     VARCHAR(50),
    @StatusDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Payments
    SET Status      = @Status,
        UpdatedDate = GETDATE(),
        ClearedDate = CASE WHEN @Status = 'Cleared' THEN @StatusDate ELSE ClearedDate END,
        BouncedDate = CASE WHEN @Status = 'Bounced' THEN @StatusDate ELSE BouncedDate END
    WHERE PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 11. usp_UpdatePayment
--     Partial update — only overwrites fields that are passed as non-NULL.
--     Pass NULL for any field you do NOT want to change.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePayment', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePayment;
GO
CREATE PROCEDURE usp_UpdatePayment
    @PaymentId       VARCHAR(50),
    @Status          VARCHAR(50),
    @Amount          DECIMAL(18,2),
    @ChequeNumber    VARCHAR(100),
    @ChequeDate      DATE,
    @BankName        NVARCHAR(200),
    @ReferenceNumber VARCHAR(100),
    @Notes           NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Payments
    SET Status          = ISNULL(@Status,          Status),
        Amount          = ISNULL(@Amount,           Amount),
        ChequeNumber    = ISNULL(@ChequeNumber,     ChequeNumber),
        ChequeDate      = ISNULL(@ChequeDate,       ChequeDate),
        BankName        = ISNULL(@BankName,         BankName),
        ReferenceNumber = ISNULL(@ReferenceNumber,  ReferenceNumber),
        Notes           = ISNULL(@Notes,            Notes),
        UpdatedDate     = GETDATE()
    WHERE PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 12. usp_DeletePayment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeletePayment', 'P') IS NOT NULL DROP PROCEDURE usp_DeletePayment;
GO
CREATE PROCEDURE usp_DeletePayment
    @PaymentId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Payments WHERE PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 13. usp_GenerateNextPaymentId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextPaymentId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextPaymentId;
GO
CREATE PROCEDURE usp_GenerateNextPaymentId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(PaymentId, 4, LEN(PaymentId) - 3) AS INT))
    FROM Payments WHERE PaymentId LIKE 'PAY%';
    SELECT 'PAY' + RIGHT('000000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(6)), 6) AS NextPaymentId;
END;
GO
