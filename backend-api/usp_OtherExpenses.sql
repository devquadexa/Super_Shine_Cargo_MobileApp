-- =============================================================================
-- Stored Procedures: OtherExpenses
-- Repository: MSSQLOtherExpenseRepository
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. usp_CreateOtherExpense
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateOtherExpense', 'P') IS NOT NULL DROP PROCEDURE usp_CreateOtherExpense;
GO
CREATE PROCEDURE usp_CreateOtherExpense
    @ExpenseId       VARCHAR(50),
    @Category        NVARCHAR(100),
    @Description     NVARCHAR(500),
    @Amount          DECIMAL(18,2),
    @ExpenseDate     DATE,
    @PaymentMethod   NVARCHAR(50),
    @ReferenceNumber NVARCHAR(100),
    @Notes           NVARCHAR(MAX),
    @RecordedBy      VARCHAR(50),
    @CreatedDate     DATETIME,
    @AttachmentUrl   NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO OtherExpenses (
        expenseId, category, description, amount, expenseDate,
        paymentMethod, referenceNumber, notes, recordedBy, createdDate, attachmentUrl
    )
    VALUES (
        @ExpenseId, @Category, @Description, @Amount, @ExpenseDate,
        @PaymentMethod, @ReferenceNumber, @Notes, @RecordedBy, @CreatedDate, @AttachmentUrl
    );
END;
GO

-- -----------------------------------------------------------------------------
-- 2. usp_GetOtherExpenseById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOtherExpenseById', 'P') IS NOT NULL DROP PROCEDURE usp_GetOtherExpenseById;
GO
CREATE PROCEDURE usp_GetOtherExpenseById
    @ExpenseId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT oe.*, u.fullName AS recordedByName
    FROM OtherExpenses oe
    LEFT JOIN Users u ON oe.recordedBy = u.userId
    WHERE oe.expenseId = @ExpenseId;
END;
GO

-- -----------------------------------------------------------------------------
-- 3. usp_GetAllOtherExpenses
--    @Category, @FromDate, @ToDate are optional — pass NULL to skip
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllOtherExpenses', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllOtherExpenses;
GO
CREATE PROCEDURE usp_GetAllOtherExpenses
    @Category NVARCHAR(100) = NULL,
    @FromDate DATE          = NULL,
    @ToDate   DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT oe.*, u.fullName AS recordedByName
    FROM OtherExpenses oe
    LEFT JOIN Users u ON oe.recordedBy = u.userId
    WHERE (@Category IS NULL OR oe.category    =  @Category)
      AND (@FromDate IS NULL OR oe.expenseDate >= @FromDate)
      AND (@ToDate   IS NULL OR oe.expenseDate <= @ToDate)
    ORDER BY oe.expenseDate DESC, oe.createdDate DESC;
END;
GO

-- -----------------------------------------------------------------------------
-- 4. usp_GetOtherExpensesByDateRange
--    @Category optional — pass NULL for all categories
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOtherExpensesByDateRange', 'P') IS NOT NULL DROP PROCEDURE usp_GetOtherExpensesByDateRange;
GO
CREATE PROCEDURE usp_GetOtherExpensesByDateRange
    @FromDate DATE,
    @ToDate   DATE,
    @Category NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT oe.*, u.fullName AS recordedByName
    FROM OtherExpenses oe
    LEFT JOIN Users u ON oe.recordedBy = u.userId
    WHERE oe.expenseDate BETWEEN @FromDate AND @ToDate
      AND (@Category IS NULL OR oe.category = @Category)
    ORDER BY oe.expenseDate DESC, oe.createdDate DESC;
END;
GO

-- -----------------------------------------------------------------------------
-- 5. usp_UpdateOtherExpense
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateOtherExpense', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateOtherExpense;
GO
CREATE PROCEDURE usp_UpdateOtherExpense
    @ExpenseId       VARCHAR(50),
    @Category        NVARCHAR(100),
    @Description     NVARCHAR(500),
    @Amount          DECIMAL(18,2),
    @ExpenseDate     DATE,
    @PaymentMethod   NVARCHAR(50),
    @ReferenceNumber NVARCHAR(100),
    @Notes           NVARCHAR(MAX),
    @AttachmentUrl   NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE OtherExpenses
    SET category        = @Category,
        description     = @Description,
        amount          = @Amount,
        expenseDate     = @ExpenseDate,
        paymentMethod   = @PaymentMethod,
        referenceNumber = @ReferenceNumber,
        notes           = @Notes,
        attachmentUrl   = @AttachmentUrl
    WHERE expenseId = @ExpenseId;
END;
GO

-- -----------------------------------------------------------------------------
-- 6. usp_DeleteOtherExpense
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteOtherExpense', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteOtherExpense;
GO
CREATE PROCEDURE usp_DeleteOtherExpense
    @ExpenseId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM OtherExpenses WHERE expenseId = @ExpenseId;
END;
GO

-- -----------------------------------------------------------------------------
-- 7. usp_GenerateNextOtherExpenseId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextOtherExpenseId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextOtherExpenseId;
GO
CREATE PROCEDURE usp_GenerateNextOtherExpenseId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(expenseId, 4, 10) AS INT))
    FROM OtherExpenses WHERE expenseId LIKE 'EXP%';
    SELECT 'EXP' + RIGHT('00000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(5)), 5) AS NextExpenseId;
END;
GO

-- -----------------------------------------------------------------------------
-- 8. usp_GetOtherExpenseCategories
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOtherExpenseCategories', 'P') IS NOT NULL DROP PROCEDURE usp_GetOtherExpenseCategories;
GO
CREATE PROCEDURE usp_GetOtherExpenseCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT category FROM OtherExpenses ORDER BY category;
END;
GO

-- -----------------------------------------------------------------------------
-- 9. usp_GetOtherExpenseSummaryByCategory
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetOtherExpenseSummaryByCategory', 'P') IS NOT NULL DROP PROCEDURE usp_GetOtherExpenseSummaryByCategory;
GO
CREATE PROCEDURE usp_GetOtherExpenseSummaryByCategory
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        category,
        COUNT(*)     AS count,
        SUM(amount)  AS totalAmount
    FROM OtherExpenses
    WHERE expenseDate BETWEEN @FromDate AND @ToDate
    GROUP BY category
    ORDER BY totalAmount DESC;
END;
GO
