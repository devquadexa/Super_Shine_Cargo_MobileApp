-- =============================================================================
-- Stored Procedures: JobAssignments
-- Repository: MSSQLJobAssignmentRepository
-- =============================================================================

IF OBJECT_ID('usp_CreateJobAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_CreateJobAssignment;
GO
CREATE PROCEDURE usp_CreateJobAssignment
    @JobId      VARCHAR(50),
    @UserId     VARCHAR(50),
    @AssignedBy VARCHAR(50),
    @Notes      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO JobAssignments (jobId, userId, assignedBy, notes)
    OUTPUT INSERTED.assignmentId
    VALUES (@JobId, @UserId, @AssignedBy, @Notes);
END;
GO

IF OBJECT_ID('usp_GetJobAssignmentById', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAssignmentById;
GO
CREATE PROCEDURE usp_GetJobAssignmentById
    @AssignmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ja.*, u.fullName AS userName, u.email AS userEmail, u.role AS userRole,
           ab.fullName AS assignedByName
    FROM JobAssignments ja
    INNER JOIN Users u  ON ja.userId     = u.userId
    LEFT  JOIN Users ab ON ja.assignedBy = ab.userId
    WHERE ja.assignmentId = @AssignmentId;
END;
GO

IF OBJECT_ID('usp_GetJobAssignmentsByJob', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAssignmentsByJob;
GO
CREATE PROCEDURE usp_GetJobAssignmentsByJob
    @JobId      VARCHAR(50),
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ja.*, u.fullName AS userName, u.email AS userEmail, u.role AS userRole,
           ab.fullName AS assignedByName
    FROM JobAssignments ja
    INNER JOIN Users u  ON ja.userId     = u.userId
    LEFT  JOIN Users ab ON ja.assignedBy = ab.userId
    WHERE ja.jobId = @JobId
      AND (@ActiveOnly = 0 OR ja.isActive = 1)
    ORDER BY ja.assignedDate DESC;
END;
GO

IF OBJECT_ID('usp_GetJobAssignmentsByUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAssignmentsByUser;
GO
CREATE PROCEDURE usp_GetJobAssignmentsByUser
    @UserId     VARCHAR(50),
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ja.*, u.fullName AS userName, u.email AS userEmail, u.role AS userRole,
           ab.fullName AS assignedByName
    FROM JobAssignments ja
    INNER JOIN Users u  ON ja.userId     = u.userId
    LEFT  JOIN Users ab ON ja.assignedBy = ab.userId
    WHERE ja.userId = @UserId
      AND (@ActiveOnly = 0 OR ja.isActive = 1)
    ORDER BY ja.assignedDate DESC;
END;
GO

IF OBJECT_ID('usp_DeactivateJobAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_DeactivateJobAssignments;
GO
CREATE PROCEDURE usp_DeactivateJobAssignments
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE JobAssignments SET isActive = 0 WHERE jobId = @JobId;
END;
GO

IF OBJECT_ID('usp_GetLatestJobAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_GetLatestJobAssignment;
GO
CREATE PROCEDURE usp_GetLatestJobAssignment
    @JobId  VARCHAR(50),
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 assignmentId FROM JobAssignments
    WHERE jobId = @JobId AND userId = @UserId
    ORDER BY assignedDate DESC;
END;
GO

IF OBJECT_ID('usp_ReactivateJobAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_ReactivateJobAssignment;
GO
CREATE PROCEDURE usp_ReactivateJobAssignment
    @AssignmentId INT,
    @AssignedBy   VARCHAR(50),
    @Notes        NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE JobAssignments
    SET isActive     = 1,
        assignedDate = GETDATE(),
        assignedBy   = @AssignedBy,
        notes        = @Notes
    WHERE assignmentId = @AssignmentId;
END;
GO

IF OBJECT_ID('usp_InsertJobAssignment', 'P') IS NOT NULL DROP PROCEDURE usp_InsertJobAssignment;
GO
CREATE PROCEDURE usp_InsertJobAssignment
    @JobId      VARCHAR(50),
    @UserId     VARCHAR(50),
    @AssignedBy VARCHAR(50),
    @Notes      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO JobAssignments (jobId, userId, assignedBy, notes, isActive)
    VALUES (@JobId, @UserId, @AssignedBy, @Notes, 1);
END;
GO

IF OBJECT_ID('usp_UpdateJobAssignedTo', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJobAssignedTo;
GO
CREATE PROCEDURE usp_UpdateJobAssignedTo
    @JobId      VARCHAR(50),
    @AssignedTo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Jobs SET assignedTo = @AssignedTo WHERE jobId = @JobId;
END;
GO

IF OBJECT_ID('usp_RemoveUserFromJob', 'P') IS NOT NULL DROP PROCEDURE usp_RemoveUserFromJob;
GO
CREATE PROCEDURE usp_RemoveUserFromJob
    @JobId  VARCHAR(50),
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count INT = 0;
    SELECT @Count = COUNT(*) FROM JobAssignments
    WHERE jobId = @JobId AND userId = @UserId AND isActive = 1;
    UPDATE JobAssignments SET isActive = 0
    WHERE jobId = @JobId AND userId = @UserId;
    SELECT @Count AS RemovedCount;
END;
GO

IF OBJECT_ID('usp_DeleteAllJobAssignments', 'P') IS NOT NULL DROP PROCEDURE usp_DeleteAllJobAssignments;
GO
CREATE PROCEDURE usp_DeleteAllJobAssignments
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM JobAssignments WHERE jobId = @JobId;
END;
GO

IF OBJECT_ID('usp_GetJobAssignmentSummary', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobAssignmentSummary;
GO
CREATE PROCEDURE usp_GetJobAssignmentSummary
    @JobId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT jobId, assignedUserCount, assignedUserNames, assignedUserIds, lastAssignedDate
    FROM vw_JobAssignmentSummary
    WHERE jobId = @JobId;
END;
GO

IF OBJECT_ID('usp_IsUserAssignedToJob', 'P') IS NOT NULL DROP PROCEDURE usp_IsUserAssignedToJob;
GO
CREATE PROCEDURE usp_IsUserAssignedToJob
    @JobId  VARCHAR(50),
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS count FROM JobAssignments
    WHERE jobId = @JobId AND userId = @UserId AND isActive = 1;
END;
GO

IF OBJECT_ID('usp_GetJobsForUser', 'P') IS NOT NULL DROP PROCEDURE usp_GetJobsForUser;
GO
CREATE PROCEDURE usp_GetJobsForUser
    @UserId     VARCHAR(50),
    @Status     VARCHAR(50) = NULL,
    @CustomerId VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT j.jobId, j.customerId, c.name AS customerName,
           j.shipmentCategory, j.status, j.openDate, j.createdDate,
           ja.assignedDate, ja.notes AS assignmentNotes, ja.assignmentId
    FROM JobAssignments ja
    INNER JOIN Jobs      j ON ja.jobId      = j.jobId
    INNER JOIN Customers c ON j.customerId  = c.customerId
    WHERE ja.userId   = @UserId
      AND ja.isActive = 1
      AND (@Status     IS NULL OR j.status     = @Status)
      AND (@CustomerId IS NULL OR j.customerId = @CustomerId)
    ORDER BY ja.assignedDate DESC;
END;
GO

IF OBJECT_ID('usp_UpdateJobAssignmentNotes', 'P') IS NOT NULL DROP PROCEDURE usp_UpdateJobAssignmentNotes;
GO
CREATE PROCEDURE usp_UpdateJobAssignmentNotes
    @AssignmentId INT,
    @Notes        NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE JobAssignments SET notes = @Notes WHERE assignmentId = @AssignmentId;
END;
GO
