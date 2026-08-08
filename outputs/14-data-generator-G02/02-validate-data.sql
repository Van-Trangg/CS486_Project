/* Step 14 independent validation, Group G02. Select the database with -d. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- IF LOWER(DB_NAME()) = 'university'
--     THROW 51400, 'Refusing to validate the protected University database in the Step 14 workflow.', 1;

IF OBJECT_ID('dbo.BOOKING', 'U') IS NULL
    THROW 51401, 'The migrated Step 14 schema is not present in the selected database.', 1;

CREATE TABLE #Checks
(
    check_name VARCHAR(120) NOT NULL,
    actual_value BIGINT NOT NULL,
    expected_condition VARCHAR(120) NOT NULL,
    result VARCHAR(4) NOT NULL
);

DECLARE @BookingCount BIGINT = (SELECT COUNT_BIG(*) FROM dbo.BOOKING);
DECLARE @AcademicYears BIGINT;
DECLARE @MinimumBookingDate DATE = (SELECT MIN(CONVERT(DATE, requested_start)) FROM dbo.BOOKING);
DECLARE @MaximumBookingDate DATE = (SELECT MAX(CONVERT(DATE, requested_start)) FROM dbo.BOOKING);
WITH AcademicYears AS
(
    SELECT DISTINCT CASE WHEN MONTH(requested_start) >= 9 THEN YEAR(requested_start) ELSE YEAR(requested_start) - 1 END AS academic_year_start
    FROM dbo.BOOKING
)
SELECT @AcademicYears = COUNT_BIG(*) FROM AcademicYears;

INSERT #Checks VALUES
('Booking row minimum', @BookingCount, '>= 100000', IIF(@BookingCount >= 100000, 'PASS', 'FAIL')),
('Distinct academic years', @AcademicYears, '>= 3', IIF(@AcademicYears >= 3, 'PASS', 'FAIL')),
('Minimum booking date coverage', ISNULL(CONVERT(BIGINT, CONVERT(CHAR(8), @MinimumBookingDate, 112)), 0), '<= 20230901', IIF(@MinimumBookingDate <= '2023-09-01', 'PASS', 'FAIL')),
('Maximum booking date coverage', ISNULL(CONVERT(BIGINT, CONVERT(CHAR(8), @MaximumBookingDate, 112)), 0), '>= 20260531', IIF(@MaximumBookingDate >= '2026-05-31', 'PASS', 'FAIL')),
('User row minimum', (SELECT COUNT_BIG(*) FROM dbo.[USER]), '>= 400', IIF((SELECT COUNT_BIG(*) FROM dbo.[USER]) >= 400, 'PASS', 'FAIL')),
('Space row minimum', (SELECT COUNT_BIG(*) FROM dbo.SPACE), '>= 50', IIF((SELECT COUNT_BIG(*) FROM dbo.SPACE) >= 50, 'PASS', 'FAIL')),
('Facility row minimum', (SELECT COUNT_BIG(*) FROM dbo.FACILITY), '>= 10', IIF((SELECT COUNT_BIG(*) FROM dbo.FACILITY) >= 10, 'PASS', 'FAIL')),
('Space-facility row minimum', (SELECT COUNT_BIG(*) FROM dbo.SPACE_FACILITY), '>= 200', IIF((SELECT COUNT_BIG(*) FROM dbo.SPACE_FACILITY) >= 200, 'PASS', 'FAIL')),
('Maintenance row minimum', (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCERECORD), '>= 3000', IIF((SELECT COUNT_BIG(*) FROM dbo.MAINTENANCERECORD) >= 3000, 'PASS', 'FAIL')),
('Usage-session row minimum', (SELECT COUNT_BIG(*) FROM dbo.USAGESESSION), '>= 50000', IIF((SELECT COUNT_BIG(*) FROM dbo.USAGESESSION) >= 50000, 'PASS', 'FAIL')),
('Advisory acknowledgement minimum', (SELECT COUNT_BIG(*) FROM dbo.BOOKING_ADVISORY_ACK), '>= 5000', IIF((SELECT COUNT_BIG(*) FROM dbo.BOOKING_ADVISORY_ACK) >= 5000, 'PASS', 'FAIL')),
('Impact-history row minimum', (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY), '>= 500', IIF((SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY) >= 500, 'PASS', 'FAIL'));

DECLARE @StatusCoverage BIGINT = (SELECT COUNT_BIG(DISTINCT booking_status) FROM dbo.BOOKING);
DECLARE @PurposeCoverage BIGINT = (SELECT COUNT_BIG(DISTINCT purpose) FROM dbo.BOOKING);
DECLARE @PathCoverage BIGINT = (SELECT COUNT_BIG(DISTINCT resolution_path) FROM dbo.BOOKING);
DECLARE @ImpactCoverage BIGINT = (SELECT COUNT_BIG(DISTINCT impact_level) FROM dbo.MAINTENANCERECORD);
INSERT #Checks VALUES
('Booking status domain coverage', @StatusCoverage, '= 7', IIF(@StatusCoverage = 7, 'PASS', 'FAIL')),
('Booking purpose domain coverage', @PurposeCoverage, '= 7', IIF(@PurposeCoverage = 7, 'PASS', 'FAIL')),
('Resolution path domain coverage', @PathCoverage, '= 2', IIF(@PathCoverage = 2, 'PASS', 'FAIL')),
('Maintenance impact coverage', @ImpactCoverage, '= 2', IIF(@ImpactCoverage = 2, 'PASS', 'FAIL')),
('User role domain coverage', (SELECT COUNT_BIG(DISTINCT role) FROM dbo.[USER]), '= 6', IIF((SELECT COUNT_BIG(DISTINCT role) FROM dbo.[USER]) = 6, 'PASS', 'FAIL')),
('User account-status coverage', (SELECT COUNT_BIG(DISTINCT account_status) FROM dbo.[USER]), '= 3', IIF((SELECT COUNT_BIG(DISTINCT account_status) FROM dbo.[USER]) = 3, 'PASS', 'FAIL')),
('Space type domain coverage', (SELECT COUNT_BIG(DISTINCT space_type) FROM dbo.SPACE), '= 6', IIF((SELECT COUNT_BIG(DISTINCT space_type) FROM dbo.SPACE) = 6, 'PASS', 'FAIL')),
('Space status domain coverage', (SELECT COUNT_BIG(DISTINCT current_status) FROM dbo.SPACE), '= 5', IIF((SELECT COUNT_BIG(DISTINCT current_status) FROM dbo.SPACE) = 5, 'PASS', 'FAIL')),
('Facility operation-status coverage', (SELECT COUNT_BIG(DISTINCT operation_status) FROM dbo.SPACE_FACILITY), '= 3', IIF((SELECT COUNT_BIG(DISTINCT operation_status) FROM dbo.SPACE_FACILITY) = 3, 'PASS', 'FAIL')),
('Maintenance status coverage', (SELECT COUNT_BIG(DISTINCT maintenance_status) FROM dbo.MAINTENANCERECORD), '= 4', IIF((SELECT COUNT_BIG(DISTINCT maintenance_status) FROM dbo.MAINTENANCERECORD) = 4, 'PASS', 'FAIL')),
('Maintenance problem-type coverage', (SELECT COUNT_BIG(DISTINCT problem_type) FROM dbo.MAINTENANCERECORD), '= 6', IIF((SELECT COUNT_BIG(DISTINCT problem_type) FROM dbo.MAINTENANCERECORD) = 6, 'PASS', 'FAIL'));

DECLARE @InvalidBookingTime BIGINT = (SELECT COUNT_BIG(*) FROM dbo.BOOKING WHERE requested_end <= requested_start OR created_at > requested_start);
DECLARE @InvalidCapacity BIGINT = (SELECT COUNT_BIG(*) FROM dbo.BOOKING b JOIN dbo.SPACE s ON s.space_code=b.space_code WHERE b.expected_participants <= 0 OR b.expected_participants > s.capacity);
DECLARE @InvalidDecision BIGINT = (SELECT COUNT_BIG(*) FROM dbo.BOOKING WHERE decision_time < created_at OR decision_time > requested_start);
DECLARE @InvalidStatusFields BIGINT =
(
    SELECT COUNT_BIG(*) FROM dbo.BOOKING
    WHERE (booking_status='Rejected' AND rejection_reason IS NULL)
       OR (booking_status<>'Rejected' AND rejection_reason IS NOT NULL)
       OR (booking_status='Pending' AND (approver_id IS NOT NULL OR decision_time IS NOT NULL OR decision_note IS NOT NULL OR rejection_reason IS NOT NULL))
       OR (resolution_path='Instant' AND (booking_status IN ('Pending','Rejected') OR approver_id IS NOT NULL OR decision_note IS NOT NULL OR decision_time IS NULL))
       OR (resolution_path='Staff' AND booking_status IN ('Approved','Checked In','Completed','No-Show','Rejected')
           AND (approver_id IS NULL OR decision_time IS NULL OR decision_note IS NULL))
       OR (resolution_path='Staff' AND booking_status='Cancelled'
           AND ((approver_id IS NULL AND (decision_time IS NOT NULL OR decision_note IS NOT NULL))
             OR (approver_id IS NOT NULL AND (decision_time IS NULL OR decision_note IS NULL))))
       OR (booking_status IN ('Approved','Checked In','Completed','No-Show','Rejected') AND decision_time IS NULL)
);
DECLARE @InvalidInstantEligibility BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING b
    JOIN dbo.SPACE s ON s.space_code=b.space_code
    JOIN dbo.[USER] u ON u.user_id=b.requester_id
    WHERE b.resolution_path='Instant'
      AND (s.space_type<>'Classroom' OR u.role NOT IN ('Lecturer','Teaching Assistant') OR u.account_status<>'Active')
);
DECLARE @InvalidInstantDecisionTime BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING
    WHERE resolution_path = 'Instant'
      AND
      (
          decision_time IS NULL
          OR decision_time <> created_at
      )
);

DECLARE @InvalidStaffRoles BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM
    (
        SELECT b.approver_id AS user_id
        FROM dbo.BOOKING b
        WHERE b.approver_id IS NOT NULL
        UNION ALL
        SELECT us.check_in_staff_id FROM dbo.USAGESESSION us
        UNION ALL
        SELECT us.check_out_staff_id FROM dbo.USAGESESSION us WHERE us.check_out_staff_id IS NOT NULL
        UNION ALL
        SELECT m.assigned_staff_id FROM dbo.MAINTENANCERECORD m WHERE m.assigned_staff_id IS NOT NULL
        UNION ALL
        SELECT h.changed_by_user_id FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    ) refs
    LEFT JOIN dbo.[USER] u ON u.user_id=refs.user_id
    WHERE u.user_id IS NULL OR u.role NOT IN ('Facility Staff','Facility Manager') OR u.account_status<>'Active'
);
INSERT #Checks VALUES
('Invalid booking time order', @InvalidBookingTime, '= 0',
 IIF(@InvalidBookingTime = 0, 'PASS', 'FAIL')),

('Invalid booking capacity', @InvalidCapacity, '= 0',
 IIF(@InvalidCapacity = 0, 'PASS', 'FAIL')),

('Invalid decision chronology', @InvalidDecision, '= 0',
 IIF(@InvalidDecision = 0, 'PASS', 'FAIL')),

('Invalid status/path field combinations', @InvalidStatusFields, '= 0',
 IIF(@InvalidStatusFields = 0, 'PASS', 'FAIL')),

('Invalid Instant eligibility rows', @InvalidInstantEligibility, '= 0',
 IIF(@InvalidInstantEligibility = 0, 'PASS', 'FAIL')),

('Invalid Instant decision time', @InvalidInstantDecisionTime, '= 0',
 IIF(@InvalidInstantDecisionTime = 0, 'PASS', 'FAIL')),

('Invalid staff-role references', @InvalidStaffRoles, '= 0',
 IIF(@InvalidStaffRoles = 0, 'PASS', 'FAIL'));

DECLARE @ApprovedConflicts BIGINT;

SELECT @ApprovedConflicts = COUNT_BIG(*)
FROM dbo.BOOKING b1
JOIN dbo.BOOKING b2
    ON b2.space_code = b1.space_code
   AND b2.booking_id > b1.booking_id
WHERE b1.booking_status IN ('Approved', 'Checked In')
  AND b2.booking_status IN ('Approved', 'Checked In')
  AND b1.requested_start < b2.requested_end
  AND b1.requested_end > b2.requested_start
OPTION (MAXDOP 1);
SELECT @ApprovedConflicts AS ApprovedConflicts;
INSERT #Checks VALUES ('Approved-lifecycle overlap pairs', @ApprovedConflicts, '= 0', IIF(@ApprovedConflicts=0, 'PASS', 'FAIL'));

DECLARE @MissingUsage BIGINT =
(
    SELECT COUNT_BIG(*) FROM dbo.BOOKING b
    LEFT JOIN dbo.USAGESESSION u ON u.booking_id=b.booking_id
    WHERE b.booking_status IN ('Completed','Checked In') AND u.booking_id IS NULL
);
DECLARE @ExtraUsage BIGINT =
(
    SELECT COUNT_BIG(*) FROM dbo.USAGESESSION u JOIN dbo.BOOKING b ON b.booking_id=u.booking_id
    WHERE b.booking_status NOT IN ('Completed','Checked In')
);
DECLARE @InvalidUsageTime BIGINT = (SELECT COUNT_BIG(*) FROM dbo.USAGESESSION WHERE actual_end IS NOT NULL AND actual_end <= actual_start);
INSERT #Checks VALUES
('Missing required usage sessions', @MissingUsage, '= 0', IIF(@MissingUsage=0, 'PASS', 'FAIL')),
('Usage sessions on unsupported statuses', @ExtraUsage, '= 0', IIF(@ExtraUsage=0, 'PASS', 'FAIL')),
('Invalid usage-session time order', @InvalidUsageTime, '= 0', IIF(@InvalidUsageTime=0, 'PASS', 'FAIL'));

/* ============================================================
   INVALID ADVISORY ACKNOWLEDGEMENT VALIDATION
   ============================================================ */

