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
const format = winston.format.combine(
  // Ajouter l'horodatage du message avec le format préféré
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss:ms" }),
  // Dire à Winston que les logs doivent être colorés
  winston.format.colorize({ all: true }),
  // Définir le format du message affichant l'horodatage, le niveau et le message
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`
  )
);
//Dire à winston que vous voulez lier les couleurs
//définies ci-dessus aux niveaux de sévérité.
winston.addColors(colors);
const logger = winston.createLogger({
  level: "debug",
  format, //:winston.format.json(),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({
      filename: "logs/serveur.log",
    }),
  ],
});
export default logger;
