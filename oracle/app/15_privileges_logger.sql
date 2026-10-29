-- =====================================================================
-- 15_privileges_logger.sql
--
-- Privileges supplementaires exiges par le paquetage logger
-- (25_logger_install.sql) : il cree un CONTEXT et des JOBS de purge.
-- Le role r_app_3gb de 001_schema_base.sql ne les contient pas, et
-- l'installateur de logger les veut accordes directement au compte.
--
-- Execute a la main, connecte en SYSTEM sur la PDB FREEPDB1 :
--   docker compose exec oracle-db sqlplus "system/<ORACLE_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/15_privileges_logger.sql"
-- =====================================================================

-- Doit correspondre a APP_USER du fichier .env
DEFINE app_user = app3gb

GRANT CREATE JOB         TO &app_user;
GRANT CREATE ANY CONTEXT TO &app_user;

-- Verification
COLUMN privilege FORMAT A25
SELECT privilege
  FROM dba_sys_privs
 WHERE grantee = UPPER('&app_user')
 ORDER BY privilege;

EXIT;
