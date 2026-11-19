// =====================================================================
// routes/cours.mjs - associe un verbe HTTP et une URL a une fonction
//
// Le prefixe /api/cours est donne une seule fois, dans server.js.
// Pour /api/cours/5, Express place "5" dans req.params.id.
// Les requetes OPTIONS (pre-vol CORS) sont traitees par cors().
//
//   GET    /api/cours      -> getCours()
//   GET    /api/cours/5    -> getCours(5)
//   POST   /api/cours      -> insertCours(body)
//   PUT    /api/cours/5    -> updateCours(5, body)
//   PUT    /api/cours      -> 400 : id requis
//   DELETE /api/cours/5    -> deleteCours(5)
// =====================================================================

import { Router } from "express";
import * as ctrl from "../controllers/cours.mjs";

const router = Router();

router.get("/",       ctrl.lireCours);
router.get("/:id",    ctrl.lireCours);
router.post("/",      ctrl.creerCours);
router.put("/:id",    ctrl.modifierCours);
// PUT sans id : le controleur repond 400 (id requis)
// au lieu de 404 « route invalide »
router.put("/",       ctrl.modifierCours);
router.delete("/:id", ctrl.supprimerCours);

export default router;
