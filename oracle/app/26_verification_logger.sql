-- =====================================================================
-- 26_verification_logger.sql
--
-- Verifie que logger (25_logger_install.sql) est installe et
-- fonctionne dans le schema applicatif : version, niveau, objets
-- invalides, paquetage, jobs de purge, puis un essai d'ecriture dans
-- LOGGER_LOGS. La ligne d'essai est effacee a la fin.
--
-- Execute connecte AVEC LE COMPTE APPLICATIF :
--   docker compose exec oracle-db sqlplus -s "app3gb/App3GB_2026@//localhost:1521/FREEPDB1" "@/sql/26_verification_logger.sql"
--
-- Aucune redirection d'entree standard : la commande est identique sur
-- macOS, Linux, PowerShell et l'invite de commandes Windows.
-- =====================================================================

SET LINESIZE 120
SET PAGESIZE 50
SET FEEDBACK OFF

COLUMN element FORMAT A28
COLUMN valeur  FORMAT A40

PROMPT
PROMPT === Verification de logger ===
PROMPT

-- Essai d'ecriture. logger ecrit en transaction autonome : la ligne
-- existe meme sans COMMIT de notre part.
EXEC logger.log('Essai de 26_verification_logger.sql', 'verif_logger');

SELECT 'Version de logger'        AS element,
       (SELECT pref_value FROM logger_prefs WHERE pref_name = 'LOGGER_VERSION') AS valeur
  FROM dual
UNION ALL
SELECT 'Niveau de journalisation',
       (SELECT pref_value FROM logger_prefs WHERE pref_name = 'LEVEL')
  FROM dual
UNION ALL
SELECT 'Objets LOGGER invalides',
       TO_CHAR(COUNT(*))
  FROM user_objects
 WHERE (object_name LIKE 'LOGGER%' OR object_name LIKE 'BIU_LOGGER%')
   AND status = 'INVALID'
UNION ALL
SELECT 'Paquetage LOGGER',
       NVL(MAX(status), 'ABSENT')
  FROM user_objects
 WHERE object_name = 'LOGGER' AND object_type = 'PACKAGE BODY'
UNION ALL
SELECT 'Jobs de purge actifs',
       TO_CHAR(COUNT(*))
  FROM user_scheduler_jobs
 WHERE job_name LIKE 'LOGGER%' AND enabled = 'TRUE'
UNION ALL
SELECT 'Essai d''ecriture',
       CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'ECHEC' END
  FROM logger_logs
 WHERE scope = 'verif_logger';

-- Nettoyage de la ligne d'essai
DELETE FROM logger_logs WHERE scope = 'verif_logger';
COMMIT;

PROMPT
PROMPT Attendu : version 3.1.1, niveau DEBUG, 0 objet invalide,
PROMPT paquetage VALID, 2 jobs actifs, essai d'ecriture OK.
PROMPT

EXIT;
