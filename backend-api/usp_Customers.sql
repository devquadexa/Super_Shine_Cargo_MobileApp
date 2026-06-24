-- =============================================================================
-- Stored Procedures: Customers
-- Repository: MSSQLCustomerRepository
-- =============================================================================

IF OBJECT_ID('usp_CreateCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_CreateCustomer;
GO
CREATE PROCEDURE usp_CreateCustomer
    @CustomerId            VARCHAR(50),
    @Name                  VARCHAR(255),
    @MainPhone             VARCHAR(20),
    @Email                 VARCHAR(255),
    @AddressNumber         VARCHAR(100),
    @AddressStreet1        VARCHAR(200),
    @AddressStreet2        VARCHAR(200),
    @AddressDistrict       VARCHAR(100),
    @AddressCity           VARCHAR(100),
    @AddressCountry        VARCHAR(100),
    @OfficeAddressNumber   VARCHAR(100),
    @OfficeAddressStreet1  VARCHAR(200),
    @OfficeAddressStreet2  VARCHAR(200),
    @OfficeAddressDistrict VARCHAR(100),
    @OfficeAddressCity     VARCHAR(100),
    @OfficeAddressCountry  VARCHAR(100),
    @IsOfficeAddressSame   BIT,
    @Website               VARCHAR(255),
    @RegistrationDate      DATETIME,
    @CreditPeriodDays      INT,
    @IsActive              BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Customers (
        CustomerId, Name, MainPhone, Email,
        addressNumber, addressStreet1, addressStreet2, addressDistrict, addressCity, addressCountry,
        officeAddressNumber, officeAddressStreet1, officeAddressStreet2, officeAddressDistrict,
        officeAddressCity, officeAddressCountry, isOfficeAddressSame,
        Website, RegistrationDate, creditPeriodDays, IsActive
    )
    VALUES (
        @CustomerId, @Name, @MainPhone, @Email,
        @AddressNumber, @AddressStreet1, @AddressStreet2, @AddressDistrict, @AddressCity, @AddressCountry,
        @OfficeAddressNumber, @OfficeAddressStreet1, @OfficeAddressStreet2, @OfficeAddressDistrict,
        @OfficeAddressCity, @OfficeAddressCountry, @IsOfficeAddressSame,
        @Website, @RegistrationDate, @CreditPeriodDays, @IsActive
    );
END;
GO

IF OBJECT_ID('usp_GetCustomerById', 'P') IS NOT NULL DROP PROCEDURE usp_GetCustomerById;
GO
CREATE PROCEDURE usp_GetCustomerById
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Customers WHERE CustomerId = @CustomerId;
END;
GO

IF OBJECT_ID('usp_GetAllCustomers', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllCustomers;
GO
CREATE PROCEDURE usp_GetAllCustomers
    @Name VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Customers
    WHERE IsActive = 1
      AND (@Name IS NULL OR Name LIKE '%' + @Name + '%')
    ORDER BY CustomerId ASC;
END;
GO

IF OBJECT_ID('usp_UpdateCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateCustomer;
GO
CREATE PROCEDURE usp_UpdateCustomer
    @CustomerId            VARCHAR(50),
    @Name                  VARCHAR(255),
    @MainPhone             VARCHAR(20),
    @Email                 VARCHAR(255),
    @AddressNumber         VARCHAR(100),
    @AddressStreet1        VARCHAR(200),
    @AddressStreet2        VARCHAR(200),
    @AddressDistrict       VARCHAR(100),
    @AddressCity           VARCHAR(100),
    @AddressCountry        VARCHAR(100),
    @OfficeAddressNumber   VARCHAR(100),
    @OfficeAddressStreet1  VARCHAR(200),
    @OfficeAddressStreet2  VARCHAR(200),
    @OfficeAddressDistrict VARCHAR(100),
    @OfficeAddressCity     VARCHAR(100),
    @OfficeAddressCountry  VARCHAR(100),
    @IsOfficeAddressSame   BIT,
    @Website               VARCHAR(255),
    @CreditPeriodDays      INT,
    @IsActive              BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Customers
    SET Name                  = @Name,
        MainPhone             = @MainPhone,
        Email                 = @Email,
        addressNumber         = @AddressNumber,
        addressStreet1        = @AddressStreet1,
        addressStreet2        = @AddressStreet2,
        addressDistrict       = @AddressDistrict,
        addressCity           = @AddressCity,
        addressCountry        = @AddressCountry,
        officeAddressNumber   = @OfficeAddressNumber,
        officeAddressStreet1  = @OfficeAddressStreet1,
        officeAddressStreet2  = @OfficeAddressStreet2,
        officeAddressDistrict = @OfficeAddressDistrict,
        officeAddressCity     = @OfficeAddressCity,
        officeAddressCountry  = @OfficeAddressCountry,
        isOfficeAddressSame   = @IsOfficeAddressSame,
        Website               = @Website,
        creditPeriodDays      = @CreditPeriodDays,
        IsActive              = @IsActive
    WHERE CustomerId = @CustomerId;
END;
GO

IF OBJECT_ID('usp_DeleteCustomer', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteCustomer;
GO
CREATE PROCEDURE usp_DeleteCustomer
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Customers SET IsActive = 0 WHERE CustomerId = @CustomerId;
END;
GO

IF OBJECT_ID('usp_CustomerExists', 'P') IS NOT NULL DROP PROCEDURE usp_CustomerExists;
GO
CREATE PROCEDURE usp_CustomerExists
    @CustomerId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS count FROM Customers WHERE CustomerId = @CustomerId;
END;
GO

IF OBJECT_ID('usp_GetCustomerByEmail', 'P') IS NOT NULL DROP PROCEDURE usp_GetCustomerByEmail;
GO
CREATE PROCEDURE usp_GetCustomerByEmail
    @Email VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Customers WHERE Email = @Email AND IsActive = 1;
END;
GO

IF OBJECT_ID('usp_GenerateNextCustomerId', 'P') IS NOT NULL DROP PROCEDURE usp_GenerateNextCustomerId;
GO
CREATE PROCEDURE usp_GenerateNextCustomerId
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaxId INT;
    SELECT @MaxId = MAX(CAST(SUBSTRING(CustomerId, 5, 4) AS INT))
    FROM Customers WHERE CustomerId LIKE 'CUST[0-9][0-9][0-9][0-9]';
    SELECT 'CUST' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextCustomerId;
END;
GO
