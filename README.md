# Cours 3GB — Environnement de laboratoire API REST

Trois conteneurs Docker : **Oracle 23ai Free**, une **API Node.js** et **nginx**.
Guide d'installation pour les postes Windows (x86) et Mac (Apple Silicon).

---

## 1. L'architecture en un coup d'œil

```
        POSTE DE L'ÉTUDIANT                    RÉSEAU DOCKER « 3gb-net »
                                     ┌──────────────────────────────────────┐
 Navigateur ──── :8080 ─────────────►│  web (nginx)                         │
                                     │    /        → fichiers statiques     │
                                     │    /api/    → proxy vers api:3010    │
                                     │                    │                 │
 Postman / curl ─ :3010 ────────────►│  api (Node.js + node-oracledb)       │
                                     │                    │                 │
                                     │                    ▼                 │
 SQL Developer ── :1521 ────────────►│  oracle-db (Oracle 23ai Free)        │
 DBeaver                             │    service : FREEPDB1                │
                                     └──────────────────────────────────────┘

  Volumes partagés :  ./frontend     →  nginx  (HTML / CSS / JS)
                      ./backend/logs ←  api    (journaux winston)
  Synchronisé :       ./backend/src  →  api    (docker compose watch)
  Ports publiés sur 127.0.0.1 seulement : invisibles depuis le réseau du collège.
```

Trois choses à retenir, et ce sont les trois sources de confusion classiques :

| Question | Réponse |
|---|---|
| Depuis le **navigateur**, quelle URL ? | `http://localhost:8080` — le navigateur ne parle **qu'à nginx**. |
| Depuis le **code Node**, quelle adresse pour Oracle ? | `oracle-db:1521/FREEPDB1` — le **nom du service**, jamais `localhost`. |
| Depuis **Postman** ou **SQL Developer** ? | `localhost:3010` et `localhost:1521` — ce sont des ports *publiés* sur l'hôte. |

Dans un conteneur, `localhost` désigne **le conteneur lui-même**. C'est pour ça que
`localhost:1521` fonctionne depuis votre poste mais échoue depuis le code Node.

---

## 2. Prérequis

| | Minimum |
|---|---|
| Docker Desktop | version récente (pour `docker compose watch`), **démarré** |
| Mémoire allouée à Docker | **4 Go** (Settings → Resources → Memory) |
| Espace disque | ~4 Go |
| Éditeur | VS Code (ou autre) |

**Mac Apple Silicon (M1 à M4)** : l'image `gvenzl/oracle-free` est multi-plateforme
depuis la version 23.5, donc elle tourne **nativement en arm64**. Vérifiez que
*Settings → General → « Use Rosetta for x86/amd64 emulation »* est **décoché** —
sinon vous perdez la moitié des performances sans raison.

**Windows** : utilisez le backend WSL 2 (*Settings → General → « Use the WSL 2 based
engine »*). Placez le projet dans votre dossier utilisateur Windows, pas dans un
partage réseau : les volumes montés y sont beaucoup plus lents.

> **Toutes les commandes de ce guide tiennent sur une seule ligne**, sans caractère
> de continuation, et leurs arguments sont entre **guillemets doubles**. Elles se
> collent telles quelles dans PowerShell, dans l'invite de commandes, dans le Terminal
> macOS et dans un shell WSL.
>
> Trois pièges PowerShell valent la peine d'être connus, parce qu'ils reviennent dès
> qu'on sort de ce guide :
>
> | Piège | Symptôme | Parade |
> |---|---|---|
> | `\` en fin de ligne | la commande est tronquée | continuation = `` ` `` en PowerShell, `^` en `cmd.exe` — ou tout sur une ligne |
> | `@` en début d'argument | `Jeton non reconnu dans le texte source` | entourer l'argument de guillemets doubles : `"@/sql/x.sql"` |
> | `curl` | sortie inattendue, options refusées | c'est un alias d'`Invoke-WebRequest` en PowerShell 5.1 — écrire `curl.exe` |
>
> Les guillemets **doubles** sont le seul style compris par les quatre interpréteurs.
> N'utilisez pas de guillemets simples : `cmd.exe` les transmettrait tels quels dans
> l'argument. Corollaire pour le `.env` : évitez le caractère `$` dans vos mots de
> passe, il est interprété entre guillemets doubles par PowerShell comme par bash.

