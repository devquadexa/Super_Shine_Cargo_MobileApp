-- =============================================================================
-- Stored Procedures: Bills
-- Repository: MSSQLBillRepository
-- =============================================================================

IF OBJECT_ID('usp_CreateBill', 'P') IS NOT NULL DROP PROCEDURE usp_CreateBill;
GO
CREATE PROCEDURE usp_CreateBill
    @BillId         VARCHAR(50),
    @JobId          VARCHAR(50),
    @CustomerId     VARCHAR(50),
    @Amount         DECIMAL(10,2),
    @Tax            DECIMAL(10,2),
    @Total          DECIMAL(10,2),
    @ActualCost     DECIMAL(10,2),
    @BillingAmount  DECIMAL(10,2),
    @Profit         DECIMAL(10,2),
    @AdvancePayment DECIMAL(18,2),
    @GrossTotal     DECIMAL(18,2),
    @NetTotal       DECIMAL(18,2),
    @PaymentStatus  VARCHAR(50),
    @InvoiceNumber  VARCHAR(100),
    @InvoiceDate    DATETIME,
    @DueDate        DATETIME,
    @IsOverdue      BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Bills (
        BillId, JobId, CustomerId, Amount, Tax, Total, ActualCost, BillingAmount,
        Profit, advancePayment, grossTotal, netTotal, PaymentStatus, InvoiceNumber,
        CreatedDate, BillDate, invoiceDate, dueDate, isOverdue
    )
    VALUES (
        @BillId, @JobId, @CustomerId, @Amount, @Tax, @Total, @ActualCost, @BillingAmount,
        @Profit, @AdvancePayment, @GrossTotal, @NetTotal, @PaymentStatus, @InvoiceNumber,
        GETDATE(), GETDATE(), @InvoiceDate, @DueDate, @IsOverdue
    );
END;
GO

IF OBJECT_ID('usp_GetBillById', 'P') IS NOT NULL DROP PROCEDURE usp_GetBillById;
GO
CREATE PROCEDURE usp_GetBillById
    @BillId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Bills WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_GetAllBills', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllBills;
GO
CREATE PROCEDURE usp_GetAllBills
    @PaymentStatus VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Bills
    WHERE (@PaymentStatus IS NULL OR PaymentStatus = @PaymentStatus)
    ORDER BY CreatedDate DESC;
END;
GO