DECLARE @InvalidAck BIGINT = 0;

;WITH OrderedHistory AS
(
    SELECT
        h.maintenance_id,
        h.changed_at,
        h.old_impact_level,

        LAG(h.changed_at) OVER
        (
            PARTITION BY h.maintenance_id
            ORDER BY h.changed_at, h.history_id
        ) AS previous_changed_at,

        ROW_NUMBER() OVER
        (
            PARTITION BY h.maintenance_id
            ORDER BY h.changed_at DESC, h.history_id DESC
        ) AS reverse_sequence
    FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
),
ImpactPeriods AS
(
    /*
        Period before each change.

        Example:
        08:00 Advisory -> 10:00 Out-of-Service

        For the history row at 10:00:
        valid_from  = previous change time
        valid_to    = 10:00
        impact      = old_impact_level
    */
    SELECT
        oh.maintenance_id,
        oh.previous_changed_at AS valid_from,
        oh.changed_at AS valid_to,
        oh.old_impact_level AS impact_level
    FROM OrderedHistory AS oh

    UNION ALL

    /*
        Period after the latest history change.
        The current impact level is stored in MAINTENANCERECORD.
    */
    SELECT
        oh.maintenance_id,
        oh.changed_at AS valid_from,
        NULL AS valid_to,
        m.impact_level
    FROM OrderedHistory AS oh
    JOIN dbo.MAINTENANCERECORD AS m
        ON m.maintenance_id = oh.maintenance_id
    WHERE oh.reverse_sequence = 1
),
AcknowledgementState AS
(
    SELECT
        a.booking_id,
        a.maintenance_id,
        a.acknowledged_at,

        b.created_at,
        b.requested_start,
        b.requested_end,
        b.space_code AS booking_space_code,

        m.space_code AS maintenance_space_code,
        m.start_time,
        m.completion_time,

        /*
            When maintenance has no history rows, use its current impact level.
        */
        COALESCE(p.impact_level, m.impact_level) AS impact_at_ack
    FROM dbo.BOOKING_ADVISORY_ACK AS a
    JOIN dbo.BOOKING AS b
        ON b.booking_id = a.booking_id
    JOIN dbo.MAINTENANCERECORD AS m
        ON m.maintenance_id = a.maintenance_id
    LEFT JOIN ImpactPeriods AS p
        ON p.maintenance_id = a.maintenance_id
       AND
       (
           p.valid_from IS NULL
           OR a.acknowledged_at >= p.valid_from
       )
       AND
       (
           p.valid_to IS NULL
           OR a.acknowledged_at < p.valid_to
       )
)
SELECT
    @InvalidAck = COUNT_BIG(*)
