// =====================================================================
// lib/erreurs.mjs - erreur applicative au format JSON:API
//
// Les couches DB et controleur LANCENT une ErreurApi (throw) au lieu
// de construire elles-memes la reponse. Express 5 transmet l'erreur au
// middleware d'erreur de server.js, qui appelle documentErreur().
// Un seul endroit fabrique donc les erreurs JSON:API.
// =====================================================================

export class ErreurApi extends Error {
  /**
   * @param {number} status - code HTTP (400, 404, 500...)
   * @param {string} title  - resume court de l'erreur
   * @param {string} detail - explication pour le developpeur client
   * @param {string} code   - code applicatif (ex. "-1", "-999")
   */
  constructor(status, title, detail, code) {
    super(detail);
    this.name = "ErreurApi";
    this.status = status;
    this.title = title;
    this.code = code;
  }
}

/** Transforme une ErreurApi en document JSON:API { errors: [...] }. */
export function documentErreur(err) {
  return {
    errors: [{
      status: String(err.status),
      title: err.title,
      detail: err.message,
      code: err.code,
      meta: { timestamp: new Date().toISOString() },
    }],
  };
}
