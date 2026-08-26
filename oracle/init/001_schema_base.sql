-- =====================================================================
-- 001_schema_base.sql
--
-- SCHEMA DE BASE - joue UNE SEULE FOIS, automatiquement, a la toute
-- premiere creation de la base (repertoire /container-entrypoint-initdb.d).
--
-- ATTENTION 1 : les scripts d'init sont executes par SYS, connecte au
-- CONTENEUR RACINE (CDB$ROOT) de l'instance FREE, et non dans la PDB.
-- D'ou le ALTER SESSION SET CONTAINER ci-dessous : sans lui, on
-- creerait les objets au mauvais endroit.
--
-- ATTENTION 2 : le fichier de donnees doit etre cree dans le VOLUME
-- MONTE (/opt/oracle/oradata), jamais ailleurs. Voir le commentaire
-- detaille plus bas - c'est le piege le plus couteux de tout ce projet.
--
-- Ce script prepare le terrain (tablespace, role, profil). Le compte
-- applicatif et le schema applicatif viennent APRES, a la main, via
-- les scripts du repertoire oracle/app/.
-- =====================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;

-- ---------------------------------------------------------------------
-- Tablespace dedie au cours
-- ---------------------------------------------------------------------
-- POURQUOI CE BLOC PL/SQL PLUTOT QU'UN SIMPLE « CREATE TABLESPACE » ?
--
-- Un nom de fichier RELATIF (DATAFILE 'tbs_3gb01.dbf') est resolu par
-- Oracle contre $ORACLE_HOME/dbs, qui se trouve dans le systeme de
-- fichiers du CONTENEUR - pas dans le volume Docker. Le fichier survit
-- alors a un « docker compose restart », mais disparait des que le
-- conteneur est recree, et la base redemarre avec :
--
--     ORA-01110: data file 25: '.../dbhomeFree/dbs/tbs_3gb01.dbf'
--     ORA-27037: unable to obtain file status
--
-- Il faut donc un chemin ABSOLU, sous /opt/oracle/oradata. Plutot que
-- de coder ce chemin en dur (il change selon la version : .../FREE/
-- FREEPDB1/ en 23ai, product/26ai/... ailleurs), on le DEDUIT du
-- fichier SYSTEM de la PDB courante, qui est forcement au bon endroit.
--
-- Equivalent en dur, si vous preferez le montrer ainsi en classe :
--     CREATE TABLESPACE tbs_3gb
--         DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/tbs_3gb01.dbf'
--         SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G;
-- ---------------------------------------------------------------------
DECLARE
    v_repertoire VARCHAR2(512);
    v_fichier    VARCHAR2(600);
BEGIN
    -- Repertoire reel des fichiers de donnees de cette PDB
    SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1))
      INTO v_repertoire
      FROM dba_data_files
     WHERE tablespace_name = 'SYSTEM'
       AND ROWNUM = 1;

    v_fichier := v_repertoire || 'tbs_3gb01.dbf';

    EXECUTE IMMEDIATE
        'CREATE TABLESPACE tbs_3gb '
        || 'DATAFILE ''' || v_fichier || ''' '
        || 'SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G '
        || 'EXTENT MANAGEMENT LOCAL '
        || 'SEGMENT SPACE MANAGEMENT AUTO';

    DBMS_OUTPUT.PUT_LINE('[3GB] Tablespace TBS_3GB cree : ' || v_fichier);
EXCEPTION
    WHEN OTHERS THEN
        -- ORA-01543 : le tablespace existe deja (script rejoue a la main)
        IF SQLCODE = -1543 THEN
            DBMS_OUTPUT.PUT_LINE('[3GB] TBS_3GB existe deja, on continue.');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------------------------------------------------------------------
-- Role applicatif
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Profil
-- ---------------------------------------------------------------------
-- En laboratoire, un mot de passe qui expire au bout de 180 jours ne
-- rend service a personne.
CREATE PROFILE p_cours_3gb LIMIT
    PASSWORD_LIFE_TIME  UNLIMITED
    FAILED_LOGIN_ATTEMPTS 10
    SESSIONS_PER_USER   UNLIMITED;

-- ---------------------------------------------------------------------
-- Trace de verification (visible dans « docker compose logs oracle-db »)
-- ---------------------------------------------------------------------
SET SERVEROUTPUT ON

DECLARE
    v_fichier VARCHAR2(600);
BEGIN
    SELECT file_name INTO v_fichier
      FROM dba_data_files
     WHERE tablespace_name = 'TBS_3GB'
       AND ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('[3GB] Schema de base pret dans FREEPDB1.');
    DBMS_OUTPUT.PUT_LINE('[3GB]   Tablespace TBS_3GB -> ' || v_fichier);
    DBMS_OUTPUT.PUT_LINE('[3GB]   Role R_APP_3GB, profil P_COURS_3GB.');

    IF v_fichier NOT LIKE '/opt/oracle/oradata/%' THEN
        DBMS_OUTPUT.PUT_LINE('[3GB] *** AVERTISSEMENT : le fichier de '
            || 'donnees n''est PAS dans le volume monte. Il sera perdu '
            || 'a la recreation du conteneur. ***');
    END IF;
END;
/

EXIT;
