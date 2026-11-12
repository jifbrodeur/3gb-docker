# =====================================================================
# Image de l'API REST
#
# node-oracledb est utilise en mode THIN : du JavaScript pur, aucun
# Oracle Instant Client a installer. C'est ce qui rend l'image legere
# ET identique sur amd64 (PC Windows) et arm64 (Mac Apple Silicon).
# =====================================================================

FROM node:24.22.3-alpine

WORKDIR /app

# Les dependances sont installees DANS L'IMAGE, pas sur le poste de
# l'etudiant. On ne monte donc jamais node_modules depuis l'hote :
# c'est ce qui casse un projet partage entre un Mac ARM et un PC x86.
#
# npm ci installe EXACTEMENT les versions de package-lock.json : tous les
# etudiants obtiennent les memes dependances, peu importe le jour du build.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copie de reference. En developpement, « docker compose watch »
# synchronise ensuite ./backend/src dans ce dossier (voir develop.watch
# dans docker-compose.yml).
COPY src ./src

EXPOSE 3010

# --watch est integre a Node : le serveur redemarre tout seul quand un
# fichier de src/ change DANS le conteneur. Aucun nodemon a installer.
# --watch-path=src surveille le DOSSIER, pas chaque fichier : la synchro
# de « docker compose watch » remplace les fichiers (nouvel inode), et un
# simple --watch, qui suit l'ancien fichier, ne verrait rien.
CMD ["node", "--watch-path=src", "src/server.js"]
