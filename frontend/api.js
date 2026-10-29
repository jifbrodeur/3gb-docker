// Module API : fonctions pour interagir avec l'API REST
// v5 : la page est servie par nginx (http://localhost:8080), qui relaie
// /api/ vers le conteneur api. Meme origine : aucune adresse ni port ici.
const HOST = "/api";

// Sans Content-Type: application/json, express.json() ignore le corps
// et req.body reste undefined.
const ENTETES_JSON = { Accept: "application/json", "Content-Type": "application/json" };

export async function rechercherCours(id_cours) {
  const response = await fetch(`${HOST}/cours/${id_cours}`);
  if (!response.ok) throw response;
  return response.json();
}

export async function insererCours(courseData) {
  const response = await fetch(`${HOST}/cours`, {
    method: "POST",
    headers: ENTETES_JSON,
    body: JSON.stringify(courseData),
    redirect: "follow",
  });
  if (!response.ok) throw response;
  return response.json();
}

export async function modifierCours(id_cours, courseData) {
  const response = await fetch(`${HOST}/cours/${id_cours}`, {
    method: "PUT",
    headers: ENTETES_JSON,
    body: JSON.stringify(courseData),
    redirect: "follow",
  });
  if (!response.ok) throw response;
  return response.json();
}

export async function supprimerCours(id_cours) {
  const response = await fetch(`${HOST}/cours/${id_cours}`, {
    method: "DELETE",
    headers: { Accept: "application/json" },
    redirect: "follow",
  });
  if (!response.ok) throw response;
  return response;
}