Vérification :

```bash
docker --version
docker compose version
docker info | grep -i "Total Memory"
```

---

## 3. Installation

```bash
# 1. Récupérer le projet
git clone <url-du-depot> 3gb-docker
cd 3gb-docker

# 2. Créer le fichier de configuration
cp .env.example .env        # Windows : copy .env.example .env

# 3. Télécharger les images, construire l'API et démarrer les trois conteneurs
docker compose up -d --build
```

Les images (Oracle, Node, nginx) sont téléchargées de Docker Hub à ce moment-là :
environ 2 Go la première fois.

Pour travailler, lancez ensuite la synchronisation du code Node dans un terminal
(celui de VS Code, par exemple) **que vous laissez ouvert** :

```bash
docker compose watch
```

> **Pourquoi `docker compose watch` ?** Le dossier `backend/src` n'est **pas**
> monté dans le conteneur : sur Windows, une sauvegarde dans VS Code ne serait
> jamais vue par Node. `docker compose watch` surveille votre poste et **copie**
> chaque fichier modifié dans le conteneur, où `node --watch-path=src` redémarre
> le serveur. Sans lui, l'API tourne avec le code de la dernière construction de
> l'image : vos modifications n'ont aucun effet.
>
> Ctrl-C arrête la synchronisation, **pas** les conteneurs. N'ajoutez pas `-d` :
> `docker compose up -d --watch` est refusé par Docker Compose.

Au **premier** démarrage, Oracle crée la base : comptez **2 à 4 minutes**. Suivez
la progression :

```bash
docker compose logs -f oracle-db
```

Attendez la ligne `DATABASE IS READY TO USE!`. Le conteneur `api` ne démarre pas
avant : c'est le rôle du `healthcheck` et du `depends_on: service_healthy` dans le
fichier `docker-compose.yml`.

État des trois services :

```bash
docker compose ps
```

Les trois doivent être `running`, et `3gb-oracle` doit afficher `(healthy)`.

---

## 4. Créer le compte et le schéma applicatifs

Le script `oracle/init/001_schema_base.sql` s'est joué **tout seul** à la création de
la base. Il a préparé le terrain : tablespace `TBS_3GB`, rôle `R_APP_3GB`, profil
`P_COURS_3GB`. Il ne se rejouera **jamais** tant que le volume `oracle-data` existe.

Le compte applicatif et les tables, eux, se créent à la main — c'est volontaire :
vous devez voir passer le DDL.

```bash
# 1. Le compte applicatif (connecté en SYSTEM sur la PDB)
docker compose exec oracle-db sqlplus "system/Oracle3GB_2026@//localhost:1521/FREEPDB1" "@/sql/10_utilisateur.sql"

# 2. Le schéma applicatif (connecté AVEC le compte applicatif)
docker compose exec oracle-db sqlplus "app3gb/App3GB_2026@//localhost:1521/FREEPDB1" "@/sql/20_schema_applicatif.sql"
```

> Remplacez les mots de passe si vous avez modifié le `.env`.

Puis redémarrez l'API, pour qu'elle ouvre son pool avec le compte qui existe
désormais :

```bash
docker compose restart api
```

Les scripts suivants de `oracle/app/` (logger, `cours`, `cours_tapi`, tests utPLSQL,
`etudiant_api`…) se jouent de la même façon, au fil des leçons.

---

## 5. Valider l'environnement

Faites les quatre tests dans l'ordre : chacun ajoute un maillon à la chaîne.

**Test 1 — Oracle répond**

```bash
docker compose exec oracle-db sqlplus -s "app3gb/App3GB_2026@//localhost:1521/FREEPDB1" "@/sql/99_verification.sql"
```

Résultat attendu : `PDB courante = FREEPDB1`, `Usager connecte = APP3GB`,
`Lignes dans ETUDIANT = 3`.

> **Pourquoi un fichier `.sql` plutôt qu'une requête directe ?** On pourrait être
> tenté d'écrire `... sqlplus -s app3gb/...@//... <<< "SELECT ..."`. Deux problèmes :
> le here-string `<<<` n'existe qu'en bash/zsh (donc pas en PowerShell), et
> `docker compose exec` alloue un TTY par défaut, ce qui est incompatible avec une
> entrée standard redirigée — d'où l'erreur `cannot attach stdin to a TTY-enabled
> container`. Si vous tenez à passer du SQL par l'entrée standard, il faut ajouter
> l'option `-T` : `docker compose exec -T oracle-db sqlplus ...`. Un fichier `.sql`
> évite les deux pièges et fonctionne à l'identique sur tous les postes.

