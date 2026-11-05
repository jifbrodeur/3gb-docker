-- =====================================================================
-- 45_desinstaller_utplsql.sql
--
-- Supprime utPLSQL (schema UT3 et ses synonymes publics), par exemple
-- apres une installation partielle. Les tests de app3gb
-- (test_cours_tapi) ne sont pas touches, mais ne s'executent plus tant
-- qu'utPLSQL n'est pas reinstalle.
--
-- Execute a la main, connecte en SYS sur la PDB FREEPDB1 :
--   docker compose exec oracle-db sqlplus "sys/<ORACLE_PASSWORD>@//localhost:1521/FREEPDB1 as sysdba" "@/sql/45_desinstaller_utplsql.sql"
-- =====================================================================

-- Synonymes publics qui pointent vers UT3
BEGIN
    FOR s IN (SELECT synonym_name FROM dba_synonyms
               WHERE owner = 'PUBLIC' AND table_owner = 'UT3') LOOP
        EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM "' || s.synonym_name || '"';
    END LOOP;
END;
/

-- Le schema UT3 et tous ses objets
BEGIN
    EXECUTE IMMEDIATE 'DROP USER ut3 CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1918 THEN RAISE; END IF;  -- -1918 = usager inexistant
END;
/

-- Verification : 0 et 0 attendus
SELECT COUNT(*) AS usager_ut3 FROM dba_users WHERE username = 'UT3';
SELECT COUNT(*) AS synonymes_ut3 FROM dba_synonyms WHERE owner = 'PUBLIC' AND table_owner = 'UT3';

EXIT;