FROM AcknowledgementState AS x
WHERE x.impact_at_ack <> 'advisory'

   OR x.maintenance_space_code <> x.booking_space_code

   OR x.start_time >= x.requested_end

   OR ISNULL
      (
          x.completion_time,
          CONVERT(DATETIME, '9999-12-31', 120)
      ) <= x.requested_start

   OR x.acknowledged_at <> x.created_at;

INSERT INTO #Checks
VALUES
(
    'Invalid advisory acknowledgement rows',
    @InvalidAck,
    '= 0',
    IIF(@InvalidAck = 0, 'PASS', 'FAIL')
);
DECLARE @MissingAck BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING b
    JOIN dbo.MAINTENANCERECORD m ON m.space_code=b.space_code
    LEFT JOIN dbo.BOOKING_ADVISORY_ACK a ON a.booking_id=b.booking_id AND a.maintenance_id=m.maintenance_id
    WHERE m.impact_level='advisory' AND m.maintenance_status IN ('Reported','In Progress')
      AND m.start_time<b.requested_end AND ISNULL(m.completion_time,CONVERT(DATETIME,'9999-12-31',120))>b.requested_start
      AND a.ack_id IS NULL
);
DECLARE @ImpactChangeAtSubmission BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING b
    JOIN dbo.MAINTENANCERECORD m
        ON m.space_code = b.space_code
    JOIN dbo.MAINTENANCE_IMPACT_HISTORY h
        ON h.maintenance_id = m.maintenance_id
    WHERE h.changed_at = b.created_at
      AND m.start_time < b.requested_end
      AND ISNULL(
            m.completion_time,
            CONVERT(DATETIME,'9999-12-31',120)
          ) > b.requested_start
);