**Test 2 — l'API parle à Oracle**

```bash
curl.exe http://localhost:3010/api/sante
```

Résultat attendu : `{"statut":"ok","oracle":{...,"PDB":"FREEPDB1","USAGER":"APP3GB"}}`

**Test 3 — nginx relaie vers l'API**

```bash
curl.exe http://localhost:8080/api/etudiants
```

La même liste que le test 2, mais passée par nginx. Si le test 2 fonctionne et pas
le test 3, le problème est dans `nginx/default.conf`.

**Test 4 — la chaîne complète**

Ouvrez <http://localhost:8080> et cliquez sur les trois boutons de la page.

**Connexion depuis SQL Developer / DBeaver**

| Champ | Valeur |
|---|---|
| Hôte | `localhost` |
| Port | `1521` |
| Type | Nom de service (*Service name*) |
| Service | `FREEPDB1` |
| Usager | `app3gb` |
| Mot de passe | `App3GB_2026` |

---

## 6. Travailler au quotidien

Au début de chaque séance, Docker Desktop démarré :

```bash
docker compose watch
```

Cette commande démarre les trois conteneurs s'ils sont arrêtés, puis synchronise
`backend/src`. Laissez son terminal ouvert pendant que vous travaillez.

| Ce que vous modifiez | Ce qu'il faut faire |
|---|---|
| `frontend/*.html`, `*.js`, `*.css` | Rien — rafraîchir le navigateur |
| `backend/src/*.js`, `*.mjs` | Rien, **si** `docker compose watch` tourne — le fichier est copié et le serveur redémarre |
| `backend/package.json` (nouvelle dépendance) | Rien si `docker compose watch` tourne (l'image est reconstruite) ; sinon `docker compose up -d --build api` |
| `nginx/default.conf` | `docker compose restart web` |
| `oracle/app/*.sql` | Rejouer le script avec `docker compose exec` |
| `.env` | `docker compose up -d` (recrée les conteneurs) |
| Après un `git pull` | `docker compose up -d --build`, puis `docker compose watch` |

Les journaux de l'API s'écrivent dans **`backend/logs/serveur.log`**, sur votre
poste : ouvrez-le dans VS Code, Notepad ou TextEdit. `docker compose logs -f api`
affiche les mêmes lignes, en couleurs.

**Attention à `node_modules`.** Les dépendances sont installées **dans l'image**, pas
sur votre poste, et `./backend/node_modules` n'est jamais monté. C'est ce qui permet
au même dépôt de fonctionner sur un Mac ARM et un PC x86 : un `node_modules` installé
sur l'un ne fonctionnerait pas sur l'autre. Si vous faites un `npm install` local pour
l'autocomplétion de VS Code, tant mieux, mais le conteneur l'ignore.

**Ajouter une dépendance.** Modifiez `backend/package.json` *et*
`backend/package-lock.json` : le plus simple est `npm install <paquet>` dans le
dossier `backend` sur votre poste (Node requis), puis `docker compose up -d --build api`.
L'image installe exactement les versions du `package-lock.json` (`npm ci`) : tous
les postes obtiennent les mêmes.

Commandes utiles :

```bash
docker compose watch                # démarrer + synchroniser backend/src
docker compose logs -f api          # journal de l'API en direct
docker compose logs -f web          # journal nginx (accès + erreurs)
docker compose exec api sh          # shell dans le conteneur Node
docker compose restart api          # redémarrer un seul service
docker compose down                 # arrêter — LES DONNÉES SURVIVENT
docker compose down -v              # arrêter ET tout effacer
```

---

## 7. Repartir à zéro

```bash
docker compose down -v
docker compose up -d --build
```

`-v` détruit le volume `oracle-data`. La base est recréée de zéro, et
`001_schema_base.sql` **se rejoue**. Il faut ensuite refaire l'étape 4.

C'est la manœuvre à faire quand votre base est dans un état incohérent — et c'est
aussi la raison pour laquelle rien d'important ne doit vivre uniquement dans le
conteneur : tout ce qui compte est dans un fichier `.sql` versionné.

---

## 8. Dépannage

**`port is already allocated` / `bind: address already in use`**
Un autre programme occupe 1521, 3010 ou 8080 sur votre poste. Changez la valeur dans `.env`
(`WEB_PORT=8081`, par exemple) puis `docker compose up -d`. Pour trouver le coupable :
`lsof -i :8080` (Mac) ou `netstat -ano | findstr :8080` (Windows).

**Oracle redémarre en boucle, ou reste `unhealthy`**
Presque toujours un manque de mémoire. Docker Desktop → Settings → Resources →
Memory ≥ 4 Go, puis `docker compose down && docker compose up -d`.

**`ORA-01017: invalid username/password`**
Le compte applicatif n'a pas encore été créé (étape 4), ou le `.env` ne correspond
pas à ce qui a été passé au script `10_utilisateur.sql`.

**`ORA-12541: TNS:no listener` ou `ORA-12514`**
Oracle n'a pas fini de démarrer, ou la chaîne de connexion est fausse. Depuis le code
Node, ce doit être `oracle-db:1521/FREEPDB1` — pas `localhost`, et pas `FREE` (qui est
le CDB, pas la PDB applicative).

**`ORA-00942: table or view does not exist`**
Le schéma applicatif n'a pas été créé, ou il a été créé sous `SYSTEM` au lieu de
`app3gb`. Vérifiez : `SELECT owner, table_name FROM all_tables WHERE table_name = 'ETUDIANT';`

**`ORA-01110` + `ORA-27037: unable to obtain file status` sur `tbs_3gb01.dbf`**
Le fichier de données du tablespace a été créé **hors du volume monté** (dans
`$ORACLE_HOME/dbs`, à l'intérieur du conteneur) : il survit à un `restart`, mais
disparaît dès que le conteneur est recréé, et la base rouvre sans son tablespace.
Vérifiez où il se trouve :

```sql
SELECT tablespace_name, file_name FROM dba_data_files WHERE tablespace_name = 'TBS_3GB';
```

Le chemin **doit** commencer par `/opt/oracle/oradata/`. S'il pointe vers `.../dbs/`,
la base est à reconstruire : `docker compose down -v && docker compose up -d`, puis
refaire l'étape 4. Depuis la correction du 26 août 2026, `001_schema_base.sql` déduit
le bon répertoire automatiquement et affiche un avertissement dans les journaux si le
fichier atterrit au mauvais endroit.

> **`Cannot find package 'cors'` (ou `'winston'`, `'express'`) et `502 Bad Gateway`**
>
> Votre image Docker date d'avant la mise à jour : `git pull` a apporté le nouveau
> code, mais pas ses nouvelles dépendances. `docker compose watch` recopie `src/`,
> pas `node_modules`. Node s'arrête au premier `import` manquant, puis attend
> (`Waiting for file changes before restarting...`) sans écouter le port 3010,
> d'où le 502 de nginx.
>
> Reconstruisez l'image une fois, puis relancez watch :
>
> ```bash
> docker compose up -d --build api
> ```
>
> `docker compose logs --tail 5 api` doit afficher `API sur le port 3010`.
>
> **Règle à retenir :** après chaque `git pull`, faites `docker compose up -d --build`,
> **puis** `docker compose watch`.

**`502 Bad Gateway` (ou JSON `"title":"API injoignable"`) sur `http://localhost:8080/api/...`**
nginx est debout, l'API ne l'est pas. `docker compose logs --tail 40 api` donne la
cause : une erreur dans le code au démarrage (`SyntaxError`, `Cannot find module`,
suivi de `Waiting for file changes...` : corrigez et sauvegardez), un module manquant
(voir l'encadré ci-dessus), ou le pool Oracle qui n'a pas pu s'ouvrir
(`[db] Tentative 10/10 echouee` : vérifiez `.env` et `docker compose ps`).

**Le navigateur sert une vieille version de mon JS**
Le `Cache-Control: no-store` de `nginx/default.conf` devrait l'empêcher. Sinon,
rechargement forcé : Ctrl-Maj-R (Windows) ou Cmd-Maj-R (Mac).

**Mes modifications dans `backend/src` n'ont aucun effet**
La synchronisation ne tourne pas : relancez `docker compose watch` et laissez son
terminal ouvert (au démarrage, tout `src/` est recopié, rien n'est perdu). Vérifiez
aussi que vous éditez bien `backend/src/` et non `backend/`.

**`--detach cannot be combined with ... --watch`**
`docker compose up -d --watch` n'existe pas. Utilisez `docker compose watch`.

**Je ne peux pas me connecter depuis un autre ordinateur**
C'est voulu : les ports sont publiés sur `127.0.0.1`, donc accessibles depuis votre
poste seulement (votre base n'est pas exposée sur le réseau du collège).

**`ORA-01804: failure to initialize timezone information`**
L'image Oracle n'est pas celle qui a créé votre base. Une base ne fonctionne
qu'avec sa version d'image : voir l'étape 4 de la section 11 (variable `ORACLE_TAG`
dans `.env`).

**Je modifie `nginx/default.conf` mais nginx ne voit rien, même après un `restart`**
Ce fichier est monté seul (pas son dossier). Certains éditeurs remplacent le fichier
en sauvegardant, et le conteneur garde l'ancien. Recréez le conteneur :
`docker compose up -d --force-recreate web`.

**`cannot attach stdin to a TTY-enabled container because stdin is not a terminal`**
Vous avez redirigé l'entrée standard (`<<<`, `<`, ou un tube) vers un
`docker compose exec` qui alloue un TTY. Ajoutez `-T` :
`docker compose exec -T oracle-db sqlplus ...`. Ou mieux, passez par un fichier
`.sql` avec `@/sql/mon_script.sql`, ce qui fonctionne partout sans option.

**Le premier `docker compose up` prend une éternité**
Le téléchargement de l'image Oracle représente environ 2 Go, puis la création de la
base 2 à 4 minutes. C'est normal, et ça n'arrive qu'une fois. Faites-le **avant** le
premier cours, pas pendant.

---

## 9. Structure du projet

```
3gb-docker/
├── docker-compose.yml          Les trois services, le réseau, le volume
├── .env.example                Modèle de configuration (à copier en .env)
├── .gitignore
├── README.md                   Ce guide
├── nginx/
│   └── default.conf            Statique + reverse proxy /api
├── oracle/
│   ├── init/
│   │   └── 001_schema_base.sql   AUTO, une seule fois : tablespace, rôle, profil
│   └── app/                      MANUEL, dans l'ordre des numéros :
│       ├── 10_utilisateur.sql    compte applicatif
│       ├── 15_privileges_logger.sql  privilèges requis par logger
│       ├── 20_schema_applicatif.sql  tables + données de test
│       ├── 25_logger_install.sql journalisation PL/SQL (logger)
│       ├── 30_cours.sql          table cours
│       ├── 31_cours_tapi.spc/.bdy  paquetage cours_tapi (JSON:API)
│       ├── 40_… à 45_…           tests utPLSQL de cours_tapi (45 : désinstaller utPLSQL)
│       ├── 99_verification.sql   test 1 de validation
│       └── 110_etudiant.spc/.bdy paquetage etudiant_api
├── backend/
│   ├── Dockerfile              node:24 + npm ci + node --watch-path
│   ├── package.json            Dépendances, versions exactes
│   ├── package-lock.json       Versions verrouillées (npm ci)
│   ├── logs/                   serveur.log, visible sur le poste (non versionné)
│   └── src/                    Synchronisé par « docker compose watch »
│       ├── server.js           Express : middlewares, routes, erreurs
│       ├── routes/             Verbe + URL → contrôleur
│       ├── controllers/        Validation, code HTTP + JSON
│       ├── models/             Appels aux TAPI (aucun HTTP)
│       └── lib/                Outils partagés
│           ├── db.js           Pool node-oracledb (mode Thin)
│           ├── tapi.mjs        Appel générique d'une TAPI (:reto JSON)
│           ├── erreurs.mjs     ErreurApi → document JSON:API { errors }
│           └── logger.mjs      Journalisation winston
├── frontend/
│   ├── index.html              Page de validation
│   ├── app.js                  Appels fetch vers /api
│   ├── cours.html, cours.js…   Interface de gestion des cours
│   └── style.css, cours.css
├── tests/
│   └── cours.json              Exemple de corps JSON pour POST/PUT /api/cours
└── docs/
    └── annexe-docker-run.md    Les mêmes conteneurs, sans Compose
```

---

## 10. Annexe pédagogique

Compose est une **traduction déclarative** de commandes `docker` que l'on pourrait
taper à la main. Voir [`docs/annexe-docker-run.md`](docs/annexe-docker-run.md) : le
même environnement, monté conteneur par conteneur, pour comprendre ce que Compose
fait à votre place.

---

## 11. Mise à jour de novembre 2026 — à faire une seule fois

> Message transmis aux étudiants. À suivre si votre dépôt date d'avant le
> 12 novembre 2026. Pour une installation neuve, ignorez cette section.

J'ai mis à jour le dépôt `3gb-docker`. Les principaux changements :

- **Sous Windows, le serveur Node redémarre enfin tout seul** quand vous sauvegardez
  un fichier dans `backend/src`.
- **Les journaux de l'API sont visibles sur votre poste**, dans
  `backend/logs/serveur.log`.
- **Oracle, l'API et nginx ne sont plus accessibles depuis le réseau du collège**,
  seulement depuis votre propre poste.
- **Tout le monde a les mêmes versions** de Node, Express, oracledb et nginx.

**Vos données Oracle sont conservées.** N'utilisez surtout pas `docker compose down -v`.

**Étape 1 : noter votre version d'Oracle** (dans le dossier `3gb-docker`, *avant*
le `git pull`)

```bash
docker compose exec oracle-db sqlplus -v
```

Notez la version affichée sur la ligne `Version 23.26.…`.

**Étape 2 : mettre de côté vos modifications**

Si vous avez modifié des fichiers du dépôt (par exemple `server.js` ou
`models/cours.mjs`), mettez-les de côté pour éviter un conflit :

```bash
git stash
```

**Étape 3 : récupérer la mise à jour**

```bash
git pull
```

**Étape 4 : adapter `.env` à votre version d'Oracle**

| Version notée à l'étape 1 | Quoi faire |
|---|---|
| `23.26.3` | Rien. |
| `23.26.2` | Ouvrez `.env` et ajoutez, sur une nouvelle ligne : `ORACLE_TAG=23.26.2-slim` |
| Une autre version | **Arrêtez-vous ici** et écrivez-moi en indiquant la version. |

Pourquoi ? Une base Oracle ne fonctionne qu'avec la version d'image qui l'a créée.
Avec la mauvaise version, la base démarre, mais tout ce qui touche aux fuseaux
horaires échoue (`ORA-01804`).

**Étape 5 : reconstruire et démarrer**

```bash
docker compose up -d --build
```

Le premier démarrage télécharge de nouvelles images. Comptez quelques minutes.

**Étape 6 : remettre vos modifications** (seulement si vous avez fait `git stash`)

```bash
git stash pop
```

En cas de conflit, ne paniquez pas : apportez votre poste au prochain cours.

**Étape 7 : vérifier que tout fonctionne**

Ouvrez <http://localhost:8080/api/sante>. Vous devez voir `"statut":"ok"`.

**⚠️ Ce qui change dans vos habitudes**

À partir de maintenant, travaillez avec **`docker compose watch`** ouvert dans un
terminal (celui de VS Code, par exemple) :

```bash
docker compose watch
```

Sans lui, vos modifications dans `backend/src` **n'ont aucun effet** : l'API continue
d'exécuter l'ancien code. Si vous avez l'impression que vos changements sont ignorés,
c'est presque toujours la raison. Relancez la commande ci-dessus. Ctrl-C l'arrête sans
arrêter les conteneurs.

Les autres outils ne changent pas : le navigateur sur `localhost:8080`, Postman sur
`localhost:3010` et SQL Developer sur `localhost:1521` fonctionnent comme avant.

**`ORA-01804` après la mise à jour ?** Vous avez sauté l'étape 4. Ajoutez la ligne
`ORACLE_TAG=…` qui correspond à votre version dans `.env`, puis relancez
`docker compose up -d`.

---

## Références

- Image Oracle : [gvenzl/oci-oracle-free](https://github.com/gvenzl/oci-oracle-free)
- Pilote Node : [node-oracledb — mode Thin](https://node-oracledb.readthedocs.io/en/latest/user_guide/appendix_a.html)
