-- =============================================================================
-- Stored Procedures: ContactPersons + Categories + CustomerCategories
-- Repositories: MSSQLContactPersonRepository, MSSQLCategoryRepository
-- =============================================================================

-- ----------------------------- ContactPersons --------------------------------

IF OBJECT_ID('usp_CreateContactPerson', 'P') IS NOT NULL DROP PROCEDURE usp_CreateContactPerson;
GO
CREATE PROCEDURE usp_CreateContactPerson
    @ContactPersonId INT,
    @CustomerId      VARCHAR(50),
    @Name            VARCHAR(255),
    @Phone           VARCHAR(20),
    @Email           VARCHAR(255),
    @Designation     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ContactPersons (ContactPersonId, CustomerId, Name, Phone, Email, Designation)
    VALUES (@ContactPersonId, @CustomerId, @Name, @Phone, @Email, @Designation);
END;
GO

IF OBJECT_ID('usp_GetContactPersonsByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_GetContactPersonsByCustomer;
GO
CREATE PROCEDURE usp_GetContactPersonsByCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM ContactPersons
    WHERE CustomerId = @CustomerId ORDER BY ContactPersonId;
END;
GO

IF OBJECT_ID('usp_DeleteContactPersonsByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteContactPersonsByCustomer;
GO
CREATE PROCEDURE usp_DeleteContactPersonsByCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM ContactPersons WHERE CustomerId = @CustomerId;
END;
GO


-- -------------------------------- Categories ---------------------------------

IF OBJECT_ID('usp_GetAllCategories', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllCategories;
GO
CREATE PROCEDURE usp_GetAllCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Categories ORDER BY CategoryName;
END;
GO

IF OBJECT_ID('usp_GetCategoryById', 'P') IS NOT NULL DROP PROCEDURE usp_GetCategoryById;
GO
CREATE PROCEDURE usp_GetCategoryById
    @CategoryId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Categories WHERE CategoryId = @CategoryId;
END;
GO

IF OBJECT_ID('usp_GetCategoriesByCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_GetCategoriesByCustomer;
GO
CREATE PROCEDURE usp_GetCategoriesByCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.*
    FROM Categories c
    INNER JOIN CustomerCategories cc ON c.CategoryId = cc.CategoryId
    WHERE cc.CustomerId = @CustomerId
    ORDER BY c.CategoryName;
END;
GO

IF OBJECT_ID('usp_AssignCategoryToCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_AssignCategoryToCustomer;
GO
CREATE PROCEDURE usp_AssignCategoryToCustomer
    @CustomerId VARCHAR(50),
    @CategoryId INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO CustomerCategories (CustomerId, CategoryId)
    VALUES (@CustomerId, @CategoryId);
END;
GO

IF OBJECT_ID('usp_RemoveCategoriesFromCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_RemoveCategoriesFromCustomer;
GO
CREATE PROCEDURE usp_RemoveCategoriesFromCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM CustomerCategories WHERE CustomerId = @CustomerId;
END;
GO
