-- =============================================================================
-- Stored Procedures: Transporters
-- Repository: MSSQLTransporterRepository
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_CreateTransporter
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateTransporter', 'P') IS NOT NULL
    DROP PROCEDURE usp_CreateTransporter;
GO

CREATE PROCEDURE usp_CreateTransporter
    @TransporterId      VARCHAR(50),
    @Name               NVARCHAR(200),
    @Phone              VARCHAR(20),
    @Email              VARCHAR(100),
    @LorryNumber        NVARCHAR(100),
    @TransporterType    NVARCHAR(50),
    @DriverName         NVARCHAR(200),
    @Size               NVARCHAR(100),
    @RegistrationDate   DATETIME,
    @AddressNumber      NVARCHAR(100),
    @AddressStreet1     NVARCHAR(200),
    @AddressStreet2     NVARCHAR(200),
    @AddressDistrict    NVARCHAR(100),
    @AddressCity        NVARCHAR(100),
    @AddressCountry     NVARCHAR(100),
    @ContactPersonsJson NVARCHAR(MAX),
    @ContactPerson      NVARCHAR(150),
    @Address            NVARCHAR(500),
    @VehicleNumber      NVARCHAR(100),
    @Notes              NVARCHAR(MAX),
    @CreatedDate        DATETIME,
    @IsActive           BIT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Transporters (
        transporterId, name, phone, email, lorryNumber, transporterType,
        driverName, size, registrationDate,
        addressNumber, addressStreet1, addressStreet2, addressDistrict, addressCity, addressCountry,
        contactPersonsJson, contactPerson, address,
        vehicleNumber, notes, createdDate, isActive
    )
    VALUES (
        @TransporterId, @Name, @Phone, @Email, @LorryNumber, @TransporterType,
        @DriverName, @Size, @RegistrationDate,
        @AddressNumber, @AddressStreet1, @AddressStreet2, @AddressDistrict, @AddressCity, @AddressCountry,
        @ContactPersonsJson, @ContactPerson, @Address,
        @VehicleNumber, @Notes, @CreatedDate, @IsActive
    );
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetTransporterById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterById', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterById;
GO

CREATE PROCEDURE usp_GetTransporterById
    @TransporterId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM Transporters
    WHERE transporterId = @TransporterId;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetAllTransporters
--    @Name: optional filter — pass NULL to return all active transporters
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllTransporters', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetAllTransporters;
GO

CREATE PROCEDURE usp_GetAllTransporters
    @Name NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM Transporters
    WHERE isActive = 1
      AND (@Name IS NULL OR name LIKE '%' + @Name + '%')
    ORDER BY transporterId ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_UpdateTransporter
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateTransporter', 'P') IS NOT NULL
    DROP PROCEDURE usp_UpdateTransporter;
GO

CREATE PROCEDURE usp_UpdateTransporter
    @TransporterId      VARCHAR(50),
    @Name               NVARCHAR(200),
    @Phone              VARCHAR(20),
    @Email              VARCHAR(100),
    @LorryNumber        NVARCHAR(100),
    @TransporterType    NVARCHAR(50),
    @DriverName         NVARCHAR(200),
    @Size               NVARCHAR(100),
    @RegistrationDate   DATETIME,
    @AddressNumber      NVARCHAR(100),
    @AddressStreet1     NVARCHAR(200),
    @AddressStreet2     NVARCHAR(200),
    @AddressDistrict    NVARCHAR(100),
    @AddressCity        NVARCHAR(100),
    @AddressCountry     NVARCHAR(100),
    @ContactPersonsJson NVARCHAR(MAX),
    @ContactPerson      NVARCHAR(150),
    @Address            NVARCHAR(500),
    @VehicleNumber      NVARCHAR(100),
    @Notes              NVARCHAR(MAX),
    @IsActive           BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Transporters
    SET
        name               = @Name,
        phone              = @Phone,
        email              = @Email,
        lorryNumber        = @LorryNumber,
        transporterType    = @TransporterType,
        driverName         = @DriverName,
        size               = @Size,
        registrationDate   = @RegistrationDate,
        addressNumber      = @AddressNumber,
        addressStreet1     = @AddressStreet1,
        addressStreet2     = @AddressStreet2,
        addressDistrict    = @AddressDistrict,
        addressCity        = @AddressCity,
        addressCountry     = @AddressCountry,
        contactPersonsJson = @ContactPersonsJson,
        contactPerson      = @ContactPerson,
        address            = @Address,
        vehicleNumber      = @VehicleNumber,
        notes              = @Notes,
        isActive           = @IsActive
    WHERE transporterId = @TransporterId;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_DeleteTransporter  (soft delete)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteTransporter', 'P') IS NOT NULL
    DROP PROCEDURE usp_DeleteTransporter;
GO

CREATE PROCEDURE usp_DeleteTransporter
    @TransporterId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Transporters
    SET isActive = 0
    WHERE transporterId = @TransporterId;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_TransporterExists
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_TransporterExists', 'P') IS NOT NULL
    DROP PROCEDURE usp_TransporterExists;
GO

CREATE PROCEDURE usp_TransporterExists
    @TransporterId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS Count
    FROM Transporters
    WHERE transporterId = @TransporterId;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_GetTransporterByEmail
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterByEmail', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterByEmail;
GO

CREATE PROCEDURE usp_GetTransporterByEmail
    @Email VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM Transporters
    WHERE email = @Email
      AND isActive = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_GetTransporterByName
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetTransporterByName', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetTransporterByName;
GO

CREATE PROCEDURE usp_GetTransporterByName
    @Name NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM Transporters
    WHERE name = @Name
      AND isActive = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 9. usp_GenerateNextTransporterId
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextTransporterId', 'P') IS NOT NULL
    DROP PROCEDURE usp_GenerateNextTransporterId;
GO

CREATE PROCEDURE usp_GenerateNextTransporterId
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxId INT;

    SELECT @MaxId = MAX(CAST(SUBSTRING(transporterId, 4, 10) AS INT))
    FROM Transporters
    WHERE transporterId LIKE 'TRN%';

    SELECT 'TRN' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextTransporterId;
END;
GO
