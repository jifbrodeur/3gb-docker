// v5 : le pool de db.js (oracle-db:1521/FREEPDB1) remplace dbconfig.mjs
import { oracledb } from "./db.js";
import logger from "./logger.mjs";

/**
 * Récupère un cours par son ID, ou tous les cours si l'ID est absent.
 * @param {number} [p_id_cours] - ID du cours ; undefined pour GET /api/cours.
 * @returns {Object} - Détails du cours (objet JS, pas stringifié).
 */
export async function getCours(p_id_cours) {
  let connection;
  try {
    connection = await oracledb.getConnection("default");
    logger.log("info", "Connexion réussie à la base de données Oracle");

    const result = await connection.execute(
      `BEGIN
         :reto := cours_tapi.get_cours(:id_cours);
       END;`,
      {
        reto: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4000 },
        // null : cours_tapi.get_cours retourne tous les cours
        id_cours: p_id_cours ?? null,
      }
    );

    let retour;
    try {
      retour = JSON.parse(result.outBinds.reto);
    } catch (e) {
      return {
        errors: [{
          status: "500",
          title: "Erreur de parsing",
          detail: "La réponse Oracle n'est pas un JSON valide.",
          code: "-998",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }

    // Format JSON:API attendu
    if (retour.data && retour.meta) {
      return retour;
    }
    if (retour.errors && Array.isArray(retour.errors)) {
      return { errors: retour.errors };
    }
    // Sinon, erreur inconnue
    return {
      errors: [{
        status: "500",
        title: "Format de réponse inattendu",
        detail: JSON.stringify(retour),
        code: "-997",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } catch (err) {
    logger.log("error", err);
    logger.log("error", "errorNum" + err.errorNum);
    if (err.errorNum == 20001) {
      return {
        errors: [{
          status: "404",
          title: "Cours non trouvé",
          detail: "Aucun cours trouvé pour cette recherche",
          code: "-2",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    return {
      errors: [{
        status: "500",
        title: "Erreur serveur",
        detail: "Erreur non attrapée dans le catch",
        code: "-999",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (err) {
        logger.error(err);
      }
    }
  }
}

/**
 * Met à jour les informations d'un cours.
 * @param {number} p_id_cours - ID du cours à mettre à jour.
 * @param {Object} cours - Objet contenant les informations du cours.
 * @returns {string} - Résultat de la mise à jour en JSON.
 */
export async function updateCours(p_id_cours, cours) {
  if (!p_id_cours || !cours) {
    return {
      errors: [{
        status: "404",
        title: "Paramètres invalides",
        detail: "id null lors de la maj du cours",
        code: "-1",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  }

  let connection;
  try {
    connection = await oracledb.getConnection("default");
    logger.log("info", "Connexion réussie à la base de données Oracle");

    const result = await connection.execute(
      `BEGIN
         :reto := cours_tapi.upd_cours(:credit, :id_cours, :nom_cours, :description_cours, :test);
       END;`,
      {
        reto: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4000 },
        id_cours: p_id_cours,
        nom_cours: cours.NOM_COURS,
        description_cours: cours.DESCRIPTION_COURS,
        credit: cours.CREDIT,
        test: "N",
      }
    );

    await connection.commit();
    let retour;
    try {
      retour = JSON.parse(result.outBinds.reto);
    } catch (e) {
      return {
        errors: [{
          status: "500",
          title: "Erreur de parsing",
          detail: "La réponse Oracle n'est pas un JSON valide.",
          code: "-998",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    if (retour.data && retour.meta) {
      return retour;
    }
    if (retour.errors && Array.isArray(retour.errors)) {
      return { errors: retour.errors };
    }
    return {
      errors: [{
        status: "500",
        title: "Format de réponse inattendu",
        detail: JSON.stringify(retour),
        code: "-997",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } catch (err) {
    logger.log("error", err);
    if (err.errorNum === 1403) {
      return {
        errors: [{
          status: "404",
          title: "ID de cours inexistant.",
          detail: "Aucun cours trouvé pour cet id_cours!",
          code: "-1403",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    return {
      errors: [{
        status: "500",
        title: "Erreur serveur",
        detail: "Erreur non attrapée dans le catch",
        code: "-999",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (err) {
        logger.error(err);
      }
    }
  }
}

/**
 * Insère un nouveau cours dans la base de données.
 * @param {Object} cours - Objet contenant les informations du cours.
 * @returns {string} - Résultat de l'insertion en JSON.
 */
export async function insertCours(cours) {
  if (!cours) {
    return {
      errors: [{
        status: "400",
        title: "Paramètre cours invalide",
        detail: "Le paramètre cours est invalide.",
        code: "-1",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  }

  let connection;
  try {
    connection = await oracledb.getConnection("default");
    logger.log("info", "Connexion réussie à la base de données Oracle");

    const result = await connection.execute(
      `BEGIN
         :reto := cours_tapi.ins_cours(:credit, :nom_cours, :description_cours, :test);
       END;`,
      {
        reto: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4000 },
        nom_cours: cours.NOM_COURS,
        description_cours: cours.DESCRIPTION_COURS,
        credit: cours.CREDIT,
        test: "N",
      }
    );

    await connection.commit();
    logger.log("info", "Cours inséré avec succès.");
    logger.log("info", result.outBinds.reto);
    let retour;
    try {
      retour = JSON.parse(result.outBinds.reto);
    } catch (e) {
      return {
        errors: [{
          status: "500",
          title: "Erreur de parsing",
          detail: "La réponse Oracle n'est pas un JSON valide.",
          code: "-998",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    if (retour.data && retour.meta) {
      // Pour une création, statusCode 201
      retour.meta = retour.meta || {};
      retour.meta.status = "success";
      retour.meta.statusCode = 201;
      return retour;
    }
    if (retour.errors && Array.isArray(retour.errors)) {
      return { errors: retour.errors };
    }
    return {
      errors: [{
        status: "500",
        title: "Format de réponse inattendu",
        detail: JSON.stringify(retour),
        code: "-997",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } catch (err) {
    logger.log("error", err);
    return {
      errors: [{
        status: "500",
        title: "Erreur serveur",
        detail: "Erreur non attrapée dans le catch",
        code: "-9999",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (err) {
        logger.error(err);
      }
    }
  }
}

/**
 * Supprime un cours par son ID.
 * @param {number} p_id_cours - ID du cours à supprimer.
 * @returns {string} - Résultat de la suppression en JSON.
 */
export async function deleteCours(p_id_cours) {
  if (!p_id_cours) {
    return {
      errors: [{
        status: "400",
        title: "Paramètre manquant",
        detail: "Le paramètre p_id_cours est requis.",
        code: "-1",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  }

  let connection;
  try {
    connection = await oracledb.getConnection("default");
    logger.log("info", "Connexion réussie à la base de données Oracle");

    const result = await connection.execute(
      `BEGIN
         :reto := cours_tapi.del_cours(:id_cours, :test);
       END;`,
      {
        reto: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4000 },
        id_cours: p_id_cours,
        test: "N",
      }
    );

    let retour;
    try {
      retour = JSON.parse(result.outBinds.reto);
    } catch (e) {
      return {
        errors: [{
          status: "500",
          title: "Erreur de parsing",
          detail: "La réponse Oracle n'est pas un JSON valide.",
          code: "-998",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    if (retour.data && retour.meta) {
      return retour;
    }
    if (retour.errors && Array.isArray(retour.errors)) {
      return { errors: retour.errors };
    }
    return {
      errors: [{
        status: "500",
        title: "Format de réponse inattendu",
        detail: JSON.stringify(retour),
        code: "-997",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } catch (err) {
    logger.log("error", err);
    // Gestion Oracle : 20001 ou 1403 = id inexistant => 404
    if (err.errorNum === 20001 || err.errorNum === 1403) {
      return {
        errors: [{
          status: "404",
          title: "Cours non trouvé",
          detail: "Aucun cours trouvé pour cette suppression",
          code: "-2",
          meta: { timestamp: new Date().toISOString() }
        }]
      };
    }
    return {
      errors: [{
        status: "500",
        title: "Erreur serveur",
        detail: "Erreur non attrapée dans le catch",
        code: "-999",
        meta: { timestamp: new Date().toISOString() }
      }]
    };
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (err) {
        logger.error(err);
      }
    }
  }
}
