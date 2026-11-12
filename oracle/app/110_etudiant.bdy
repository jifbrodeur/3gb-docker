-- =====================================================================
-- 110_etudiant.bdy
--
-- Corps du paquetage etudiant_api. Prerequis : 110_etudiant.spc deja
-- joue, et le paquetage logger installe (25_logger_install.sql).
--
-- Execute connecte AVEC LE COMPTE APPLICATIF :
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/110_etudiant.bdy"
-- =====================================================================

SET DEFINE OFF

-- etudiant_api journalise avec logger : on arrete tout s'il est absent.
WHENEVER SQLERROR EXIT FAILURE

Prompt Création du package body etudiant_api.
CREATE OR REPLACE PACKAGE BODY etudiant_api IS
    -- variable global pour logger afin de contenir le nom du package
    -- ($$plsql_unit vaut deja ETUDIANT_API : on ajoute seulement le point)
    gc_scope_prefix CONSTANT VARCHAR2(31) := lower($$plsql_unit) || '.';

    FUNCTION afficher (p_id_etudiant number) return varchar2 AS
        -- variable pour journaliser (logger) afin de peupler la colonne scope avec package + fonction de logger_logs
        l_scope           logger_logs.scope%type := gc_scope_prefix || 'afficher';
        -- variable pour logger afin de peupler la colonne des paramètres (param) de logger_logs
        l_params          logger.tab_param;
        ex_id_etudiant_is_null EXCEPTION;
        rec_etudiant etudiant%ROWTYPE;
    BEGIN
        logger.append_param(l_params, 'p_id_etudiant: ', p_id_etudiant);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        IF p_id_etudiant IS NULL THEN
            RAISE ex_id_etudiant_is_null;
        END IF;
        SELECT * INTO rec_etudiant FROM etudiant WHERE id = p_id_etudiant;
       -- return 'L''étudiant est : ' || rec_etudiant.nom;
        return rec_etudiant.nom;
    EXCEPTION
        WHEN ex_id_etudiant_is_null THEN
            return 'L''ID de l''étudiant est NULL';
        WHEN NO_DATA_FOUND THEN
            return 'Aucun étudiant trouvé avec l''ID ' || p_id_etudiant;
    END afficher;

    FUNCTION effacer (p_id_etudiant number) return varchar2 AS
        -- variable pour journaliser (logger) afin de peupler la colonne scope avec package + fonction de logger_logs
        l_scope           logger_logs.scope%type := gc_scope_prefix || 'effacer';
        -- variable pour logger afin de peupler la colonne des paramètres (param) de logger_logs
        l_params          logger.tab_param;
        ex_id_etudiant_is_null EXCEPTION;
        ex_inscription_existe EXCEPTION;
        PRAGMA EXCEPTION_INIT(ex_inscription_existe, -2292);
    BEGIN
        logger.append_param(l_params, 'p_id_etudiant: ', p_id_etudiant);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        IF p_id_etudiant IS NULL THEN
            RAISE ex_id_etudiant_is_null;
        END IF;
        -- Point de reprise : le ROLLBACK plus bas annule SEULEMENT la
        -- suppression, pas le travail en cours de l'appelant.
        SAVEPOINT avant_effacer;
        DELETE FROM etudiant WHERE id = p_id_etudiant;
        -- Un DELETE qui ne touche aucune ligne ne leve PAS NO_DATA_FOUND
        -- (contrairement a SELECT INTO) : il faut tester SQL%ROWCOUNT.
        IF SQL%ROWCOUNT = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;
        ROLLBACK TO SAVEPOINT avant_effacer; -- Annuler la suppression pour l'exemple
        return 'L''étudiant a été supprimé';
    EXCEPTION
        WHEN ex_id_etudiant_is_null THEN
            return 'L''ID de l''étudiant est NULL';
        WHEN NO_DATA_FOUND THEN
            return 'Aucun étudiant trouvé avec l''ID ' || p_id_etudiant;
        WHEN ex_inscription_existe THEN
            return 'Impossible de supprimer l''étudiant ' || p_id_etudiant || ' car il est inscrit à un cours';
    END effacer;

END etudiant_api;
/
SHOW ERRORS;

SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'ETUDIANT_API' ORDER BY 2;

EXIT;
