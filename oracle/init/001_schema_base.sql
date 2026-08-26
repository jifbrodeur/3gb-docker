-- =====================================================================
-- 001_schema_base.sql
--
-- SCHEMA DE BASE - joue UNE SEULE FOIS, automatiquement, a la toute
-- premiere creation de la base (repertoire /container-entrypoint-initdb.d).
--
-- ATTENTION : les scripts d'init sont executes par SYS, connecte au
-- CONTENEUR RACINE (CDB$ROOT) de l'instance FREE, et non dans la PDB.
-- D'ou le ALTER SESSION SET CONTAINER ci-dessous : sans lui, on
-- creerait les objets au mauvais endroit.
--
-- Ce script prepare le terrain (tablespace, role, profil). Le compte
-- applicatif et le schema applicatif viennent APRES, a la main, via
-- les scripts du repertoire oracle/app/.
-- =====================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;

-- --- Tablespace dedie au cours ---------------------------------------
-- Separe les donnees du cours de USERS : on peut le sauvegarder,
-- le mettre hors ligne ou le detruire sans toucher au reste.
CREATE TABLESPACE tbs_3gb
    DATAFILE 'tbs_3gb01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M MAXSIZE 2G
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO;

-- --- Role applicatif --------------------------------------------------
-- Les privileges sont accordes au ROLE, jamais directement a
-- l'utilisateur : c'est ce qui permet d'ajouter un 2e, un 3e compte
-- plus tard sans rejouer tous les GRANT.
CREATE ROLE r_app_3gb;

GRANT CREATE SESSION      TO r_app_3gb;
GRANT CREATE TABLE        TO r_app_3gb;
GRANT CREATE VIEW         TO r_app_3gb;
GRANT CREATE SEQUENCE     TO r_app_3gb;
GRANT CREATE PROCEDURE    TO r_app_3gb;
GRANT CREATE TRIGGER      TO r_app_3gb;
GRANT CREATE SYNONYM      TO r_app_3gb;

-- --- Profil ------------------------------------------------------------
-- En laboratoire, un mot de passe qui expire au bout de 180 jours ne
-- rend service a personne.
CREATE PROFILE p_cours_3gb LIMIT
    PASSWORD_LIFE_TIME  UNLIMITED
    FAILED_LOGIN_ATTEMPTS 10
    SESSIONS_PER_USER   UNLIMITED;

-- --- Trace de verification --------------------------------------------
-- Visible dans « docker compose logs oracle-db ».
BEGIN
    DBMS_OUTPUT.PUT_LINE('[3GB] Schema de base cree dans FREEPDB1 : '
        || 'tablespace TBS_3GB, role R_APP_3GB, profil P_COURS_3GB.');
END;
/

EXIT;
