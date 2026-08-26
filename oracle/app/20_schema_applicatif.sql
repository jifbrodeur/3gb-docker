-- =====================================================================
-- 20_schema_applicatif.sql
--
-- SCHEMA APPLICATIF de demonstration. Execute a la main, connecte
-- AVEC LE COMPTE APPLICATIF (pas SYSTEM) : les objets appartiennent
-- ainsi a app3gb, ce qui evite les synonymes et les prefixes de schema
-- dans le code Node.
--
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/20_schema_applicatif.sql"
--
-- C'est ce fichier que l'on remplace par le modele de donnees du cours.
-- =====================================================================

-- Idempotent : on peut rejouer le script sans erreur.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE etudiant CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;  -- -942 = table inexistante
END;
/

CREATE TABLE etudiant (
    id           NUMBER GENERATED ALWAYS AS IDENTITY,
    matricule    VARCHAR2(10)  NOT NULL,
    nom          VARCHAR2(50)  NOT NULL,
    prenom       VARCHAR2(50)  NOT NULL,
    courriel     VARCHAR2(120),
    programme    VARCHAR2(60),
    date_creation TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_etudiant  PRIMARY KEY (id),
    CONSTRAINT uk_etudiant_matricule UNIQUE (matricule),
    CONSTRAINT ck_etudiant_courriel  CHECK (courriel IS NULL OR courriel LIKE '%@%')
);

COMMENT ON TABLE  etudiant IS 'Table de demonstration pour le cours 3GB';
COMMENT ON COLUMN etudiant.matricule IS 'Matricule collegial, unique';

INSERT INTO etudiant (matricule, nom, prenom, courriel, programme)
VALUES ('2400101', 'Tremblay', 'Alexis', 'a.tremblay@exemple.ca', 'Techniques de l''informatique');

INSERT INTO etudiant (matricule, nom, prenom, courriel, programme)
VALUES ('2400102', 'Nguyen', 'Mai', 'm.nguyen@exemple.ca', 'Techniques de l''informatique');

INSERT INTO etudiant (matricule, nom, prenom, courriel, programme)
VALUES ('2400103', 'Diallo', 'Amadou', 'a.diallo@exemple.ca', 'Techniques de l''informatique');

COMMIT;

SELECT COUNT(*) AS nb_etudiants FROM etudiant;

EXIT;
