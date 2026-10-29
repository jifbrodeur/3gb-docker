// Module UI : fonctions pour manipuler le DOM et afficher des messages

export function afficherMessageAvecCompteARebours(messagesDiv, message, temps, estErreur = false, initialiserFormulaire) {
  messagesDiv.style.color = estErreur ? "red" : "green";
  let compteur = temps;
  const intervalID = setInterval(function () {
    messagesDiv.textContent = message + " " + compteur + "..";
    compteur--;
    if (compteur < 0) {
      clearInterval(intervalID);
      messagesDiv.textContent = "";
      if (!estErreur && typeof initialiserFormulaire === "function") {
        initialiserFormulaire();
      }
    }
  }, 1000);
}

export function afficherErreur(erreurCREDIT, message) {
  erreurCREDIT.textContent = message;
}

export function afficherConfirmationDialog(dialog) {
  dialog.showModal();
}

export function cacherConfirmationDialog(dialog) {
  dialog.close();
}

export function initialiserChamps(formElements) {
  // Ne pas vider ID_COURS ici car il est dans la section recherche
  formElements.NOM_COURS.value = "";
  formElements.DESCRIPTION_COURS.value = "";
  formElements.CREDIT.value = "";
}

export function activerChamps(formElements) {
  formElements.NOM_COURS.disabled = false;
  formElements.DESCRIPTION_COURS.disabled = false;
  formElements.CREDIT.disabled = false;
}

export function desactiverChamps(formElements) {
  formElements.NOM_COURS.disabled = true;
  formElements.DESCRIPTION_COURS.disabled = true;
  formElements.CREDIT.disabled = true;
}