IF OBJECT_ID('usp_GetBillsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetBillsByJob;
GO
CREATE PROCEDURE usp_GetBillsByJob
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Bills WHERE JobId = @JobId;
END;
GO

IF OBJECT_ID('usp_GetBillsByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_GetBillsByCustomer;
GO
CREATE PROCEDURE usp_GetBillsByCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Bills WHERE CustomerId = @CustomerId ORDER BY CreatedDate DESC;
END;
GO

IF OBJECT_ID('usp_GetUnpaidBills', 'P') IS NOT NULL DROP PROCEDURE usp_GetUnpaidBills;
GO
CREATE PROCEDURE usp_GetUnpaidBills
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Bills WHERE PaymentStatus = 'Unpaid' ORDER BY CreatedDate DESC;
END;
GO

IF OBJECT_ID('usp_UpdateBill', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateBill;
GO
CREATE PROCEDURE usp_UpdateBill
    @BillId         VARCHAR(50),
    @Amount         DECIMAL(10,2),
    @Tax            DECIMAL(10,2),
    @Total          DECIMAL(10,2),
    @AdvancePayment DECIMAL(18,2),
    @GrossTotal     DECIMAL(18,2),
    @NetTotal       DECIMAL(18,2),
    @PaymentStatus  VARCHAR(50),
    @IsOverdue      BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Bills
    SET Amount         = ISNULL(@Amount,         Amount),
        Tax            = ISNULL(@Tax,            Tax),
        Total          = ISNULL(@Total,          Total),
        advancePayment = ISNULL(@AdvancePayment, advancePayment),
        grossTotal     = ISNULL(@GrossTotal,     grossTotal),
        netTotal       = ISNULL(@NetTotal,       netTotal),
        PaymentStatus  = ISNULL(@PaymentStatus,  PaymentStatus),
        isOverdue      = ISNULL(@IsOverdue,      isOverdue)
    WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_MarkBillAsPaid', 'P') IS NOT NULL DROP PROCEDURE usp_MarkBillAsPaid;
GO
CREATE PROCEDURE usp_MarkBillAsPaid
    @BillId          VARCHAR(50),
    @PaidDate        DATETIME,
    @PaidAmount      DECIMAL(18,2),
    @RemainingAmount DECIMAL(18,2),
    @PaymentMethod   VARCHAR(50),
    @ChequeNumber    VARCHAR(100),
    @ChequeDate      DATE,
    @ChequeAmount    DECIMAL(18,2),
    @BankName        VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Bills
    SET PaymentStatus   = 'Paid',
        paidDate        = @PaidDate,
        paidAmount      = @PaidAmount,
        remainingAmount = @RemainingAmount,
        paymentMethod   = ISNULL(@PaymentMethod,  paymentMethod),
        chequeNumber    = ISNULL(@ChequeNumber,   chequeNumber),
        chequeDate      = ISNULL(@ChequeDate,     chequeDate),
        chequeAmount    = ISNULL(@ChequeAmount,   chequeAmount),
        bankName        = ISNULL(@BankName,       bankName)
    WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_ApplyBillPartialPayment', 'P') IS NOT NULL DROP PROCEDURE usp_ApplyBillPartialPayment;
GO
CREATE PROCEDURE usp_ApplyBillPartialPayment
    @BillId          VARCHAR(50),
    @PaidAmount      DECIMAL(18,2),
    @RemainingAmount DECIMAL(18,2),
    @PaymentStatus   VARCHAR(50),
    @PaidDate        DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Bills
    SET paidAmount      = @PaidAmount,
        remainingAmount = @RemainingAmount,
        PaymentStatus   = @PaymentStatus,
        paidDate        = @PaidDate
    WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_ReplaceBill', 'P') IS NOT NULL DROP PROCEDURE usp_ReplaceBill;
GO
CREATE PROCEDURE usp_ReplaceBill
    @BillId         VARCHAR(50),
    @CustomerId     VARCHAR(50),
    @Amount         DECIMAL(10,2),
    @Tax            DECIMAL(10,2),
    @Total          DECIMAL(10,2),
    @ActualCost     DECIMAL(10,2),
    @BillingAmount  DECIMAL(10,2),
    @Profit         DECIMAL(10,2),
    @AdvancePayment DECIMAL(18,2),
    @GrossTotal     DECIMAL(18,2),
    @NetTotal       DECIMAL(18,2),
    @PaymentStatus  VARCHAR(50),
    @InvoiceNumber  VARCHAR(100),
    @InvoiceDate    DATETIME,
    @DueDate        DATETIME,
    @IsOverdue      BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Bills
    SET CustomerId     = @CustomerId,
        Amount         = @Amount,
        Tax            = @Tax,
        Total          = @Total,
        ActualCost     = @ActualCost,
        BillingAmount  = @BillingAmount,
        Profit         = @Profit,
        advancePayment = @AdvancePayment,
        grossTotal     = @GrossTotal,
        netTotal       = @NetTotal,
        PaymentStatus  = @PaymentStatus,
        InvoiceNumber  = @InvoiceNumber,
        invoiceDate    = @InvoiceDate,
        dueDate        = @DueDate,
        isOverdue      = @IsOverdue,
        BillDate       = GETDATE()
    WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_DeleteBill', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteBill;
GO
CREATE PROCEDURE usp_DeleteBill
    @BillId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Bills WHERE BillId = @BillId;
END;
GO

IF OBJECT_ID('usp_GenerateNextBillId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextBillId;
GO
CREATE PROCEDURE usp_GenerateNextBillId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(BillId, 5, 4) AS INT))
    FROM Bills WHERE BillId LIKE 'BILL[0-9][0-9][0-9][0-9]';
    SELECT 'BILL' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextBillId;
END;
GO
