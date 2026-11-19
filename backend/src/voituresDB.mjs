// =====================================================================
// voituresDB.mjs - GABARIT : acces aux donnees des voitures
//
// A COMPLETER : ce fichier suppose une table VOITURE et un paquetage
// voitures_tapi qui suivent le meme contrat que cours_tapi (chaque
// fonction retourne un VARCHAR2 au format JSON:API). Ni l'une ni
// l'autre n'existent encore dans la base.
//
// Comme coursDB.mjs, ce fichier ne connait PAS HTTP.
// =====================================================================

import { appelerTapi } from "./tapi.mjs";

/**
 * Recupere une voiture par son ID, ou toutes les voitures si l'ID est absent.
 * @param {number} [idVoiture] - undefined pour GET /api/voitures
 */
export function getVoitures(idVoiture) {
  return appelerTapi(
    `BEGIN :reto := voitures_tapi.get_voitures(:id_voiture); END;`,
    { id_voiture: idVoiture ?? null }
  );
}

/**
 * Insere une nouvelle voiture.
 * @param {Object} voiture - A COMPLETER : { MARQUE, MODELE, ANNEE }
 */
export function insertVoiture(voiture) {
  return appelerTapi(
    `BEGIN
       :reto := voitures_tapi.ins_voiture(:marque, :modele, :annee, :test);
     END;`,
    {
      marque: voiture.MARQUE,
      modele: voiture.MODELE,
      annee: voiture.ANNEE,
      test: "N",
    },
    { commit: true }
  );
}

/**
 * Met a jour une voiture.
 * @param {number} idVoiture - ID de la voiture a modifier
 * @param {Object} voiture   - A COMPLETER : { MARQUE, MODELE, ANNEE }
 */
export function updateVoiture(idVoiture, voiture) {
  return appelerTapi(
    `BEGIN
       :reto := voitures_tapi.upd_voiture(:id_voiture, :marque, :modele, :annee, :test);
     END;`,
    {
      id_voiture: idVoiture,
      marque: voiture.MARQUE,
      modele: voiture.MODELE,
      annee: voiture.ANNEE,
      test: "N",
    },
    { commit: true }
  );
}

/**
 * Supprime une voiture.
 * @param {number} idVoiture - ID de la voiture a supprimer
 */
export function deleteVoiture(idVoiture) {
  return appelerTapi(
    `BEGIN :reto := voitures_tapi.del_voiture(:id_voiture, :test); END;`,
    { id_voiture: idVoiture, test: "N" },
    { commit: true }
  );
}
