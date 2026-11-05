-- =====================================================================
-- 41_exec_tests_cours_tapi.sql
--
-- Execution des tests unitaires utPLSQL de cours_tapi (suite
-- test_cours_tapi). Equivalent de « exec_tests.sql » de la lecon 13.
--
-- Prerequis : 40_test_cours_tapi.spc et 40_test_cours_tapi.bdy deja joues.
--
-- Execute connecte AVEC LE COMPTE APPLICATIF :
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/41_exec_tests_cours_tapi.sql"
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

Prompt Exécution des tests unitaires.
BEGIN
    ut.run('test_cours_tapi');
END;
/

-- Les tests appellent cours_tapi avec p_test = 'O' (sans COMMIT) et la
-- suite est en --%rollback(manual) : on annule ici tout ce qu'ils ont
-- modifie, car sqlplus fait un COMMIT implicite a l'EXIT.
ROLLBACK;

EXIT;