INSERT INTO #Checks
VALUES
(
    'No maintenance impact change exactly at booking submission time',
    @ImpactChangeAtSubmission,
    0,
    CASE
        WHEN @ImpactChangeAtSubmission = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
);
DECLARE @InvalidAckTimestamp BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING_ADVISORY_ACK AS a
    JOIN dbo.BOOKING AS b
        ON b.booking_id = a.booking_id
    WHERE a.acknowledged_at <> b.created_at
);
INSERT INTO #Checks
VALUES
(
    'Advisory acknowledgement timestamp matches booking submission',
    @InvalidAckTimestamp,
    0,
    CASE
        WHEN @InvalidAckTimestamp = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
);
DECLARE @DuplicateAck BIGINT =
(
    SELECT COUNT_BIG(*) FROM (SELECT booking_id,maintenance_id FROM dbo.BOOKING_ADVISORY_ACK GROUP BY booking_id,maintenance_id HAVING COUNT_BIG(*)>1) d
);
INSERT #Checks VALUES
('Missing required advisory acknowledgements', @MissingAck, '= 0', IIF(@MissingAck=0, 'PASS', 'FAIL')),
('Duplicate acknowledgement pairs', @DuplicateAck, '= 0', IIF(@DuplicateAck=0, 'PASS', 'FAIL')),
('Bookings acknowledging multiple advisories', (SELECT COUNT_BIG(*) FROM (SELECT booking_id FROM dbo.BOOKING_ADVISORY_ACK GROUP BY booking_id HAVING COUNT_BIG(*)>1) x), '> 0', IIF((SELECT COUNT_BIG(*) FROM (SELECT booking_id FROM dbo.BOOKING_ADVISORY_ACK GROUP BY booking_id HAVING COUNT_BIG(*)>1) x)>0, 'PASS', 'FAIL'));

