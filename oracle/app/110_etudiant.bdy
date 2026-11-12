CREATE OR REPLACE PACKAGE BODY etudiant_api IS
    -- variable global pour logger afin de contenir le nom du package
    gc_scope_prefix CONSTANT VARCHAR2(31) := lower($$plsql_unit) || 'etudiant_api.';
    FUNCTION afficher (p_id_etudiant number) return varchar2 AS
        -- variable pour journaliser (logger) afin de peupler la colonne scope avec package + fonction de logger_logs
        l_scope           logger_logs.scope%type := gc_scope_prefix || 'ins_cours';
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
        rec_etudiant etudiant%ROWTYPE;
    BEGIN
        logger.append_param(l_params, 'p_id_etudiant: ', p_id_etudiant);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        IF p_id_etudiant IS NULL THEN
            RAISE ex_id_etudiant_is_null;
        END IF;
        DELETE FROM etudiant WHERE id = p_id_etudiant;
        ROLLBACK; -- Annuler la suppression pour l'exemple
        return 'L''étudiant a été supprimé';
    EXCEPTION
        WHEN ex_id_etudiant_is_null THEN
            return 'L''ID de l''étudiant est NULL';
        WHEN NO_DATA_FOUND THEN
            return 'Aucun étudiant trouvé avec l''ID ' || p_id_etudiant;
        WHEN ex_inscription_existe THEN
            return 'Impossible de supprimer l''étudiant'|| p_id_etudiant ||'car il est inscrit à un cours';
    END effacer;

END etudiant_api;
