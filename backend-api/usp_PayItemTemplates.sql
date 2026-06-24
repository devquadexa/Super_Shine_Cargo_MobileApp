-- =============================================================================
-- Stored Procedures: PayItemTemplates
-- Repository: MSSQLPayItemTemplateRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_GetPayItemTemplatesByCategory
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPayItemTemplatesByCategory', 'P') IS NOT NULL DROP PROCEDURE usp_GetPayItemTemplatesByCategory;
GO
CREATE PROCEDURE usp_GetPayItemTemplatesByCategory
    @ShipmentCategory NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT templateId, shipmentCategory, itemName, itemOrder, isActive, createdDate
    FROM PayItemTemplates
    WHERE shipmentCategory = @ShipmentCategory AND isActive = 1
    ORDER BY itemOrder ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetAllPayItemTemplates
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllPayItemTemplates', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllPayItemTemplates;
GO
CREATE PROCEDURE usp_GetAllPayItemTemplates
AS
BEGIN
    SET NOCOUNT ON;
    SELECT templateId, shipmentCategory, itemName, itemOrder, isActive, createdDate
    FROM PayItemTemplates
    WHERE isActive = 1
    ORDER BY shipmentCategory, itemOrder ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_CreatePayItemTemplate
--    Automatically assigns next itemOrder for the category
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreatePayItemTemplate', 'P') IS NOT NULL DROP PROCEDURE usp_CreatePayItemTemplate;
GO
CREATE PROCEDURE usp_CreatePayItemTemplate
    @ShipmentCategory NVARCHAR(100),
    @ItemName         NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NextOrder INT;
    SELECT @NextOrder = ISNULL(MAX(itemOrder), 0) + 1
    FROM PayItemTemplates
    WHERE shipmentCategory = @ShipmentCategory;

    INSERT INTO PayItemTemplates (shipmentCategory, itemName, itemOrder)
    OUTPUT INSERTED.*
    VALUES (@ShipmentCategory, @ItemName, @NextOrder);
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_UpdatePayItemTemplate
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePayItemTemplate', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePayItemTemplate;
GO
CREATE PROCEDURE usp_UpdatePayItemTemplate
    @TemplateId INT,
    @ItemName   NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PayItemTemplates
    SET itemName = @ItemName
    OUTPUT INSERTED.*
    WHERE templateId = @TemplateId;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_DeletePayItemTemplate  (soft delete)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeletePayItemTemplate', 'P') IS NOT NULL DROP PROCEDURE usp_DeletePayItemTemplate;
GO
CREATE PROCEDURE usp_DeletePayItemTemplate
    @TemplateId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PayItemTemplates SET isActive = 0 WHERE templateId = @TemplateId;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_ReorderPayItemTemplate
--    Called per item inside a transaction from reorder()
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_ReorderPayItemTemplate', 'P') IS NOT NULL DROP PROCEDURE usp_ReorderPayItemTemplate;
GO
CREATE PROCEDURE usp_ReorderPayItemTemplate
    @TemplateId INT,
    @ItemOrder  INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PayItemTemplates SET itemOrder = @ItemOrder WHERE templateId = @TemplateId;
END;
GO