DECLARE @InvalidMaintenanceTime BIGINT = (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCERECORD WHERE completion_time IS NOT NULL AND completion_time<=start_time);
DECLARE @InvalidHistory BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    JOIN dbo.MAINTENANCERECORD m ON m.maintenance_id=h.maintenance_id
    LEFT JOIN dbo.[USER] u ON u.user_id=h.changed_by_user_id
    WHERE h.old_impact_level=h.new_impact_level OR h.changed_at<m.start_time
       OR (m.completion_time IS NOT NULL AND h.changed_at>=m.completion_time)
       OR u.user_id IS NULL OR u.role NOT IN ('Facility Staff','Facility Manager')
);
DECLARE @BrokenHistoryChain BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM
    (
        SELECT h.maintenance_id, h.old_impact_level,
               LAG(h.new_impact_level) OVER (PARTITION BY h.maintenance_id ORDER BY h.changed_at,h.history_id) AS prior_new
        FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    ) x
    WHERE x.prior_new IS NOT NULL AND x.old_impact_level<>x.prior_new
);
DECLARE @HistoryCurrentMismatch BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.MAINTENANCERECORD m
    CROSS APPLY
    (
        SELECT TOP (1) h.new_impact_level
        FROM dbo.MAINTENANCE_IMPACT_HISTORY h
        WHERE h.maintenance_id=m.maintenance_id
        ORDER BY h.changed_at DESC,h.history_id DESC
    ) latest
    WHERE latest.new_impact_level<>m.impact_level
);
INSERT #Checks VALUES
('Invalid maintenance time order', @InvalidMaintenanceTime, '= 0', IIF(@InvalidMaintenanceTime=0, 'PASS', 'FAIL')),
('Invalid impact-history events', @InvalidHistory, '= 0', IIF(@InvalidHistory=0, 'PASS', 'FAIL')),
('Broken impact-history chains', @BrokenHistoryChain, '= 0', IIF(@BrokenHistoryChain=0, 'PASS', 'FAIL')),
('Impact history/current mismatches', @HistoryCurrentMismatch, '= 0', IIF(@HistoryCurrentMismatch=0, 'PASS', 'FAIL')),
('Escalation events', (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY WHERE old_impact_level='advisory' AND new_impact_level='out-of-service'), '> 0', IIF((SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY WHERE old_impact_level='advisory' AND new_impact_level='out-of-service')>0, 'PASS', 'FAIL')),
('Downgrade events', (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY WHERE old_impact_level='out-of-service' AND new_impact_level='advisory'), '> 0', IIF((SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_HISTORY WHERE old_impact_level='out-of-service' AND new_impact_level='advisory')>0, 'PASS', 'FAIL'));

