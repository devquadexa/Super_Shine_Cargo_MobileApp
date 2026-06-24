-- =============================================================================
-- Stored Procedures: PasswordResetRequests
-- Repository: MSSQLPasswordResetRepository
-- =============================================================================

-- Shared SELECT columns used across all read procedures:
-- pr.*, u1.username, u1.fullName, u2.fullName, u3.fullName (via JOINs)


-- -----------------------------------------------------------------------------
-- 1. usp_CreatePasswordResetRequest
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_CreatePasswordResetRequest', 'P') IS NOT NULL DROP PROCEDURE usp_CreatePasswordResetRequest;
GO
CREATE PROCEDURE usp_CreatePasswordResetRequest
    @RequestId   VARCHAR(50),
    @UserId      VARCHAR(50),
    @RequestedBy VARCHAR(50),
    @RequestDate DATETIME,
    @Status      VARCHAR(50),
    @Notes       NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO PasswordResetRequests (requestId, userId, requestedBy, requestDate, status, notes)
    VALUES (@RequestId, @UserId, @RequestedBy, @RequestDate, @Status, @Notes);
END;
GO


-- -----------------------------------------------------------------------------
-- 2. usp_GetPasswordResetRequestById
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPasswordResetRequestById', 'P') IS NOT NULL DROP PROCEDURE usp_GetPasswordResetRequestById;
GO
CREATE PROCEDURE usp_GetPasswordResetRequestById
    @RequestId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pr.*,
        u1.username  AS userName,
        u1.fullName  AS userFullName,
        u2.fullName  AS requestedByName,
        u3.fullName  AS resolvedByName
    FROM PasswordResetRequests pr
    INNER JOIN Users u1 ON pr.userId      = u1.userId
    INNER JOIN Users u2 ON pr.requestedBy = u2.userId
    LEFT  JOIN Users u3 ON pr.resolvedBy  = u3.userId
    WHERE pr.requestId = @RequestId;
END;
GO


-- -----------------------------------------------------------------------------
-- 3. usp_GetPasswordResetRequestsByUser
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPasswordResetRequestsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetPasswordResetRequestsByUser;
GO
CREATE PROCEDURE usp_GetPasswordResetRequestsByUser
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pr.*,
        u1.username  AS userName,
        u1.fullName  AS userFullName,
        u2.fullName  AS requestedByName,
        u3.fullName  AS resolvedByName
    FROM PasswordResetRequests pr
    INNER JOIN Users u1 ON pr.userId      = u1.userId
    INNER JOIN Users u2 ON pr.requestedBy = u2.userId
    LEFT  JOIN Users u3 ON pr.resolvedBy  = u3.userId
    WHERE pr.userId = @UserId
    ORDER BY pr.requestDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 4. usp_GetPendingPasswordResetRequests
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetPendingPasswordResetRequests', 'P') IS NOT NULL DROP PROCEDURE usp_GetPendingPasswordResetRequests;
GO
CREATE PROCEDURE usp_GetPendingPasswordResetRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pr.*,
        u1.username  AS userName,
        u1.fullName  AS userFullName,
        u2.fullName  AS requestedByName,
        u3.fullName  AS resolvedByName
    FROM PasswordResetRequests pr
    INNER JOIN Users u1 ON pr.userId      = u1.userId
    INNER JOIN Users u2 ON pr.requestedBy = u2.userId
    LEFT  JOIN Users u3 ON pr.resolvedBy  = u3.userId
    WHERE pr.status = 'Pending'
    ORDER BY pr.requestDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 5. usp_GetAllPasswordResetRequests
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_GetAllPasswordResetRequests', 'P') IS NOT NULL DROP PROCEDURE usp_GetAllPasswordResetRequests;
GO
CREATE PROCEDURE usp_GetAllPasswordResetRequests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pr.*,
        u1.username  AS userName,
        u1.fullName  AS userFullName,
        u2.fullName  AS requestedByName,
        u3.fullName  AS resolvedByName
    FROM PasswordResetRequests pr
    INNER JOIN Users u1 ON pr.userId      = u1.userId
    INNER JOIN Users u2 ON pr.requestedBy = u2.userId
    LEFT  JOIN Users u3 ON pr.resolvedBy  = u3.userId
    ORDER BY pr.requestDate DESC;
END;
GO


-- -----------------------------------------------------------------------------
-- 6. usp_UpdatePasswordResetRequestStatus
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_UpdatePasswordResetRequestStatus', 'P') IS NOT NULL DROP PROCEDURE usp_UpdatePasswordResetRequestStatus;
GO
CREATE PROCEDURE usp_UpdatePasswordResetRequestStatus
    @RequestId    VARCHAR(50),
    @Status       VARCHAR(50),
    @ResolvedBy   VARCHAR(50),
    @ResolvedDate DATETIME,
    @Notes        NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PasswordResetRequests
    SET status       = @Status,
        resolvedBy   = @ResolvedBy,
        resolvedDate = @ResolvedDate,
        notes        = @Notes
    WHERE requestId = @RequestId;
END;
GO


-- -----------------------------------------------------------------------------
-- 7. usp_DeletePasswordResetRequest
-- -----------------------------------------------------------------------------
IF OBJECT_ID('usp_DeletePasswordResetRequest', 'P') IS NOT NULL DROP PROCEDURE usp_DeletePasswordResetRequest;
GO
CREATE PROCEDURE usp_DeletePasswordResetRequest
    @RequestId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM PasswordResetRequests WHERE requestId = @RequestId;
END;
GO
