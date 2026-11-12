import winston from "winston";
// Définir des couleurs différentes pour chaque niveau.
// Les couleurs rendent le message de log plus visible,
// ajoutant la possibilité de se concentrer sur ou d'ignorer les messages.
const colors = {
  error: "red",
  warn: "yellow",
  info: "green",
  http: "magenta",
  debug: "white",
};
//Choisissez l'aspect de votre log en personnalisant le format de log.
// Ajouter l'horodatage du message avec le format préféré
const horodatage = winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss:ms" });
// Définir le format du message affichant l'horodatage, le niveau et le message
const ligne = winston.format.printf(
  (info) => `${info.timestamp} ${info.level}: ${info.message}`
);
// Console (docker compose logs) : en couleurs
const format = winston.format.combine(
  horodatage,
  winston.format.colorize({ all: true }),
  ligne
);
// Fichier (backend/logs/serveur.log sur le poste) : SANS couleurs, sinon
// le fichier est truffé de codes comme [32m illisibles dans un éditeur.
const formatFichier = winston.format.combine(horodatage, ligne);
//Dire à winston que vous voulez lier les couleurs
//définies ci-dessus aux niveaux de sévérité.
winston.addColors(colors);
const logger = winston.createLogger({
  level: "debug",
  // Chaque transport a SON format : un format place ici, au niveau du
  // logger, s'appliquerait avant et colorerait aussi le fichier.
  transports: [
    new winston.transports.Console({ format }),
    new winston.transports.File({
      filename: "logs/serveur.log",
      format: formatFichier,
    }),
  ],
});
export default logger;