DECLARE @CurrentOosOverlap BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.BOOKING b
    JOIN dbo.MAINTENANCERECORD m
      ON m.space_code = b.space_code
    WHERE b.booking_status IN ('Approved', 'Checked In')
      AND m.impact_level = 'out-of-service'
      AND m.maintenance_status IN ('Reported', 'In Progress')
      AND m.start_time < b.requested_end
      AND ISNULL(
            m.completion_time,
            CONVERT(DATETIME, '9999-12-31', 120)
          ) > b.requested_start
);

DROP TABLE IF EXISTS #ImpactHistory;

SELECT
    maintenance_id,
    changed_at,
    old_impact_level
INTO #ImpactHistory
FROM dbo.MAINTENANCE_IMPACT_HISTORY;

CREATE CLUSTERED INDEX IX_TempImpactHistory
ON #ImpactHistory
(
    maintenance_id,
    changed_at
);

DECLARE @InvalidApprovalDuringOos BIGINT;

SELECT @InvalidApprovalDuringOos = COUNT_BIG(*)
FROM dbo.BOOKING b
JOIN dbo.MAINTENANCERECORD m
    ON m.space_code = b.space_code
   AND m.start_time < b.requested_end
   AND ISNULL(
         m.completion_time,
         CONVERT(DATETIME, '9999-12-31', 120)
       ) > b.requested_start

OUTER APPLY
(
    SELECT TOP (1)
        h.old_impact_level AS impact_at_decision
    FROM #ImpactHistory h
    WHERE h.maintenance_id = m.maintenance_id
      AND h.changed_at > b.decision_time
    ORDER BY h.changed_at
) next_change

WHERE b.decision_time IS NOT NULL
  AND b.booking_status IN
      ('Approved', 'Checked In', 'Completed', 'No-Show')
  AND COALESCE(
        next_change.impact_at_decision,
        m.impact_level
      ) = 'out-of-service'
OPTION (MAXDOP 1);

SELECT @InvalidApprovalDuringOos;
DROP TABLE IF EXISTS #ImpactHistory;
DECLARE @OrphanMaintenanceHistory BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    LEFT JOIN dbo.MAINTENANCERECORD m
      ON m.maintenance_id = h.maintenance_id
    WHERE h.maintenance_id IS NULL
       OR m.maintenance_id IS NULL
);


DECLARE @InvalidImpactHistoryTransition BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    WHERE h.old_impact_level = h.new_impact_level
       OR h.old_impact_level NOT IN ('advisory', 'out-of-service')
       OR h.new_impact_level NOT IN ('advisory', 'out-of-service')
);


DECLARE @BrokenHistorySequence BIGINT;

WITH OrderedHistory AS
(
    SELECT
        maintenance_id,
        changed_at,
        old_impact_level,
        new_impact_level,
        LAG(new_impact_level) OVER
        (
            PARTITION BY maintenance_id
            ORDER BY changed_at
        ) AS previous_new_impact
    FROM dbo.MAINTENANCE_IMPACT_HISTORY
)
SELECT
    @BrokenHistorySequence = COUNT_BIG(*)
FROM OrderedHistory
WHERE previous_new_impact IS NOT NULL
  AND old_impact_level <> previous_new_impact;


DECLARE @LatestImpactMismatch BIGINT;

WITH LatestHistory AS
(
    SELECT
        h.maintenance_id,
        h.new_impact_level,
        ROW_NUMBER() OVER
        (
            PARTITION BY h.maintenance_id
            ORDER BY h.changed_at DESC
        ) AS rn
    FROM dbo.MAINTENANCE_IMPACT_HISTORY h
)
SELECT
    @LatestImpactMismatch = COUNT_BIG(*)
FROM LatestHistory h
JOIN dbo.MAINTENANCERECORD m
  ON m.maintenance_id = h.maintenance_id
WHERE h.rn = 1
  AND h.new_impact_level <> m.impact_level;
DECLARE @EscalationAffected BIGINT =
(
    SELECT COUNT_BIG(DISTINCT b.booking_id)
    FROM dbo.MAINTENANCE_IMPACT_HISTORY h
    JOIN dbo.MAINTENANCERECORD m ON m.maintenance_id=h.maintenance_id
    JOIN dbo.BOOKING b ON b.space_code=m.space_code
    WHERE h.old_impact_level='advisory' AND h.new_impact_level='out-of-service'
      AND b.booking_status IN ('Approved','Checked In','Completed','No-Show')
      AND b.decision_time<h.changed_at
      AND b.requested_start<ISNULL(m.completion_time,CONVERT(DATETIME,'9999-12-31',120))
      AND b.requested_end>m.start_time
);
INSERT #Checks VALUES
(
    'No booking approved while Out-of-Service was effective',
    @InvalidApprovalDuringOos,
    '= 0',
    IIF(@InvalidApprovalDuringOos = 0, 'PASS', 'FAIL')
);

