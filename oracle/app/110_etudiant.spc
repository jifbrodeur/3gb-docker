-- =====================================================================
-- 110_etudiant.spc
--
-- Specification du paquetage etudiant_api. Prerequis : la table
-- etudiant (20_schema_applicatif.sql).
--
-- Execute connecte AVEC LE COMPTE APPLICATIF, avant 110_etudiant.bdy :
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/110_etudiant.spc"
-- =====================================================================

SET DEFINE OFF

Prompt Création du package spec etudiant_api.
CREATE OR REPLACE PACKAGE etudiant_api IS
    FUNCTION afficher (p_id_etudiant NUMBER) RETURN VARCHAR2;
    FUNCTION effacer (p_id_etudiant NUMBER) RETURN VARCHAR2;
END etudiant_api;
/
SHOW ERRORS;

EXIT;
