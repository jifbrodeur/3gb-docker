// =====================================================================
// controllers/cours.mjs - lit req, choisit le code HTTP, repond en JSON
//
// Remplace get_cours, ins_cours, upd_cours et del_cours de
// serveur-APIv4. Aucun SQL ici : il reste dans coursDB.mjs.
// Pas de try/catch : Express 5 envoie une promesse rejetee au
// middleware d'erreur de server.js.
// =====================================================================

import logger from "../logger.mjs";
import {
  getCours,
  insertCours,
  updateCours,
  deleteCours,
} from "../coursDB.mjs";

// Meme regle que serveur-APIv4 : le code HTTP vient de la reponse
// construite par coursDB.mjs.
function codeHttp(obj) {
  if (obj?.meta?.statusCode)
    return obj.meta.statusCode;
  if (obj?.errors?.[0]?.status)
    return Number(obj.errors[0].status);
  return 200;
}

function repondre(res, reponse) {
  const code = codeHttp(reponse);
  logger.log("info", `Code HTTP envoyé: ${code}`);
  res.status(code).json(reponse);
}

// GET /api/cours et GET /api/cours/:id
// req.params.id est undefined sur /api/cours : getCours() renvoie la liste.
export async function lireCours(req, res) {
  repondre(res, await getCours(req.params.id));
}

// POST /api/cours : req.body est deja converti par express.json()
export async function creerCours(req, res) {
  repondre(res, await insertCours(req.body));
}

// PUT /api/cours/:id
export async function modifierCours(req, res) {
  repondre(res, await updateCours(req.params.id, req.body));
}

// DELETE /api/cours/:id
export async function supprimerCours(req, res) {
  repondre(res, await deleteCours(req.params.id));
}