INSERT #Checks VALUES
(
    'No orphan maintenance impact history rows',
    @OrphanMaintenanceHistory,
    '= 0',
    IIF(@OrphanMaintenanceHistory = 0, 'PASS', 'FAIL')
);

INSERT #Checks VALUES
(
    'Maintenance impact transitions are valid',
    @InvalidImpactHistoryTransition,
    '= 0',
    IIF(@InvalidImpactHistoryTransition = 0, 'PASS', 'FAIL')
);

INSERT #Checks VALUES
(
    'Maintenance impact history sequence is continuous',
    @BrokenHistorySequence,
    '= 0',
    IIF(@BrokenHistorySequence = 0, 'PASS', 'FAIL')
);

INSERT #Checks VALUES
(
    'Latest maintenance history matches current impact level',
    @LatestImpactMismatch,
    '= 0',
    IIF(@LatestImpactMismatch = 0, 'PASS', 'FAIL')
);

INSERT #Checks VALUES
('Escalation-affected bookings', @EscalationAffected, '> 0', IIF(@EscalationAffected>0, 'PASS', 'FAIL'));

DECLARE @Orphans BIGINT = 0;

/* BOOKING */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.BOOKING AS b
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SPACE AS s
    WHERE s.space_code = b.space_code
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.BOOKING AS b
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.[USER] AS u
    WHERE u.user_id = b.requester_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.BOOKING AS b
WHERE b.approver_id IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.[USER] AS u
      WHERE u.user_id = b.approver_id
  );

/* SPACE_FACILITY */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.SPACE_FACILITY AS sf
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SPACE AS s
    WHERE s.space_code = sf.space_code
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.SPACE_FACILITY AS sf
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.FACILITY AS f
    WHERE f.facility_id = sf.facility_id
);

/* MAINTENANCERECORD */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.MAINTENANCERECORD AS m
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SPACE AS s
    WHERE s.space_code = m.space_code
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.MAINTENANCERECORD AS m
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.[USER] AS u
    WHERE u.user_id = m.reporter_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.MAINTENANCERECORD AS m
WHERE m.assigned_staff_id IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.[USER] AS u
      WHERE u.user_id = m.assigned_staff_id
  );

/* USAGESESSION */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.USAGESESSION AS us
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.BOOKING AS b
    WHERE b.booking_id = us.booking_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.USAGESESSION AS us
WHERE us.check_in_staff_id IS NOT NULL
  AND NOT EXISTS
(
    SELECT 1
    FROM dbo.[USER] AS u
    WHERE u.user_id = us.check_in_staff_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.USAGESESSION AS us
WHERE us.check_out_staff_id IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.[USER] AS u
      WHERE u.user_id = us.check_out_staff_id
  );

/* BOOKING_ADVISORY_ACK */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.BOOKING_ADVISORY_ACK AS ack
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.BOOKING AS b
    WHERE b.booking_id = ack.booking_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.BOOKING_ADVISORY_ACK AS ack
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.MAINTENANCERECORD AS m
    WHERE m.maintenance_id = ack.maintenance_id
);

/* MAINTENANCE_IMPACT_HISTORY */
SELECT @Orphans += COUNT_BIG(*)
FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.MAINTENANCERECORD AS m
    WHERE m.maintenance_id = h.maintenance_id
);

SELECT @Orphans += COUNT_BIG(*)
FROM dbo.MAINTENANCE_IMPACT_HISTORY AS h
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.[USER] AS u
    WHERE u.user_id = h.changed_by_user_id
);

INSERT INTO #Checks
VALUES
(
    'Foreign-key orphan rows',
    @Orphans,
    '= 0',
    IIF(@Orphans = 0, 'PASS', 'FAIL')
);

DECLARE @FacilityCombinationCount BIGINT;
WITH FacilitySets AS
(
    SELECT space_code, STRING_AGG(CONVERT(VARCHAR(MAX),facility_id), ',') WITHIN GROUP (ORDER BY facility_id) AS facility_set
    FROM dbo.SPACE_FACILITY
    GROUP BY space_code
)
SELECT @FacilityCombinationCount=COUNT_BIG(*) FROM (SELECT facility_set FROM FacilitySets GROUP BY facility_set) x;

DECLARE @DisabledTriggers BIGINT =
(
    SELECT COUNT_BIG(*) FROM sys.triggers
    WHERE parent_id IN (OBJECT_ID('dbo.BOOKING'),OBJECT_ID('dbo.MAINTENANCERECORD'),OBJECT_ID('dbo.USAGESESSION'))
      AND is_disabled=1
);

