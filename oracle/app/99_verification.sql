-- =====================================================================
-- 99_verification.sql
--
-- Test 1 de la validation de l'environnement : confirme qu'Oracle
-- repond, que la PDB est la bonne, que le compte applicatif est actif
-- et que le schema applicatif existe.
--
--   docker compose exec oracle-db sqlplus -s "app3gb/App3GB_2026@//localhost:1521/FREEPDB1" "@/sql/99_verification.sql"
--
-- Aucune redirection d'entree standard : la commande est identique sur
-- macOS, Linux, PowerShell et l'invite de commandes Windows.
-- =====================================================================

SET LINESIZE 120
SET PAGESIZE 50
SET FEEDBACK OFF

COLUMN element FORMAT A22
COLUMN valeur  FORMAT A40

PROMPT
PROMPT === Verification de l'environnement Oracle 3GB ===
PROMPT

SELECT 'Base (CDB)'      AS element, SYS_CONTEXT('USERENV','DB_NAME')  AS valeur FROM dual
UNION ALL
SELECT 'PDB courante',                SYS_CONTEXT('USERENV','CON_NAME')          FROM dual
UNION ALL
SELECT 'Usager connecte',             USER                                        FROM dual
UNION ALL
SELECT 'Version',                     (SELECT version_full FROM product_component_version WHERE ROWNUM = 1) FROM dual
UNION ALL
SELECT 'Tables du schema',            TO_CHAR(COUNT(*))  FROM user_tables
UNION ALL
SELECT 'Lignes dans ETUDIANT',        TO_CHAR(COUNT(*))  FROM etudiant;

PROMPT
PROMPT Attendu : PDB = FREEPDB1, usager = APP3GB, ETUDIANT = 3 lignes.
PROMPT

EXIT;
