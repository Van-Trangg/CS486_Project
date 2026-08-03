USE University;
GO
DELETE FROM dbo.STEP13_UNSAFE_BOOKING WHERE test_code = 'T13-UNSAFE';
PRINT 'Unsafe test rows removed. Protected tests may now run.';
GO
