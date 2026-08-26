-- =====================================================================
-- 10_utilisateur.sql
--
-- Creation du COMPTE APPLICATIF. Ce script n'est PAS joue
-- automatiquement : on l'execute a la main, connecte en SYSTEM sur la
-- PDB FREEPDB1, une fois que le conteneur Oracle est demarre.
--
--   docker compose exec oracle-db sqlplus system/<ORACLE_PASSWORD>@//localhost:1521/FREEPDB1 @/sql/10_utilisateur.sql
--
-- Il suppose que 001_schema_base.sql a deja cree TBS_3GB, R_APP_3GB
-- et P_COURS_3GB.
-- =====================================================================

-- Doivent correspondre a APP_USER / APP_USER_PASSWORD du fichier .env
DEFINE app_user     = app3gb
DEFINE app_password = "App3GB_2026"

CREATE USER &app_user IDENTIFIED BY &app_password
    DEFAULT TABLESPACE   tbs_3gb
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON   tbs_3gb
    PROFILE              p_cours_3gb;

-- Les privileges passent par le role, pas par des GRANT directs.
GRANT r_app_3gb TO &app_user;

-- Le role doit etre actif par defaut, sinon node-oracledb se connecte
-- sans aucun privilege.
ALTER USER &app_user DEFAULT ROLE ALL;

-- Verification
COLUMN username   FORMAT A20
COLUMN profile    FORMAT A15
COLUMN account_status FORMAT A20
SELECT username, profile, account_status, default_tablespace
  FROM dba_users
 WHERE username = UPPER('&app_user');

EXIT;
