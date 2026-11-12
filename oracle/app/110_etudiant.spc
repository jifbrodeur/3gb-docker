CREATE OR REPLACE PACKAGE etudiant_api IS
    FUNCTION afficher (p_id_etudiant NUMBER) RETURN VARCHAR2;
    FUNCTION effacer (p_id_etudiant NUMBER) RETURN VARCHAR2;
END etudiant_api;