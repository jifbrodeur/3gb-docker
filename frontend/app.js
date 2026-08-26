// =====================================================================
// app.js - frontend de validation
//
// Noter l'URL : « /api/... », en chemin RELATIF. Pas de
// http://localhost:3010. C'est nginx qui relaie, donc le navigateur
// reste sur une seule origine et la question du CORS ne se pose pas.
// =====================================================================

const API = '/api';

// --- 1. Etat de la chaine --------------------------------------------
document.getElementById('btn-sante').addEventListener('click', async () => {
  const sortie = document.getElementById('sortie-sante');
  sortie.textContent = 'Appel en cours...';
  try {
    const reponse = await fetch(`${API}/sante`);
    const donnees = await reponse.json();
    sortie.textContent = JSON.stringify(donnees, null, 2);
    sortie.className = reponse.ok ? 'ok' : 'erreur';
  } catch (err) {
    sortie.textContent = `Echec de l'appel : ${err.message}`;
    sortie.className = 'erreur';
  }
});

// --- 2. Lecture -------------------------------------------------------
document.getElementById('btn-liste').addEventListener('click', chargerEtudiants);

async function chargerEtudiants() {
  const corps = document.querySelector('#table-etudiants tbody');
  corps.innerHTML = '<tr><td colspan="5">Chargement...</td></tr>';
  try {
    const reponse = await fetch(`${API}/etudiants`);
    if (!reponse.ok) throw new Error(`HTTP ${reponse.status}`);
    const etudiants = await reponse.json();
    corps.innerHTML = etudiants
      .map(
        (e) => `<tr>
          <td>${e.ID}</td>
          <td>${e.MATRICULE}</td>
          <td>${e.NOM}</td>
          <td>${e.PRENOM}</td>
          <td>${e.COURRIEL ?? ''}</td>
        </tr>`
      )
      .join('');
  } catch (err) {
    corps.innerHTML = `<tr><td colspan="5" class="erreur">${err.message}</td></tr>`;
  }
}

// --- 3. Ecriture ------------------------------------------------------
document.getElementById('form-etudiant').addEventListener('submit', async (evt) => {
  evt.preventDefault();
  const sortie = document.getElementById('sortie-post');
  const donnees = Object.fromEntries(new FormData(evt.target).entries());

  try {
    const reponse = await fetch(`${API}/etudiants`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(donnees),
    });
    const resultat = await reponse.json();
    sortie.textContent = `HTTP ${reponse.status}\n${JSON.stringify(resultat, null, 2)}`;
    sortie.className = reponse.ok ? 'ok' : 'erreur';
    if (reponse.ok) {
      evt.target.reset();
      chargerEtudiants();
    }
  } catch (err) {
    sortie.textContent = `Echec de l'appel : ${err.message}`;
    sortie.className = 'erreur';
  }
});
