-- =============================================================================
-- Stored Procedures: TransporterPayments
-- Repository: MSSQLTransporterPaymentRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_CreateTransporterPayment
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateTransporterPayment', 'P') IS NOT NULL
    DROP PROCEDURE usp_CreateTransporterPayment;
GO

CREATE PROCEDURE usp_CreateTransporterPayment
    @PaymentId     VARCHAR(50),
    @JobId         VARCHAR(50),
    @TransporterId VARCHAR(50),
    @Amount        DECIMAL(18, 2),
    @PaymentMethod VARCHAR(50),
    @PaymentDate   DATETIME,
    @Status        VARCHAR(50),
    @ChequeNumber  VARCHAR(100),
    @ChequeDate    DATE,
    @ChequeAmount  DECIMAL(18, 2),
    @BankName      NVARCHAR(200),
    @PaidBy        VARCHAR(50),
    @PaidByName    NVARCHAR(200),
    @Notes         NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO TransporterPayments (
        PaymentId, JobId, TransporterId, Amount, PaymentMethod, PaymentDate, Status,
        ChequeNumber, ChequeDate, ChequeAmount, BankName, PaidBy, PaidByName, Notes, CreatedDate
    )
    VALUES (
        @PaymentId, @JobId, @TransporterId, @Amount, @PaymentMethod, @PaymentDate, @Status,
        @ChequeNumber, @ChequeDate, @ChequeAmount, @BankName, @PaidBy, @PaidByName, @Notes, GETDATE()
    );
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetTransporterPaymentsByTransporterId
--    Optional filters: Status, FromDate, ToDate — pass NULL to skip each filter
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterPaymentsByTransporterId', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterPaymentsByTransporterId;
GO

CREATE PROCEDURE usp_GetTransporterPaymentsByTransporterId
    @TransporterId VARCHAR(50),
    @Status        VARCHAR(50)  = NULL,
    @FromDate      DATETIME     = NULL,
    @ToDate        DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM TransporterPayments
    WHERE TransporterId = @TransporterId
      AND (@Status   IS NULL OR Status      =  @Status)
      AND (@FromDate IS NULL OR PaymentDate >= @FromDate)
      AND (@ToDate   IS NULL OR PaymentDate <= @ToDate)
    ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetTransporterPaymentsByJobId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterPaymentsByJobId', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterPaymentsByJobId;
GO

CREATE PROCEDURE usp_GetTransporterPaymentsByJobId
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM TransporterPayments
    WHERE JobId = @JobId
    ORDER BY PaymentDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetTransporterPaymentById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterPaymentById', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterPaymentById;
GO

CREATE PROCEDURE usp_GetTransporterPaymentById
    @PaymentId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM TransporterPayments
    WHERE PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_UpdateTransporterPaymentStatus
--    Sets ClearedDate automatically when status is 'Cleared'
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateTransporterPaymentStatus', 'P') IS NOT NULL
    DROP PROCEDURE usp_UpdateTransporterPaymentStatus;
GO

CREATE PROCEDURE usp_UpdateTransporterPaymentStatus
    @PaymentId VARCHAR(50),
    @Status    VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE TransporterPayments
    SET
        Status      = @Status,
        ClearedDate = CASE WHEN @Status = 'Cleared' THEN GETDATE() ELSE ClearedDate END,
        UpdatedDate = GETDATE()
    WHERE PaymentId = @PaymentId;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_GetTransporterOutstandingBalance
--    Returns total outstanding amount (Pending + Bounced) for a transporter
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterOutstandingBalance', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterOutstandingBalance;
GO

CREATE PROCEDURE usp_GetTransporterOutstandingBalance
    @TransporterId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ISNULL(SUM(Amount), 0) AS TotalOutstanding
    FROM TransporterPayments
    WHERE TransporterId = @TransporterId
      AND Status IN ('Pending', 'Bounced');
END;
GO
