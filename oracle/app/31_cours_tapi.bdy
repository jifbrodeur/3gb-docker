-- =====================================================================
-- 31_cours_tapi.bdy
--
-- Corps du paquetage cours_tapi (Lecon 13, version 2.1.0 JSON:API).
-- Prerequis : 30_cours.sql et 31_cours_tapi.spc deja joues, et le
-- paquetage logger installe (25_logger_install.sql).
--
-- Execute connecte AVEC LE COMPTE APPLICATIF :
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/31_cours_tapi.bdy"
-- =====================================================================

SET DEFINE OFF

-- cours_tapi journalise avec logger : on arrete tout s'il est absent.
WHENEVER SQLERROR EXIT FAILURE
DECLARE
    v_nb NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM user_objects
     WHERE object_name = 'LOGGER' AND object_type = 'PACKAGE BODY' AND status = 'VALID';
    IF v_nb = 0 THEN
        RAISE_APPLICATION_ERROR(-20000,
            'Paquetage LOGGER absent : jouer d''abord /sql/25_logger_install.sql');
    END IF;
END;
/
WHENEVER SQLERROR CONTINUE

Prompt Création du package body cours_tapi.
CREATE OR REPLACE PACKAGE BODY cours_tapi AS
    -- variable global pour logger afin de contenir le nom du package
    gc_scope_prefix CONSTANT VARCHAR2(31) := lower($$plsql_unit) || '.';
 /**
    * Description   fonction pour insérer un cours
    *
    * @version      2.1.0               refonte pour traiter les exceptions en tableau JSON et ajout de status et format JSON:API
    *
    * @example      l_resultant := cours_tapi.ins_cours ('','ABC', 'cours de base de données', 'N');
    *
    * @issue        problème xyz
    *
    * @author       JF Brodeur
    * @created      2023-11-2
    * @param        p_derscription      description du cours
    * @param        p_sigle             sigle du cours ex.: 420-3GB-BB
    * @param        p_credit            nombre de crédits du cours
    * @param        p_test              paramètre pour ne pas sauvegarder les tests, si 'N' alors commit
    * @return       l_reponse           objet JSON avec un status et la clé primaire id_cours du cours créée
    * @exception    ex_nom_cours_null   si le nom du cours est null, retourné dans un objet JSON avec status et code d erreur -1400
    * @exception    OTHERS              excepttion autre non traitée, retourné dans un objet JSON avec status et code d erreur -999
    */
    FUNCTION ins_cours (
        p_credit cours.credit%type, p_nom_cours cours.nom_cours%type, p_description_cours cours.description_cours%type, p_test VARCHAR2 DEFAULT 'N'
    ) RETURN VARCHAR2 AS
        -- variable pour journaliser (logger) afin de peupler la colonne scope avec package + fonction de logger_logs
        l_scope           logger_logs.scope%type := gc_scope_prefix || 'ins_cours';
        -- variable pour logger afin de peupler la colonne des paramètres (param) de logger_logs
        l_params          logger.tab_param;
        l_id_cours        cours.id_cours%type;
        l_reponse         VARCHAR2(4000);
        l_error_mess      VARCHAR2(4000);
        l_error_code      NUMBER;
        ex_nom_cours_null EXCEPTION;
        PRAGMA EXCEPTION_INIT(ex_nom_cours_null, -1400);
    BEGIN
        -- affectation de tous les paramètres passés à la fonction pour aider au débuggage
        logger.append_param(l_params, 'p_credit: ', p_credit);
        logger.append_param(l_params, 'p_nom_cours: ', p_nom_cours);
        logger.append_param(l_params, 'p_description_cours: ', p_description_cours);
        logger.append_param(l_params, 'p_test: ', p_test);
        -- écriture de tous les paramètres dans le journal (logger) 
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        INSERT INTO cours (
            credit, nom_cours, description_cours
        ) VALUES (
            p_credit, p_nom_cours, p_description_cours
        ) RETURNING id_cours INTO l_id_cours;
        logger.append_param(l_params, 'l_id_cours: ', l_id_cours);
        IF p_test = 'N' THEN
            COMMIT;
        END IF;
        --creation d un objet JSON avec le status et l id_cours inséré
        l_reponse := JSON_OBJECT(
            'data' VALUE JSON_OBJECT(
            'type'       VALUE 'cours',
            'id'         VALUE l_id_cours,
            'attributes' VALUE JSON_OBJECT(
                'nomCours'         VALUE p_nom_cours,
                'descriptionCours' VALUE p_description_cours,
                'credit'           VALUE p_credit
            )
            ),
            'meta' VALUE JSON_OBJECT(
            'status'     VALUE 'success',
            'statusCode' VALUE 201
            )
        );
        logger.log('>>>FIN de la procédure', l_scope, NULL, l_params);
    RETURN l_reponse;
    EXCEPTION
        -- Dans ce bloc d exception le traitement de l erreur est fait dans le bloc d exception et non dans la partie js
        WHEN ex_nom_cours_null THEN
            -- sqlerrm et sqlcode sont des fonctions qui doivent être obligatoirement affectées à des variables, s utilise dans le cas d execption de la BD
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            ROLLBACK;
            logger.log_error('>>>ERREUR de type ex_nom_cours_null', l_scope, null, l_params);
            --creation d un objet JSON avec un status et un code d erreur - https://blog.postman.com/best-practices-for-api-error-handling/
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                JSON_OBJECT(
                    'status'  VALUE '400',
                    'title'   VALUE 'Nom du cours requis',
                    'detail'  VALUE 'Erreur nom_cours null lors de l insertion du cours ORA-01400',
                    'code'    VALUE TO_CHAR(l_error_code),
                    'meta'    VALUE JSON_OBJECT('timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                    )
                )
                )
            );
            RETURN l_reponse;
        WHEN OTHERS THEN
            ROLLBACK;
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            logger.log_error('>>>ERREUR de de type OTHERS', l_scope, null, l_params);
            --creation d un objet JSON avec un status et un code d erreur
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                JSON_OBJECT(
                    'status'  VALUE '400',
                    'title'   VALUE 'Nom du cours requis',
                    'detail'  VALUE 'Erreur nom_cours null lors de l’insertion du cours',
                    'code'    VALUE TO_CHAR(l_error_code),
                    'meta'    VALUE JSON_OBJECT(
                    'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                    )
                )
                )
            );
            RETURN l_reponse;
    END ins_cours; /**
    * Description   fonction pour mettre à jour un cours - ATTENTION cette fonction ne peut pas mettre une colonne à null
    *
    * @version      2.1.0               refonte pour traiter les exceptions en tableau JSON et ajout de status et format JSON:API
    *
    * @example      l_resultat : = cours_tapi.upd_cours (12,1,null,null);
    *
    * @issue        problème xyz
    *
    * @author       JF Brodeur
    * @created      2023-11-2
    * @param        p_derscription      description du cours
    * @param        p_sigle             sigle du cours ex. 420-3GB-BB
    * @param        p_credit            nombre de crédits du cours
    * @param        p_id_cours          la clé primaire du cours à mettre à jour
    * @return       l_reponse           objet JSON avec un status et la clé primaire id_cours du cours créée
    * @exception    ex_id_is_null       si le paramètre p_id_cours du cours est null, retourne dans un objet JSON avec status et code d erreur -1
    * @exception    ex_id_inexistant    si aucune rangée dans la table ne correspond au p_id_cours, code d erreur -2
    * @exception    OTHERS              excepttion autre non traitée, retourné dans un objet JSON avec status et code d erreur -999
    */
    FUNCTION upd_cours (
        p_credit IN cours.credit%type DEFAULT NULL, p_id_cours IN cours.id_cours%type, p_nom_cours IN cours.nom_cours%type DEFAULT NULL, p_description_cours IN cours.description_cours%type DEFAULT NULL, p_test VARCHAR2 DEFAULT 'N'
    ) RETURN VARCHAR2 IS
        l_scope              logger_logs.scope%type := gc_scope_prefix || 'upd_cours';
        l_params             logger.tab_param;
        l_id_cours           cours.id_cours%type;
        r_cours              cours%rowtype;
        l_nbre_rangee        NUMBER;
        l_reponse            VARCHAR2(4000);
        l_error_mess         VARCHAR2(4000);
        l_error_code         NUMBER;
        ex_id_is_null        EXCEPTION;
        ex_id_inexistant     EXCEPTION;
    BEGIN
        logger.append_param(l_params, 'p_id_cours: ', p_id_cours);
        logger.append_param(l_params, 'p_credit: ', p_credit);
        logger.append_param(l_params, 'p_nom_cours: ', p_nom_cours);
        logger.append_param(l_params, 'p_description_cours: ', p_description_cours);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        IF p_id_cours IS NULL THEN
            RAISE ex_id_is_null;
        END IF;
        -- afin de faire un seul update, on peuple un record avec toutes qui peuvent être mis à jour
        SELECT * INTO r_cours
        FROM cours
        WHERE id_cours = p_id_cours;
        UPDATE cours
        SET
            credit = coalesce(
                p_credit, r_cours.credit
            ), nom_cours = coalesce(
                p_nom_cours, r_cours.nom_cours
            ), description_cours = coalesce(
                p_description_cours, r_cours.description_cours
            )
        WHERE
            id_cours = p_id_cours
        RETURNING id_cours INTO l_id_cours;
        l_nbre_rangee := sql%rowcount;
        logger.append_param(l_params, 'sql%l_nbre_rangee: ', l_nbre_rangee);
        logger.log('>>>FIN de la procédure', l_scope, NULL, l_params);
        IF p_test = 'N' THEN
            COMMIT;
        END IF;
        --creation d un objet JSON avec le status et l id_cours maj en format JSON:API
        l_reponse := JSON_OBJECT(
            'data' VALUE JSON_OBJECT(
                'type'       VALUE 'cours',
                'id'         VALUE l_id_cours,
                'attributes' VALUE JSON_OBJECT(
                    'nomCours'         VALUE p_nom_cours,
                    'descriptionCours' VALUE p_description_cours,
                    'credit'           VALUE p_credit
                )
            ),
            'meta' VALUE JSON_OBJECT(
                'status'     VALUE 'success',
                'statusCode' VALUE 200
            )
        );
        RETURN l_reponse;
    EXCEPTION
        WHEN ex_id_is_null THEN
            -- pas d utilisation de SQLERRM et SQLCODE car on a une exception personnalisée
            ROLLBACK;
            logger.log_error('>>>ERREUR de de type ex_id_is_null la procédure', l_scope, null, l_params);
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '400',
                        'title'   VALUE 'ID du cours requis',
                        'detail'  VALUE 'Erreur id est null lors de la maj du cours',
                        'code'    VALUE TO_CHAR(-1),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
        WHEN no_data_found THEN
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            ROLLBACK;
            logger.log_error('>>>ERREUR de de type ex_id_inexistant la procédure', l_scope, null, l_params);
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '404',
                        'title'   VALUE 'Cours non trouvé',
                        'detail'  VALUE 'Erreur id inexistant '|| p_id_cours || ' lors de la maj du cours',
                        'code'    VALUE TO_CHAR(l_error_code),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
        WHEN OTHERS THEN
            ROLLBACK;
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            logger.log_error('>>>ERREUR de de type OTHERS la procédure', l_scope, null, l_params);
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '500',
                        'title'   VALUE 'Erreur système',
                        'detail'  VALUE 'Erreur OTHERS lors de la mise à jour du cours',
                        'code'    VALUE TO_CHAR(l_error_code),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
    END upd_cours; /**
    * Description fonction pour effacer un cours
    *
    * @version      2.1.0               refonte pour traiter les exceptions en tableau JSON et ajout de status et format JSON:API
    *
    * @example      cours_tapi.del_cours (12);
    *
    * @issue: n/a
    *
    * @author       JF Brodeur
    * @created      2023-11-2
    * @param        id_cours            la clé primaire du cours à mettre à jour
    * @return       l_reponse           objet JSON avec un status et la clé primaire id_cours du cours créée
    * @exception    ex_id_is_null       si le paramètre p_id_cours du cours est null, retourne dans un objet JSON avec status et code d erreur -1
    * @exception    ex_id_inexistant    si aucune rangée dans la table ne correspond au p_id_cours, code d erreur -2
    * @exception    OTHERS              excepttion autre non traitée, retourné dans un objet JSON avec status et code d erreur -999
    */
    FUNCTION del_cours (
        p_id_cours IN cours.id_cours%type, p_test VARCHAR2 DEFAULT 'N'
    ) RETURN VARCHAR2 IS
        l_scope              logger_logs.scope%type := gc_scope_prefix || 'del_cours';
        l_params             logger.tab_param;
        l_nbre_rangee        NUMBER;
        l_reponse            VARCHAR2(4000);
        l_error_mess         VARCHAR2(4000);
        l_error_code         NUMBER;
        ex_id_is_null        EXCEPTION;
        ex_id_inexistant     EXCEPTION;
    BEGIN
        logger.append_param(l_params, 'p_id_cours: ', p_id_cours);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        IF p_id_cours IS NULL THEN
            RAISE ex_id_is_null;
        END IF;        
        DELETE FROM cours
        WHERE
            id_cours = p_id_cours;
        l_nbre_rangee := sql%rowcount;
        logger.append_param(l_params, 'SQL%ROWCOUNT: ', sql%rowcount);
        logger.log('>>>FIN de la procédure', l_scope, NULL, l_params);
        IF l_nbre_rangee = 0 THEN
            RAISE ex_id_inexistant;
        END IF;
        IF p_test = 'N' THEN
            COMMIT;
        END IF;
        --creation d un objet JSON avec le status et l id_cours effacé en format JSON:API
        l_reponse := JSON_OBJECT(
            'data' VALUE JSON_OBJECT(
                'type'  VALUE 'cours',
                'id'    VALUE p_id_cours
            ),
            'meta' VALUE JSON_OBJECT(
                'status'     VALUE 'success',
                'statusCode' VALUE 200
            )
        );
        RETURN l_reponse;
    EXCEPTION
            WHEN ex_id_is_null THEN
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            ROLLBACK;
            logger.log_error('>>>ERREUR de de type ex_id_is_null', l_scope, null, l_params);
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '400',
                        'title'   VALUE 'ID du cours requis',
                        'detail'  VALUE 'Erreur id est null lors de l effacement du cours',
                        'code'    VALUE TO_CHAR(-1),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
        WHEN ex_id_inexistant THEN
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            ROLLBACK;
            logger.log_error('>>>ERREUR de de type ex_id_inexistant', l_scope, null, l_params);
            --creation d un objet JSON avec un status error et un code d erreur
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '404',
                        'title'   VALUE 'Cours non trouvé',
                        'detail'  VALUE 'Erreur id inexistant '|| p_id_cours ||' lors de l effacement du cours',
                        'code'    VALUE TO_CHAR(-2),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
        WHEN OTHERS THEN
            ROLLBACK;
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            logger.log_error('>>>ERREUR de de type OTHERS la procédure', l_scope, null, l_params);
            --creation d un objet JSON avec un status error et un code d erreur
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '500',
                        'title'   VALUE 'Erreur système',
                        'detail'  VALUE 'Erreur OTHERS lors de l effacement du cours',
                        'code'    VALUE TO_CHAR(l_error_code),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
    END del_cours; /**
    * Description fonction pour retourner les information d un ou plusieurscours
    *
    * @version      2.1.0           refonte pour traiter les exceptions en tableau JSON et ajout de status, ajout de pagination (p_limite, p_debut et p_taille) et format JSON:API
    *
    * @example      l_resultat := cours_tapi.get_cours (12);
    *
    * @issue        n/a
    *
    * @author       JF Brodeur
    * @created      2023-11-2
    * @param        id_cours            la clé primaire du cours à retourner les informations, si null retourne tous les cours
    * @param        p_limite            nombre de rangées maximum à retourner
    * @param        p_debut             rangée de départ
    * @param        p_taille            nombre de rangées à retournées
    * @return       l_reponse           tableau JSON qui contient les informations des cours
    * @exception    ex_aucun_cours      si aucun cours ne correspond aux critères une exception Oracle est levée avec un code d erreur -20001
    * @exception    OTHERS              excepttion autre non traitée, retourné dans un objet JSON avec status et code d erreur -999
    */
    FUNCTION get_cours (
        p_id_cours  IN cours.id_cours%type,
        p_limite    IN NUMBER DEFAULT 5,
        p_debut     IN NUMBER DEFAULT 0,
        p_taille    IN NUMBER DEFAULT 4
    ) RETURN VARCHAR2 IS
        l_scope         logger_logs.scope%type := gc_scope_prefix || 'get_cours';
        l_params        logger.tab_param;
        l_reponse       VARCHAR2(4000);
        l_json_cours    VARCHAR2(4000);
        l_error_mess    VARCHAR2(4000);
        l_error_code    NUMBER;
        ex_aucun_cours  EXCEPTION;
    BEGIN
        logger.append_param(l_params, 'p_id_cours: ', p_id_cours);
        logger.log('>>>DÉBUT de la procédure', l_scope, NULL, l_params);
        -- Requête pour récupérer les cours au format JSON:API
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'type'  VALUE 'cours',
                'id'    VALUE id_cours,
                'attributes' VALUE JSON_OBJECT(
                    'nomCours'         VALUE nom_cours,
                    'descriptionCours' VALUE description_cours,
                    'credit'           VALUE credit
                )
            )
        ) INTO l_json_cours
        FROM cours
        WHERE id_cours=coalesce(p_id_cours, id_cours)
        OFFSET p_debut ROWS FETCH NEXT 
            CASE WHEN p_limite > 0 THEN LEAST(p_limite, p_taille) ELSE p_taille END 
        ROWS ONLY;
        
        IF l_json_cours IS NULL THEN
            RAISE ex_aucun_cours;
        END IF;
        
        -- Formatage de la réponse conforme à JSON:API
        l_reponse := JSON_OBJECT(
            'data' VALUE l_json_cours FORMAT JSON,
            'meta' VALUE JSON_OBJECT(
                'status'     VALUE 'success',
                'statusCode' VALUE 200,
                'pagination' VALUE JSON_OBJECT(
                    'offset' VALUE p_debut,
                    'limit'  VALUE CASE WHEN p_limite > 0 THEN LEAST(p_limite, p_taille) ELSE p_taille END
                )
            )
        );
        logger.append_param(l_params, 'l_reponse: ', l_reponse);
        logger.log('>>>FIN de la procédure', l_scope, NULL, l_params);
        RETURN l_reponse;
    EXCEPTION
        WHEN ex_aucun_cours THEN
            ROLLBACK;
            logger.log_error('>>>ERREUR de de type ex_aucun_cours', l_scope, null, l_params);
            -- Gestion de l'exception directement en PL/SQL au lieu de faire un RAISE_APPLICATION_ERROR
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '404',
                        'title'   VALUE 'Cours non trouvé',
                        'detail'  VALUE 'Aucun cours trouvé pour cette recherche',
                        'code'    VALUE TO_CHAR(-20001),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
        WHEN OTHERS THEN
            ROLLBACK;
            l_error_mess := sqlerrm;
            l_error_code := sqlcode;
            logger.log_error('>>>ERREUR de de type OTHERS la procédure', l_scope, null, l_params);
            l_reponse := JSON_OBJECT(
                'errors' VALUE JSON_ARRAY(
                    JSON_OBJECT(
                        'status'  VALUE '500',
                        'title'   VALUE 'Erreur système',
                        'detail'  VALUE 'Erreur OTHERS lors de la récupération du cours',
                        'code'    VALUE TO_CHAR(l_error_code),
                        'meta'    VALUE JSON_OBJECT(
                            'timestamp' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS')
                        )
                    )
                )
            );
            RETURN l_reponse;
    END get_cours;
END cours_tapi;
/
SHOW ERRORS;

SELECT object_name, object_type, status FROM user_objects WHERE object_name IN ('COURS', 'COURS_TAPI') ORDER BY 2;

EXIT;
