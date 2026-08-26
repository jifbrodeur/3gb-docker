// =====================================================================
// server.js - API REST de demonstration du cours 3GB
//
// Toutes les routes sont prefixees par /api : c'est ce prefixe que
// nginx relaie vers ce conteneur (voir nginx/default.conf).
// =====================================================================

import express from 'express';
import { initPool, query, closePool, oracledb } from './db.js';

const app  = express();
const PORT = Number(process.env.PORT) || 3010;

app.use(express.json());

// Trace de chaque requete : l'etudiant voit dans « docker compose logs
// -f api » que son clic dans le navigateur atteint bien Node.
app.use((req, _res, next) => {
  console.log(`[api] ${req.method} ${req.originalUrl}`);
  next();
});

// ---------------------------------------------------------------------
// Sante : confirme que l'API vit ET qu'elle parle a Oracle
// ---------------------------------------------------------------------
app.get('/api/sante', async (_req, res) => {
  try {
    const r = await query(
      `SELECT SYSTIMESTAMP AS maintenant,
              SYS_CONTEXT('USERENV','DB_NAME')  AS base,
              SYS_CONTEXT('USERENV','CON_NAME') AS pdb,
              USER                              AS usager
         FROM dual`
    );
    res.json({ statut: 'ok', oracle: r.rows[0] });
  } catch (err) {
    res.status(503).json({ statut: 'erreur', message: err.message });
  }
});

// ---------------------------------------------------------------------
// GET /api/etudiants - liste
// ---------------------------------------------------------------------
app.get('/api/etudiants', async (_req, res, next) => {
  try {
    const r = await query(
      `SELECT id, matricule, nom, prenom, courriel, programme
         FROM etudiant
        ORDER BY nom, prenom`
    );
    res.json(r.rows);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------
// GET /api/etudiants/:id - un seul
// ---------------------------------------------------------------------
app.get('/api/etudiants/:id', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT id, matricule, nom, prenom, courriel, programme
         FROM etudiant
        WHERE id = :id`,
      { id: Number(req.params.id) }
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ erreur: 'Etudiant introuvable' });
    }
    res.json(r.rows[0]);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------
// POST /api/etudiants - creation
// RETURNING ... INTO recupere la cle generee par la colonne IDENTITY.
// ---------------------------------------------------------------------
app.post('/api/etudiants', async (req, res, next) => {
  const { matricule, nom, prenom, courriel, programme } = req.body ?? {};
  if (!matricule || !nom || !prenom) {
    return res.status(400).json({ erreur: 'matricule, nom et prenom sont obligatoires' });
  }
  try {
    const r = await query(
      `INSERT INTO etudiant (matricule, nom, prenom, courriel, programme)
       VALUES (:matricule, :nom, :prenom, :courriel, :programme)
       RETURNING id INTO :id`,
      {
        matricule,
        nom,
        prenom,
        courriel:  courriel  ?? null,
        programme: programme ?? null,
        id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
      }
    );
    res.status(201).json({ id: r.outBinds.id[0], matricule, nom, prenom });
  } catch (err) {
    // ORA-00001 : violation de contrainte unique
    if (err.errorNum === 1) {
      return res.status(409).json({ erreur: `Le matricule ${matricule} existe deja` });
    }
    next(err);
  }
});

// ---------------------------------------------------------------------
// Gestion centralisee des erreurs
// ---------------------------------------------------------------------
app.use((err, _req, res, _next) => {
  console.error('[api] Erreur :', err.message);
  res.status(500).json({ erreur: 'Erreur interne', detail: err.message });
});

// ---------------------------------------------------------------------
// Demarrage
// ---------------------------------------------------------------------
const serveur = await (async () => {
  await initPool();
  return app.listen(PORT, '0.0.0.0', () =>
    console.log(`[api] A l'ecoute sur le port ${PORT}`)
  );
})();

// Arret propre sur « docker compose down » / Ctrl-C
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, async () => {
    console.log(`[api] ${signal} recu, arret en cours...`);
    serveur.close();
    await closePool();
    process.exit(0);
  });
}
