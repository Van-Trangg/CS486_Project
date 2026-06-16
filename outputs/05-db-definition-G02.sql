-- ============================================================
-- Database: Campus Space Management System
-- Platform: Microsoft SQL Server
-- Group: G02
-- Step 5: Database Implementation (DDL)
-- Based on Step 3 logical design with mandatory fixes from Step 4
-- ============================================================

-- Cleanup Section (Reverse Dependency Order)
DROP TRIGGER IF EXISTS TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE;
DROP TRIGGER IF EXISTS TR_BOOKING_STATUS_AND_AUDIT;
GO

IF OBJECT_ID('dbo.fn_CheckSpaceCapacity', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CheckSpaceCapacity;
GO

DROP TABLE IF EXISTS [MAINTENANCERECORD];
DROP TABLE IF EXISTS [USAGESESSION];
DROP TABLE IF EXISTS [BOOKING];
DROP TABLE IF EXISTS [SPACE_FACILITY];
DROP TABLE IF EXISTS [FACILITY];
DROP TABLE IF EXISTS [SPACE];
DROP TABLE IF EXISTS [USER];
GO

-- Table Creation
CREATE TABLE [USER] (
    [user_id] VARCHAR(50) NOT NULL,
    [email] VARCHAR(150) NOT NULL,
    [full_name] VARCHAR(150) NOT NULL,
    [phone_number] VARCHAR(20) NULL,
    [role] VARCHAR(50) NOT NULL,
    [department] VARCHAR(100) NOT NULL,
    [account_status] VARCHAR(20) NOT NULL,

    CONSTRAINT PK_USER PRIMARY KEY ([user_id])
);
GO

CREATE TABLE [SPACE] (
    [space_code] VARCHAR(50) NOT NULL,
    [space_name] VARCHAR(100) NOT NULL,
    [space_type] VARCHAR(50) NOT NULL,
    [building] VARCHAR(50) NOT NULL,
    [floor] VARCHAR(10) NOT NULL,
    [room_number] VARCHAR(20) NOT NULL,
    [capacity] INT NOT NULL,
    [current_status] VARCHAR(20) NOT NULL,
    [usage_policy] NVARCHAR(MAX) NOT NULL,

    CONSTRAINT PK_SPACE PRIMARY KEY ([space_code])
);
GO

CREATE TABLE [FACILITY] (
    [facility_id] INT IDENTITY(1,1) NOT NULL,
    [facility_name] VARCHAR(100) NOT NULL,
    [facility_description] NVARCHAR(MAX) NULL,

    CONSTRAINT PK_FACILITY PRIMARY KEY ([facility_id])
);
GO

CREATE TABLE [SPACE_FACILITY] (
    [space_code] VARCHAR(50) NOT NULL,
    [facility_id] INT NOT NULL,
    [quantity] INT NOT NULL,
    [operation_status] VARCHAR(30) NOT NULL,
    [description] NVARCHAR(500) NULL,

    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY ([space_code], [facility_id])
);
GO

CREATE TABLE [BOOKING] (
    [booking_id] INT IDENTITY(1,1) NOT NULL,
    [space_code] VARCHAR(50) NOT NULL,
    [requester_id] VARCHAR(50) NOT NULL,
    [requested_start] DATETIME NOT NULL,
    [requested_end] DATETIME NOT NULL,
    [purpose] VARCHAR(100) NOT NULL,
    [expected_participants] INT NOT NULL,
    [booking_status] VARCHAR(30) NOT NULL,
    [created_at] DATETIME NOT NULL,
    [approver_id] VARCHAR(50) NULL,
    [decision_time] DATETIME NULL,
    [decision_note] NVARCHAR(MAX) NULL,
    [rejection_reason] VARCHAR(255) NULL,

    CONSTRAINT PK_BOOKING PRIMARY KEY ([booking_id])
);
GO

CREATE TABLE [USAGESESSION] (
    [booking_id] INT NOT NULL,
    [check_in_staff_id] VARCHAR(50) NOT NULL,
    [actual_start] DATETIME NOT NULL,
    [initial_condition] NVARCHAR(MAX) NOT NULL,
    [check_out_staff_id] VARCHAR(50) NULL,
    [actual_end] DATETIME NULL,
    [final_condition] NVARCHAR(MAX) NULL,
    [usage_notes] NVARCHAR(MAX) NULL,

    CONSTRAINT PK_USAGESESSION PRIMARY KEY ([booking_id])
);
GO

CREATE TABLE [MAINTENANCERECORD] (
    [maintenance_id] INT IDENTITY(1,1) NOT NULL,
    [space_code] VARCHAR(50) NOT NULL,
    [reporter_id] VARCHAR(50) NOT NULL,
    [assigned_staff_id] VARCHAR(50) NULL,
    [problem_type] VARCHAR(50) NOT NULL,
    [problem_description] NVARCHAR(MAX) NOT NULL,
    [start_time] DATETIME NOT NULL,
    [completion_time] DATETIME NULL,
    [maintenance_status] VARCHAR(20) NOT NULL,
    [result_note] NVARCHAR(MAX) NULL,

    CONSTRAINT PK_MAINTENANCERECORD PRIMARY KEY ([maintenance_id])
);
GO

-- UDF Definitions
GO
CREATE FUNCTION dbo.fn_CheckSpaceCapacity (@SpaceCode VARCHAR(50), @Participants INT)
RETURNS BIT
AS
BEGIN
    DECLARE @Capacity INT;
    DECLARE @Result BIT = 1;
    
    SELECT @Capacity = capacity FROM [SPACE] WHERE space_code = @SpaceCode;
    
    IF @Participants > @Capacity
        SET @Result = 0;
        
    RETURN @Result;
END;
GO

-- Constraint Definitions
ALTER TABLE [USER] ADD CONSTRAINT UQ_USER_EMAIL UNIQUE ([email]);

ALTER TABLE [USER] ADD CONSTRAINT CK_USER_ROLE CHECK (
    [role] IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')
);

ALTER TABLE [USER] ADD CONSTRAINT CK_USER_ACCOUNT_STATUS CHECK (
    [account_status] IN ('Active', 'Suspended', 'Inactive')
);

ALTER TABLE [SPACE] ADD CONSTRAINT CK_SPACE_TYPE CHECK (
    [space_type] IN ('Auditorium', 'Classroom', 'Computer Laboratory', 'Project Laboratory', 'Meeting Room', 'Student Workspace')
);

ALTER TABLE [SPACE] ADD CONSTRAINT CK_SPACE_CAPACITY CHECK ([capacity] > 0);

ALTER TABLE [SPACE] ADD CONSTRAINT CK_SPACE_CURRENT_STATUS CHECK (
    [current_status] IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')
);

ALTER TABLE [FACILITY] ADD CONSTRAINT UQ_FACILITY_NAME UNIQUE ([facility_name]);

ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT DF_SPACE_FACILITY_QUANTITY DEFAULT 1 FOR [quantity];
ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT CK_SPACE_FACILITY_QUANTITY CHECK ([quantity] > 0);
ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT DF_SPACE_FACILITY_STATUS DEFAULT 'Operational' FOR [operation_status];
ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT CK_SPACE_FACILITY_STATUS CHECK (
    [operation_status] IN ('Operational', 'Partially Operational', 'Broken')
);

ALTER TABLE [BOOKING] ADD CONSTRAINT DF_BOOKING_CREATED_AT DEFAULT GETDATE() FOR [created_at];
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_TIME_ORDER CHECK ([requested_end] > [requested_start]);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_PARTICIPANTS CHECK ([expected_participants] > 0);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_PURPOSE CHECK (
    [purpose] IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_STATUS CHECK (
    [booking_status] IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-Show')
);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_FUTURE_START CHECK ([requested_start] >= [created_at]);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_REJECTION_REASON CHECK ([booking_status] <> 'Rejected' OR [rejection_reason] IS NOT NULL);
ALTER TABLE [BOOKING] ADD CONSTRAINT CK_BOOKING_CAPACITY_LIMIT CHECK (dbo.fn_CheckSpaceCapacity([space_code], [expected_participants]) = 1);

ALTER TABLE [USAGESESSION] ADD CONSTRAINT CK_USAGE_TIME_ORDER CHECK ([actual_end] > [actual_start]);

ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT CK_MAINTENANCE_TIME_ORDER CHECK ([completion_time] > [start_time]);
ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT CK_MAINTENANCE_STATUS CHECK (
    [maintenance_status] IN ('Reported', 'In Progress', 'Resolved', 'Cancelled')
);
ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT CK_MAINTENANCE_PROBLEM_TYPE CHECK (
    [problem_type] IN ('Projector Failure', 'Air-Conditioning Issue', 'Cleaning Issue', 'Furniture Damage', 'Network Issue', 'Other')
);
GO

-- Referential Integrity Definitions
ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT FK_SPACE_FACILITY_SPACE
    FOREIGN KEY ([space_code]) REFERENCES [SPACE] ([space_code])
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE [SPACE_FACILITY] ADD CONSTRAINT FK_SPACE_FACILITY_FACILITY
    FOREIGN KEY ([facility_id]) REFERENCES [FACILITY] ([facility_id])
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE [BOOKING] ADD CONSTRAINT FK_BOOKING_SPACE
    FOREIGN KEY ([space_code]) REFERENCES [SPACE] ([space_code])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [BOOKING] ADD CONSTRAINT FK_BOOKING_USER
    FOREIGN KEY ([requester_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [BOOKING] ADD CONSTRAINT FK_BOOKING_USER_APPROVER
    FOREIGN KEY ([approver_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

-- Step 4 High-Risk Fix (BR-18)
-- Historical records must be preserved.
-- Changed ON DELETE CASCADE to ON DELETE NO ACTION.
ALTER TABLE [USAGESESSION] ADD CONSTRAINT FK_USAGESESSION_BOOKING
    FOREIGN KEY ([booking_id]) REFERENCES [BOOKING] ([booking_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [USAGESESSION] ADD CONSTRAINT FK_USAGESESSION_USER_CHECKIN
    FOREIGN KEY ([check_in_staff_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [USAGESESSION] ADD CONSTRAINT FK_USAGESESSION_USER_CHECKOUT
    FOREIGN KEY ([check_out_staff_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT FK_MAINTENANCERECORD_SPACE
    FOREIGN KEY ([space_code]) REFERENCES [SPACE] ([space_code])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT FK_MAINTENANCERECORD_USER_REPORTER
    FOREIGN KEY ([reporter_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE [MAINTENANCERECORD] ADD CONSTRAINT FK_MAINTENANCERECORD_USER_STAFF
    FOREIGN KEY ([assigned_staff_id]) REFERENCES [USER] ([user_id])
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- Trigger Definitions
CREATE TRIGGER TR_BOOKING_PREVENT_OVERLAPS_AND_UNAVAILABLE
ON [BOOKING]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN [SPACE] s ON i.space_code = s.space_code
        WHERE i.booking_status = 'Approved'
          AND (
              s.current_status IN ('Retired', 'Temporarily Closed')
              OR EXISTS (
                  SELECT 1 FROM [BOOKING] b
                  WHERE b.space_code = i.space_code AND b.booking_id <> i.booking_id
                    AND b.booking_status = 'Approved'
                    AND i.requested_start < b.requested_end AND i.requested_end > b.requested_start
              )
              OR EXISTS (
                  SELECT 1 FROM [MAINTENANCERECORD] m
                  WHERE m.space_code = i.space_code
                    AND m.maintenance_status IN ('Reported', 'In Progress')
                    AND (i.requested_start < m.completion_time OR m.completion_time IS NULL)
                    AND i.requested_end > m.start_time
              )
          )
    )
    BEGIN
        RAISERROR ('Double booking, scheduling during maintenance, or booking retired/closed spaces is forbidden.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- ============================================================
-- Trigger: Enforce Booking Cancellation and Audit Rules (BR-21)
-- ============================================================
CREATE TRIGGER TR_BOOKING_STATUS_AND_AUDIT
ON [BOOKING]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Enforce Cancellation Rule: Can only cancel if status was 'Pending' or 'Approved'
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.booking_status = 'Cancelled'
          AND d.booking_status NOT IN ('Pending', 'Approved')
    )
    BEGIN
        RAISERROR ('A booking may be cancelled only if the booking status is Pending or Approved.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Enforce Cancellation Audit Rule: Cancelled bookings cannot be deleted
    IF EXISTS (
        SELECT 1
        FROM deleted
        WHERE booking_status = 'Cancelled'
          AND NOT EXISTS (SELECT 1 FROM inserted)
    )
    BEGIN
        RAISERROR ('Cancelled bookings must remain stored in the system to preserve historical records and auditability.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO
