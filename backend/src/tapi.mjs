// =====================================================================
// tapi.mjs - appel generique d'une fonction TAPI qui retourne du JSON
//
// Toutes les fonctions de cours_tapi suivent le meme contrat :
//   :reto := paquetage.fonction(...)  -> VARCHAR2 au format JSON:API
// Ce helper regroupe ce qui etait repete dans chaque fonction de
// coursDB.mjs : connexion, execute, commit, JSON.parse, verification
// du format et fermeture de la connexion.
// =====================================================================

import { oracledb } from "./db.js";
import logger from "./logger.mjs";
import { ErreurApi } from "./erreurs.mjs";

// 32767 : taille max d'un VARCHAR2 en PL/SQL. Avec 4000, une liste
// complete depasse vite la limite (ORA-06502).
const TAILLE_MAX_RETOUR = 32767;

// Erreurs Oracle qui signifient « la ressource n'existe pas »
//   20001 : RAISE_APPLICATION_ERROR(-20001, ...) d'une TAPI
//    1403 : NO_DATA_FOUND
const ORA_INTROUVABLE = [20001, 1403];

/**
 * Execute un bloc PL/SQL « :reto := ... » et retourne le document
 * JSON:API produit par la TAPI ({ data, meta } ou { errors }).
 *
 * @param {string} plsql - bloc PL/SQL qui affecte :reto
 * @param {Object} binds - liaisons, SANS reto (ajoute ici)
 * @param {Object} [options]
 * @param {boolean} [options.commit=false] - commit apres l'appel
 * @returns {Promise<Object>} document JSON:API (objet JS)
 * @throws {ErreurApi} ressource introuvable, reponse invalide ou erreur Oracle
 */
export async function appelerTapi(plsql, binds, { commit = false } = {}) {
  let connexion;
  let result;
  try {
    connexion = await oracledb.getConnection("default");
    result = await connexion.execute(plsql, {
      reto: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: TAILLE_MAX_RETOUR },
      ...binds,
    });
    if (commit) {
      await connexion.commit();
    }
  } catch (err) {
    logger.log("error", `Erreur Oracle ${err.errorNum ?? ""} : ${err.message}`);
    if (ORA_INTROUVABLE.includes(err.errorNum)) {
      throw new ErreurApi(404, "Ressource non trouvée",
        "Aucune rangée ne correspond à cet identifiant.", "-2");
    }
    throw new ErreurApi(500, "Erreur serveur",
      "Erreur Oracle non traitée par la TAPI.", "-999");
  } finally {
    if (connexion) {
      try {
        await connexion.close();
      } catch (err) {
        logger.log("error", err);
      }
    }
  }

  let retour;
  try {
    retour = JSON.parse(result.outBinds.reto);
  } catch {
    throw new ErreurApi(500, "Erreur de parsing",
      "La réponse Oracle n'est pas un JSON valide.", "-998");
  }

  // Format JSON:API attendu : succes ou erreurs traitees par la TAPI
  if ((retour?.data && retour?.meta) || Array.isArray(retour?.errors)) {
    return retour;
  }
  throw new ErreurApi(500, "Format de réponse inattendu",
    JSON.stringify(retour), "-997");
}
