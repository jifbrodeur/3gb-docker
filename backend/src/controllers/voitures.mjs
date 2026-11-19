// =====================================================================
// controllers/voitures.mjs - GABARIT : lit req, valide, choisit le code HTTP
//
// Aucun SQL ici : il reste dans models/voitures.mjs.
// Pas de try/catch : Express 5 envoie une promesse rejetee (ou une
// ErreurApi lancee) au middleware d'erreur de server.js.
// =====================================================================

import logger from "../lib/logger.mjs";
import { ErreurApi } from "../lib/erreurs.mjs";
import {
  getVoitures,
  insertVoiture,
  updateVoiture,
  deleteVoiture,
} from "../models/voitures.mjs";

// Le code HTTP vient du document JSON:API retourne par voitures_tapi :
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

// /api/voitures/abc : 400 plutot qu'une erreur Oracle (ORA-06502 -> 500)
function idValide(id) {
  if (!/^\d+$/.test(id ?? "")) {
    throw new ErreurApi(400, "Paramètres invalides",
      "L'id de la voiture doit être un entier positif.", "-1");
  }
  return Number(id);
}

function corpsValide(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new ErreurApi(400, "Paramètre voiture invalide",
      "Le corps de la requête doit être un objet JSON.", "-1");
  }
  return body;
}

// GET /api/voitures et GET /api/voitures/:id
// req.params.id est undefined sur /api/voitures : getVoitures() renvoie la liste.
export async function lireVoitures(req, res) {
  const id = req.params.id === undefined ? undefined : idValide(req.params.id);
  repondre(res, await getVoitures(id));
}

// POST /api/voitures : req.body est deja converti par express.json()
export async function creerVoiture(req, res) {
  repondre(res, await insertVoiture(corpsValide(req.body)), 201);
}

// PUT /api/voitures/:id (et PUT /api/voitures, sans id : 400)
export async function modifierVoiture(req, res) {
  const id = idValide(req.params.id);
  repondre(res, await updateVoiture(id, corpsValide(req.body)));
}

// DELETE /api/voitures/:id
export async function supprimerVoiture(req, res) {
  repondre(res, await deleteVoiture(idValide(req.params.id)));
}
