-- =============================================================================
-- Stored Procedures: Users
-- Repository: MSSQLUserRepository
-- Each procedure maps 1-to-1 with a repository method.
-- Run this script once against your database to create/replace all procedures.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. usp_AuthenticateUser
--    Used by: authenticate()
--    Returns the full user row for the given username if the account is active.
--    Password verification is done in application code (bcryptjs) — not here.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_AuthenticateUser', 'P') IS NOT NULL
    DROP PROCEDURE usp_AuthenticateUser;
GO

CREATE PROCEDURE usp_AuthenticateUser
    @UserName VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        Username,
        Password,
        FullName,
        Role,
        Email,
        CreatedDate,
        IsActive,
        isTemporaryPassword,
        passwordResetRequired,
        lastPasswordChange
    FROM Users
    WHERE Username = @UserName
      AND IsActive = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_CreateUser
--    Used by: create()
--    Inserts a new user record.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreateUser', 'P') IS NOT NULL
    DROP PROCEDURE usp_CreateUser;
GO

CREATE PROCEDURE usp_CreateUser
    @UserId                VARCHAR(50),
    @Username              VARCHAR(100),
    @Password              VARCHAR(255),
    @FullName              VARCHAR(255),
    @Role                  VARCHAR(50),
    @Email                 VARCHAR(255),
    @CreatedDate           DATETIME,
    @IsActive              BIT,
    @IsTemporaryPassword   BIT,
    @PasswordResetRequired BIT,
    @LastPasswordChange    DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Users (
        UserId, Username, Password, FullName, Role, Email,
        CreatedDate, IsActive, isTemporaryPassword,
        passwordResetRequired, lastPasswordChange
    )
    VALUES (
        @UserId, @Username, @Password, @FullName, @Role, @Email,
        @CreatedDate, @IsActive, @IsTemporaryPassword,
        @PasswordResetRequired, @LastPasswordChange
    );
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetUserById
--    Used by: findById()
--    Returns a single active user by primary key.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetUserById', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetUserById;
GO

CREATE PROCEDURE usp_GetUserById
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        Username,
        Password,
        FullName,
        Role,
        Email,
        CreatedDate,
        IsActive,
        isTemporaryPassword,
        passwordResetRequired,
        lastPasswordChange
    FROM Users
    WHERE UserId = @UserId
      AND IsActive = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetUserByUsername
--    Used by: findByUsername()
--    Returns a single active user by username.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetUserByUsername', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetUserByUsername;
GO

CREATE PROCEDURE usp_GetUserByUsername
    @Username VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        Username,
        Password,
        FullName,
        Role,
        Email,
        CreatedDate,
        IsActive,
        isTemporaryPassword,
        passwordResetRequired,
        lastPasswordChange
    FROM Users
    WHERE Username = @Username
      AND IsActive = 1;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetAllUsers
--    Used by: findAll()
--    Returns all active users ordered by UserId ascending.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllUsers', 'P') IS NOT NULL
    DROP PROCEDURE usp_GetAllUsers;
GO

CREATE PROCEDURE usp_GetAllUsers
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        Username,
        Password,
        FullName,
        Role,
        Email,
        CreatedDate,
        IsActive,
        isTemporaryPassword,
        passwordResetRequired,
        lastPasswordChange
    FROM Users
    WHERE IsActive = 1
    ORDER BY UserId ASC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_UpdateUser
--    Used by: update()
--    Updates profile fields (FullName, Role, Email) for a given user.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateUser', 'P') IS NOT NULL
    DROP PROCEDURE usp_UpdateUser;
GO

CREATE PROCEDURE usp_UpdateUser
    @UserId   VARCHAR(50),
    @FullName VARCHAR(255),
    @Role     VARCHAR(50),
    @Email    VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Users
    SET
        FullName = @FullName,
        Role     = @Role,
        Email    = @Email
    WHERE UserId = @UserId;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_DeleteUser
--    Used by: delete()
--    Soft-deletes a user by setting IsActive = 0.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeleteUser', 'P') IS NOT NULL
    DROP PROCEDURE usp_DeleteUser;
GO

CREATE PROCEDURE usp_DeleteUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Users
    SET IsActive = 0
    WHERE UserId = @UserId;
END;
GO


-- -----------------------------------------------------------------------------
-- 8. usp_UpdateUserPassword
--    Used by: updatePassword()
--    Updates the hashed password and related flags.
--    lastPasswordChange is set to server time internally — no caller input needed.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdateUserPassword', 'P') IS NOT NULL
    DROP PROCEDURE usp_UpdateUserPassword;
GO

CREATE PROCEDURE usp_UpdateUserPassword
    @UserId                VARCHAR(50),
    @Password              VARCHAR(255),
    @IsTemporaryPassword   BIT,
    @PasswordResetRequired BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Users
    SET
        Password              = @Password,
        isTemporaryPassword   = @IsTemporaryPassword,
        passwordResetRequired = @PasswordResetRequired,
        lastPasswordChange    = GETDATE()
    WHERE UserId = @UserId;
END;
GO


-- -----------------------------------------------------------------------------
-- 9. usp_GenerateNextUserId
--    Used by: generateNextId()
--    Returns the next available UserId in the format USER0001.
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GenerateNextUserId', 'P') IS NOT NULL
    DROP PROCEDURE usp_GenerateNextUserId;
GO

CREATE PROCEDURE usp_GenerateNextUserId
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxId INT;

    SELECT @MaxId = MAX(CAST(SUBSTRING(UserId, 5, 4) AS INT))
    FROM Users
    WHERE UserId LIKE 'USER[0-9][0-9][0-9][0-9]';

    SELECT 'USER' + RIGHT('0000' + CAST(ISNULL(@MaxId, 0) + 1 AS VARCHAR(4)), 4) AS NextUserId;
END;
GO
