// =====================================================================
// models/cours.mjs - acces aux donnees des cours (couche « modele »)
//
// Ne connait PAS HTTP : ni req, ni res, ni code de statut. Chaque
// fonction appelle cours_tapi et retourne le document JSON:API qu'elle
// produit. Les cas d'erreur sont lances (throw) par appelerTapi().
// =====================================================================

import { appelerTapi } from "../lib/tapi.mjs";

/**
 * Recupere un cours par son ID, ou tous les cours si l'ID est absent.
 * @param {number} [idCours] - undefined pour GET /api/cours
 */
export function getCours(idCours) {
  return appelerTapi(
    `BEGIN :reto := cours_tapi.get_cours(:id_cours); END;`,
    // null : cours_tapi.get_cours retourne tous les cours
    { id_cours: idCours ?? null }
  );
}

/**
 * Insere un nouveau cours.
 * @param {Object} cours - { NOM_COURS, DESCRIPTION_COURS, CREDIT }
 */
export function insertCours(cours) {
  return appelerTapi(
    `BEGIN
       :reto := cours_tapi.ins_cours(:credit, :nom_cours, :description_cours, :test);
     END;`,
    {
      nom_cours: cours.NOM_COURS,
      description_cours: cours.DESCRIPTION_COURS,
      credit: cours.CREDIT,
      test: "N",
    },
    { commit: true }
  );
}

/**
 * Met a jour un cours (les attributs absents restent inchanges).
 * @param {number} idCours - ID du cours a modifier
 * @param {Object} cours   - { NOM_COURS, DESCRIPTION_COURS, CREDIT }
 */
export function updateCours(idCours, cours) {
  return appelerTapi(
    `BEGIN
       :reto := cours_tapi.upd_cours(:credit, :id_cours, :nom_cours, :description_cours, :test);
     END;`,
    {
      id_cours: idCours,
      nom_cours: cours.NOM_COURS,
      description_cours: cours.DESCRIPTION_COURS,
      credit: cours.CREDIT,
      test: "N",
    },
    { commit: true }
  );
}

/**
 * Supprime un cours.
 * @param {number} idCours - ID du cours a supprimer
 */
export function deleteCours(idCours) {
  return appelerTapi(
    `BEGIN :reto := cours_tapi.del_cours(:id_cours, :test); END;`,
    { id_cours: idCours, test: "N" },
    { commit: true }
  );
}
