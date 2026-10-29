// Fichier principal : point d'entrée
import { attacherEvenements } from "./events.js";

document.addEventListener("DOMContentLoaded", function () {
  // Références aux éléments du DOM
  const formElements = {
    ID_COURS: document.getElementById("ID_COURS"),
    NOM_COURS: document.getElementById("NOM_COURS"),
    DESCRIPTION_COURS: document.getElementById("DESCRIPTION_COURS"),
    CREDIT: document.getElementById("CREDIT"),
  };
  const domRefs = {
    searchButton: document.getElementById("searchButton"),
    newButton: document.getElementById("newButton"), // Remplacé insertButton
    saveButton: document.getElementById("saveButton"),
    deleteButton: document.getElementById("deleteButton"),
    dialogSupprimer: document.getElementById("dialogSupprimer"),
    messagesDiv: document.getElementById("messages"),
    erreurCREDIT: document.getElementById("erreurCREDIT"),
    CREDITInput: document.getElementById("CREDIT"),
  };
  attacherEvenements(formElements, domRefs);
});
