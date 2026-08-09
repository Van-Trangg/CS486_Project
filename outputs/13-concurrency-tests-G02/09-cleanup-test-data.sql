/* Drops only the explicitly named Step13G02_* disposable database. */
USE master;
GO

DECLARE @DatabaseName SYSNAME = N'$(DatabaseName)';

IF @DatabaseName NOT LIKE N'Step13G02[_]%'
    THROW 52090, 'Cleanup refuses to drop a database unless its name matches Step13G02_*.', 1;

IF DB_ID(@DatabaseName) IS NULL
    THROW 52091, 'The requested Step 13 disposable database does not exist.', 1;

DECLARE @DropSql NVARCHAR(MAX) =
    N'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; '
  + N'DROP DATABASE ' + QUOTENAME(@DatabaseName) + N';';

EXEC sys.sp_executesql @DropSql;
PRINT 'Dropped Step 13 disposable database ' + @DatabaseName + '.';
GO
