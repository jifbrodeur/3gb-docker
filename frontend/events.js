// Module Events : gestionnaires d'événements
import { rechercherCours, insererCours, modifierCours, supprimerCours } from "./api.js";
import { afficherMessageAvecCompteARebours, afficherErreur, afficherConfirmationDialog, cacherConfirmationDialog, initialiserChamps } from "./ui.js";

export function attacherEvenements(formElements, domRefs) {
  const { searchButton, newButton, saveButton, deleteButton, dialogSupprimer, messagesDiv, erreurCREDIT, CREDITInput } = domRefs;

  // État interne pour savoir si on modifie un cours existant ou si on en crée un nouveau
  let currentId = null;

  // --- Gestion de la Recherche ---
  async function executerRecherche() {
    const id_cours = formElements.ID_COURS.value.trim();
    if (!id_cours) {
      afficherMessageAvecCompteARebours(messagesDiv, "Veuillez entrer un ID", 3, true);
      return;
    }

    try {
      const data_ret = await rechercherCours(id_cours);
      if (data_ret && data_ret.data && data_ret.data.length > 0) {
        const cours = data_ret.data[0];
        const attr = cours.attributes;

        // Remplir le formulaire
        formElements.NOM_COURS.value = attr.nomCours || "";
        formElements.DESCRIPTION_COURS.value = attr.descriptionCours || "";
        formElements.CREDIT.value = attr.credit || "";

        // Mettre à jour l'état
        currentId = id_cours;
        deleteButton.disabled = false; // On peut supprimer un cours existant
        afficherMessageAvecCompteARebours(messagesDiv, "Cours chargé", 2, false);
      } else {
        afficherMessageAvecCompteARebours(messagesDiv, "Cours non trouvé", 3, true);
        currentId = null;
        deleteButton.disabled = true;
      }
    } catch (e) {
      console.error(e);
      afficherMessageAvecCompteARebours(messagesDiv, "Erreur lors de la recherche", 3, true);
      currentId = null;
      deleteButton.disabled = true;
    }
  }

  searchButton.addEventListener("click", executerRecherche);
  formElements.ID_COURS.addEventListener("keydown", function (event) {
    if (event.key === "Enter") {
      executerRecherche();
    }
  });

  // --- Gestion du "Nouveau Cours" ---
  newButton.addEventListener("click", function () {
    initialiserChamps(formElements);
    // On ne vide pas forcément ID_COURS, ou alors si ? 
    // Pour l'UX, c'est mieux de vider l'ID car on va créer un nouveau cours (ID généré ou saisi ?)
    // Si l'ID est généré par la BD, on s'en fiche de l'input ID.
    // Si l'ID doit être saisi (ce qui semble être le cas pour la recherche), est-ce qu'on l'insère ?
    // D'après le code serveur `insertCours`, il ne prend pas d'ID. Donc l'ID est généré.
    // Donc on vide le champ ID pour éviter la confusion.
    formElements.ID_COURS.value = "";

    currentId = null;
    deleteButton.disabled = true;
    formElements.NOM_COURS.focus();
    afficherMessageAvecCompteARebours(messagesDiv, "Prêt pour la création", 2, false);
  });

  // --- Gestion de l'Enregistrement (Create / Update) ---
  saveButton.addEventListener("click", async function () {
    const saisieCREDIT = CREDITInput.value;
    if (isNaN(saisieCREDIT) || saisieCREDIT === "") {
      afficherErreur(erreurCREDIT, "Veuillez saisir un nombre valide pour les crédits.");
      return;
    }
    afficherErreur(erreurCREDIT, "");

    const courseData = {
      NOM_COURS: formElements.NOM_COURS.value,
      DESCRIPTION_COURS: formElements.DESCRIPTION_COURS.value,
      CREDIT: formElements.CREDIT.value,
    };

    try {
      if (currentId) {
        // --- MODE UPDATE ---
        await modifierCours(currentId, courseData);
        afficherMessageAvecCompteARebours(messagesDiv, "Cours modifié avec succès", 3, false);
      } else {
        // --- MODE CREATE ---
        const resultat = await insererCours(courseData);
        // Si l'insertion renvoie le nouvel ID, on pourrait passer en mode édition
        // cours_tapi.ins_cours renvoie data sous forme d'objet (get_cours : tableau)
        const cree = Array.isArray(resultat?.data) ? resultat.data[0] : resultat?.data;
        if (cree && cree.id) {
          const newId = cree.id;
          currentId = newId;
          formElements.ID_COURS.value = newId; // Afficher le nouvel ID
          deleteButton.disabled = false;
        }
        afficherMessageAvecCompteARebours(messagesDiv, "Cours créé avec succès", 3, false);
      }
    } catch (e) {
      console.error(e);
      afficherMessageAvecCompteARebours(messagesDiv, "Erreur lors de l'enregistrement", 5, true);
    }
  });

  // --- Gestion de la Suppression ---
  deleteButton.addEventListener("click", function () {
    if (currentId) {
      afficherConfirmationDialog(dialogSupprimer);
    }
  });

  dialogSupprimer.addEventListener("close", async function () {
    if (dialogSupprimer.returnValue === "oui") {
      try {
        await supprimerCours(currentId);
        afficherMessageAvecCompteARebours(messagesDiv, "Cours supprimé", 3, false);
        initialiserChamps(formElements);
        formElements.ID_COURS.value = "";
        currentId = null;
        deleteButton.disabled = true;
      } catch (e) {
        console.error(e);
        afficherMessageAvecCompteARebours(messagesDiv, "Erreur lors de la suppression", 5, true);
      }
    }
  });
}
