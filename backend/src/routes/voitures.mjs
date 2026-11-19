// =====================================================================
// routes/voitures.mjs - GABARIT : verbe HTTP + URL -> controleur
//
// Pour l'activer, une fois voitures_tapi cree dans la base, ajouter
// dans server.js :
//   import voituresRouter from "./routes/voitures.mjs";
//   app.use("/api/voitures", voituresRouter);
//
//   GET    /api/voitures      -> getVoitures()
//   GET    /api/voitures/5    -> getVoitures(5)
//   POST   /api/voitures      -> insertVoiture(body)
//   PUT    /api/voitures/5    -> updateVoiture(5, body)
//   PUT    /api/voitures      -> 400 : id requis
//   DELETE /api/voitures/5    -> deleteVoiture(5)
// =====================================================================

import { Router } from "express";
import * as ctrl from "../controllers/voitures.mjs";

const router = Router();

router.get("/",       ctrl.lireVoitures);
router.get("/:id",    ctrl.lireVoitures);
router.post("/",      ctrl.creerVoiture);
router.put("/:id",    ctrl.modifierVoiture);
router.put("/",       ctrl.modifierVoiture);
router.delete("/:id", ctrl.supprimerVoiture);

export default router;
