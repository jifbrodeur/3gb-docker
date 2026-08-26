# =====================================================================
# Image de l'API REST
#
# node-oracledb est utilise en mode THIN : du JavaScript pur, aucun
# Oracle Instant Client a installer. C'est ce qui rend l'image legere
# ET identique sur amd64 (PC Windows) et arm64 (Mac Apple Silicon).
# =====================================================================

FROM node:22-alpine

WORKDIR /app

# Les dependances sont installees DANS L'IMAGE, pas sur le poste de
# l'etudiant. On ne monte donc jamais node_modules depuis l'hote :
# c'est ce qui casse un projet partage entre un Mac ARM et un PC x86.
COPY package.json ./
RUN npm install --omit=dev

# Copie de reference : en developpement, ./backend/src est monte
# par-dessus (voir docker-compose.yml).
COPY src ./src

EXPOSE 3010

# --watch est integre a Node 22 : le serveur redemarre tout seul quand
# l'etudiant sauvegarde un fichier. Aucun nodemon a installer.
CMD ["node", "--watch", "src/server.js"]
