// =====================================================================
// controllers/cours.mjs - lit req, valide, choisit le code HTTP
//
// Aucun SQL ici : il reste dans models/cours.mjs.
// Pas de try/catch : Express 5 envoie une promesse rejetee (ou une
// ErreurApi lancee) au middleware d'erreur de server.js.
// =====================================================================

import logger from "../lib/logger.mjs";
import { ErreurApi } from "../lib/erreurs.mjs";
import {
  getCours,
  insertCours,
  updateCours,
  deleteCours,
} from "../models/cours.mjs";

// Le code HTTP vient du document JSON:API retourne par cours_tapi :
// meta.statusCode en cas de succes, errors[0].status sinon.
function codeHttp(doc) {
  if (doc?.meta?.statusCode)
    return Number(doc.meta.statusCode);
  if (doc?.errors?.[0]?.status)
    return Number(doc.errors[0].status);
  return 200;
}

function repondre(res, doc, codeSucces) {
  const code = doc.errors ? codeHttp(doc) : (codeSucces ?? codeHttp(doc));
  logger.log("info", `Code HTTP envoyé: ${code}`);
  res.status(code).json(doc);
}

// /api/cours/abc : 400 plutot qu'une erreur Oracle (ORA-06502 -> 500)
function idValide(id) {
  if (!/^\d+$/.test(id ?? "")) {
    throw new ErreurApi(400, "Paramètres invalides",
      "L'id du cours doit être un entier positif.", "-1");
  }
  return Number(id);
}

function corpsValide(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new ErreurApi(400, "Paramètre cours invalide",
      "Le corps de la requête doit être un objet JSON.", "-1");
  }
  return body;
}

// GET /api/cours et GET /api/cours/:id
// req.params.id est undefined sur /api/cours : getCours() renvoie la liste.
export async function lireCours(req, res) {
  const id = req.params.id === undefined ? undefined : idValide(req.params.id);
  repondre(res, await getCours(id));
}

// POST /api/cours : req.body est deja converti par express.json()
export async function creerCours(req, res) {
  repondre(res, await insertCours(corpsValide(req.body)), 201);
}

// PUT /api/cours/:id (et PUT /api/cours, sans id : 400)
export async function modifierCours(req, res) {
  const id = idValide(req.params.id);
  repondre(res, await updateCours(id, corpsValide(req.body)));
}

// DELETE /api/cours/:id
export async function supprimerCours(req, res) {
  repondre(res, await deleteCours(idValide(req.params.id)));
}
