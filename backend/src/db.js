// =====================================================================
// db.js - pool de connexions Oracle (node-oracledb, mode Thin)
//
// Mode Thin : depuis la version 6, node-oracledb parle directement le
// protocole Oracle Net en JavaScript. Aucun Instant Client, aucune
// variable LD_LIBRARY_PATH, aucun probleme d'architecture.
// =====================================================================

import oracledb from 'oracledb';

// Les lignes sont retournees comme des objets { NOM: valeur } plutot
// que comme des tableaux : indispensable pour produire du JSON.
oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

// Les colonnes CLOB/BLOB sont retournees directement en string/Buffer
// plutot qu'en flux : plus simple pour un cours d'introduction.
oracledb.fetchAsString = [oracledb.CLOB];

const config = {
  user:          process.env.DB_USER,
  password:      process.env.DB_PASSWORD,
  // « oracle-db » est le NOM DU SERVICE Docker, pas localhost.
  // localhost, vu de l'interieur du conteneur, designerait le
  // conteneur lui-meme.
  connectString: process.env.DB_CONNECT_STRING,
  poolMin:       2,
  poolMax:       10,
  poolIncrement: 1,
  poolAlias:     'default',
};

/**
 * Ouvre le pool de connexions, avec quelques tentatives.
 * Meme avec depends_on/service_healthy, il arrive qu'Oracle accepte les
 * connexions quelques secondes apres avoir ete declare « healthy ».
 */
export async function initPool(tentatives = 10, delaiMs = 5000) {
  for (let i = 1; i <= tentatives; i++) {
    try {
      await oracledb.createPool(config);
      console.log(`[db] Pool ouvert sur ${config.connectString} (usager ${config.user})`);
      return;
    } catch (err) {
      console.warn(`[db] Tentative ${i}/${tentatives} echouee : ${err.message}`);
      if (i === tentatives) throw err;
      await new Promise((r) => setTimeout(r, delaiMs));
    }
  }
}

/**
 * Execute une requete et libere la connexion, quoi qu'il arrive.
 * Les liaisons (binds) sont OBLIGATOIRES : jamais de concatenation de
 * chaines dans du SQL.
 */
export async function query(sql, binds = {}, options = {}) {
  let connexion;
  try {
    connexion = await oracledb.getConnection('default');
    return await connexion.execute(sql, binds, { autoCommit: true, ...options });
  } finally {
    if (connexion) {
      try {
        await connexion.close();
      } catch (err) {
        console.error('[db] Fermeture de connexion impossible :', err.message);
      }
    }
  }
}

/** Fermeture propre du pool a l'arret du conteneur. */
export async function closePool() {
  try {
    await oracledb.getPool('default').close(10);
    console.log('[db] Pool ferme.');
  } catch (err) {
    console.error('[db] Fermeture du pool impossible :', err.message);
  }
}

export { oracledb };
