-- =====================================================================
-- 30_cours.sql
--
-- Table COURS (avec sa sequence, son trigger et 5 cours de depart)
-- utilisee par cours_tapi. Reprise de « Lecon - 13 - Generation API/
-- cours/cours.sql ». Le paquetage est dans 31_cours_tapi.spc et
-- 31_cours_tapi.bdy, a jouer ensuite.
--
-- Execute connecte AVEC LE COMPTE APPLICATIF (pas SYSTEM) :
--   docker compose exec oracle-db sqlplus "app3gb/<APP_USER_PASSWORD>@//localhost:1521/FREEPDB1" "@/sql/30_cours.sql"
--
-- Rejouer ce script remet la table a ses 5 cours de depart. Rejouer
-- ensuite 31_cours_tapi.spc et 31_cours_tapi.bdy, qui sont invalides
-- tant que la table n'existe pas.
-- =====================================================================

SET DEFINE OFF

-- Idempotent : on peut rejouer le script sans erreur.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE cours CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;  -- -942 = table inexistante
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE cours_id_cours_seq';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2289 THEN RAISE; END IF; -- -2289 = sequence inexistante
END;
/

CREATE TABLE cours (
    id_cours          NUMBER,
    nom_cours         VARCHAR2(100) NOT NULL,
    description_cours VARCHAR2(200),
    credit            NUMBER,
    CONSTRAINT pk_cours PRIMARY KEY (id_cours)
);

CREATE SEQUENCE cours_id_cours_seq INCREMENT BY 1 START WITH 30;

CREATE OR REPLACE TRIGGER cours_id_cours_trg
    BEFORE INSERT ON cours FOR EACH ROW WHEN (new.id_cours IS NULL)
BEGIN
    :new.id_cours := cours_id_cours_seq.nextval;
END;
/

INSERT INTO cours (id_cours, nom_cours, description_cours, credit) VALUES (1, 'Informatique', 'Introduction à l''informatique', 3);
INSERT INTO cours (id_cours, nom_cours, description_cours, credit) VALUES (2, 'Mathématiques', 'Algèbre linéaire', 4);
INSERT INTO cours (id_cours, nom_cours, description_cours, credit) VALUES (4, 'Programmation Java', 'Un cours super', 12);
INSERT INTO cours (id_cours, nom_cours, description_cours, credit) VALUES (9, 'Programmation JavaScript', 'Un cours pas pire', 12);
INSERT INTO cours (id_cours, nom_cours, description_cours, credit) VALUES (11, 'Programmation PL/SQL', 'Un cours vraiment super', 12);
COMMIT;

SELECT COUNT(*) AS nb_cours FROM cours;

EXIT;