INSERT #Checks VALUES
('Buildings represented', (SELECT COUNT_BIG(DISTINCT building) FROM dbo.SPACE), '>= 3', IIF((SELECT COUNT_BIG(DISTINCT building) FROM dbo.SPACE)>=3, 'PASS', 'FAIL')),
('Distinct capacities', (SELECT COUNT_BIG(DISTINCT capacity) FROM dbo.SPACE), '>= 10', IIF((SELECT COUNT_BIG(DISTINCT capacity) FROM dbo.SPACE)>=10, 'PASS', 'FAIL')),
('Distinct facility combinations', @FacilityCombinationCount, '>= 8', IIF(@FacilityCombinationCount>=8, 'PASS', 'FAIL')),
('Weekdays represented', (SELECT COUNT_BIG(DISTINCT DATEPART(WEEKDAY,requested_start)) FROM dbo.BOOKING), '= 7', IIF((SELECT COUNT_BIG(DISTINCT DATEPART(WEEKDAY,requested_start)) FROM dbo.BOOKING)=7, 'PASS', 'FAIL')),
('Start hours represented', (SELECT COUNT_BIG(DISTINCT DATEPART(HOUR,requested_start)) FROM dbo.BOOKING), '>= 7', IIF((SELECT COUNT_BIG(DISTINCT DATEPART(HOUR,requested_start)) FROM dbo.BOOKING)>=7, 'PASS', 'FAIL')),
('Disabled protected-table triggers', @DisabledTriggers, '= 0', IIF(@DisabledTriggers=0, 'PASS', 'FAIL'));

SELECT check_name, actual_value, expected_condition, result FROM #Checks ORDER BY check_name;
SELECT IIF(EXISTS(SELECT 1 FROM #Checks WHERE result='FAIL'), 'FAIL', 'PASS') AS overall_result,
       SUM(CASE WHEN result='PASS' THEN 1 ELSE 0 END) AS passed_checks,
       SUM(CASE WHEN result='FAIL' THEN 1 ELSE 0 END) AS failed_checks
FROM #Checks;

SELECT COUNT_BIG(*) AS booking_count, MIN(requested_start) AS minimum_booking_start, MAX(requested_end) AS maximum_booking_end FROM dbo.BOOKING;
SELECT booking_status, COUNT_BIG(*) AS booking_count FROM dbo.BOOKING GROUP BY booking_status ORDER BY booking_status;
SELECT resolution_path, COUNT_BIG(*) AS booking_count FROM dbo.BOOKING GROUP BY resolution_path ORDER BY resolution_path;
SELECT CASE WHEN MONTH(requested_start)>=9 THEN YEAR(requested_start) ELSE YEAR(requested_start)-1 END AS academic_year_start, COUNT_BIG(*) AS booking_count FROM dbo.BOOKING GROUP BY CASE WHEN MONTH(requested_start)>=9 THEN YEAR(requested_start) ELSE YEAR(requested_start)-1 END ORDER BY academic_year_start;
SELECT DATENAME(WEEKDAY,requested_start) AS weekday_name, DATEPART(HOUR,requested_start) AS start_hour, COUNT_BIG(*) AS booking_count FROM dbo.BOOKING GROUP BY DATENAME(WEEKDAY,requested_start), DATEPART(WEEKDAY,requested_start), DATEPART(HOUR,requested_start) ORDER BY DATEPART(WEEKDAY,requested_start), start_hour;
SELECT space_code, COUNT_BIG(*) AS booking_count FROM dbo.BOOKING GROUP BY space_code ORDER BY booking_count DESC, space_code;
SELECT impact_level, maintenance_status, COUNT_BIG(*) AS maintenance_count FROM dbo.MAINTENANCERECORD GROUP BY impact_level, maintenance_status ORDER BY impact_level, maintenance_status;
SELECT COUNT_BIG(*) AS acknowledgement_count, COUNT_BIG(DISTINCT booking_id) AS acknowledged_booking_count FROM dbo.BOOKING_ADVISORY_ACK;
SELECT t.name AS table_name, tr.name AS trigger_name, tr.is_disabled FROM sys.triggers tr JOIN sys.tables t ON t.object_id=tr.parent_id WHERE t.name IN ('BOOKING','MAINTENANCERECORD','USAGESESSION') ORDER BY t.name,tr.name;

IF EXISTS (SELECT 1 FROM #Checks WHERE result='FAIL')
    THROW 51402, 'Step 14 validation failed. Inspect the FAIL rows above.', 1;
