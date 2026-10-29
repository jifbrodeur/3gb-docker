// =====================================================================
// server.js - API REST v5 du cours 3GB (Express)
//
// Conversion de serveur-APIv4.js (module http natif) vers Express.
// Toutes les routes sont prefixees par /api : c'est ce prefixe que
// nginx relaie vers ce conteneur (voir nginx/default.conf).
//
//   serveur-APIv4 (http)              Express (v5)
//   url.parse() + switch           -> app.use("/api/cours", coursRouter)
//   extractBody(req)               -> express.json() -> req.body
//   setCORSHeaders() + OPTIONS     -> app.use(cors())
//   default : route invalide       -> middleware 404 en fin de chaine
//   try/catch dans chaque fonction -> un middleware d'erreur unique
// =====================================================================

import express from "express";
import cors from "cors";
import logger from "./logger.mjs"; // copie de serveur-APIv4
import { initPool, query, closePool, oracledb } from "./db.js";
import coursRouter from "./routes/cours.mjs";

const app = express();
const port = Number(process.env.PORT) || 3010;

// L'ordre compte : Express execute les app.use() de haut en bas.
app.use(cors());          // remplace setCORSHeaders
app.use(express.json());  // remplace extractBody

// Trace de chaque requete : visible dans « docker compose logs -f api »
app.use((req, res, next) => {
  logger.log("info", `${req.method} ${req.originalUrl}`);
  next(); // passe au suivant
});

// ---------------------------------------------------------------------
// Cours : routeur et controleur (routes/cours.mjs, controllers/cours.mjs)
// ---------------------------------------------------------------------
app.use("/api/cours", coursRouter);

// ---------------------------------------------------------------------
// Sante : confirme que l'API vit ET qu'elle parle a Oracle
// (conservee : la page de validation de 3gb-docker s'en sert)
// ---------------------------------------------------------------------
app.get("/api/sante", async (req, res) => {
  try {
    const r = await query(
      `SELECT SYSTIMESTAMP AS maintenant,
              SYS_CONTEXT('USERENV','DB_NAME')  AS base,
              SYS_CONTEXT('USERENV','CON_NAME') AS pdb,
              USER                              AS usager
         FROM dual`
    );
    res.json({ statut: "ok", oracle: r.rows[0] });
  } catch (err) {
    res.status(503).json({ statut: "erreur", message: err.message });
  }
});

// ---------------------------------------------------------------------
// Etudiants (conservee : la page de validation de 3gb-docker s'en sert)
// Express 5 : une promesse rejetee va seule au middleware d'erreur,
// d'ou l'absence de try/catch.
// ---------------------------------------------------------------------
app.get("/api/etudiants", async (req, res) => {
  const r = await query(
    `SELECT id, matricule, nom, prenom, courriel, programme
       FROM etudiant
      ORDER BY nom, prenom`
  );
  res.json(r.rows);
});

app.get("/api/etudiants/:id", async (req, res) => {
  const r = await query(
    `SELECT id, matricule, nom, prenom, courriel, programme
       FROM etudiant
      WHERE id = :id`,
    { id: Number(req.params.id) }
  );
  if (r.rows.length === 0) {
    return res.status(404).json({ erreur: "Etudiant introuvable" });
  }
  res.json(r.rows[0]);
});

app.post("/api/etudiants", async (req, res, next) => {
  const { matricule, nom, prenom, courriel, programme } = req.body ?? {};
  if (!matricule || !nom || !prenom) {
    return res.status(400).json({ erreur: "matricule, nom et prenom sont obligatoires" });
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
// 404 : atteint seulement si aucune route n'a repondu
// ---------------------------------------------------------------------
app.use((req, res) => {
  logger.log("error", `Route invalide : ${req.method} ${req.originalUrl}`);
  res.status(404).json({ status: "error",
    statusCode: 404, message: "la route est invalide" });
});

// ---------------------------------------------------------------------
// Erreurs : Express reconnait ce middleware a ses 4 parametres
// ---------------------------------------------------------------------
app.use((err, req, res, next) => {
  logger.log("error", err.stack ?? err);
  const code = err.status ?? 500; // 400 : JSON invalide (express.json)
  res.status(code).json({ status: "error",
    statusCode: code,
    message: code === 500
      ? "Erreur interne du serveur" : err.message });
});

// ---------------------------------------------------------------------
// Demarrage : le pool Oracle d'abord, puis l'ecoute sur 0.0.0.0
// (127.0.0.1 refuserait nginx et Postman, qui sont hors du conteneur)
// ---------------------------------------------------------------------
await initPool();
const serveur = app.listen(port, "0.0.0.0", () => {
  logger.log("info", `API sur le port ${port}`);
});

// Arret propre sur « docker compose down » / Ctrl-C
for (const signal of ["SIGTERM", "SIGINT"]) {
  process.on(signal, async () => {
    logger.log("info", `${signal} recu, arret en cours...`);
    serveur.close();
    await closePool();
    process.exit(0);
  });
}
