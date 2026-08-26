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

  Volumes partagés :  ./frontend  →  nginx   (HTML / CSS / JS)
                      ./backend/src → api    (sources Node)
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
| Docker Desktop | version récente, **démarré** |
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

# 3. Démarrer les trois conteneurs
docker compose up -d
```

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
docker compose exec oracle-db sqlplus \
    system/Oracle3GB_2026@//localhost:1521/FREEPDB1 @/sql/10_utilisateur.sql

# 2. Le schéma applicatif (connecté AVEC le compte applicatif)
docker compose exec oracle-db sqlplus \
    app3gb/App3GB_2026@//localhost:1521/FREEPDB1 @/sql/20_schema_applicatif.sql
```

> Remplacez les mots de passe si vous avez modifié le `.env`.

Puis redémarrez l'API, pour qu'elle ouvre son pool avec le compte qui existe
désormais :

```bash
docker compose restart api
```

---

## 5. Valider l'environnement

Faites les quatre tests dans l'ordre : chacun ajoute un maillon à la chaîne.

**Test 1 — Oracle répond**

```bash
docker compose exec oracle-db sqlplus -s \
    app3gb/App3GB_2026@//localhost:1521/FREEPDB1 @/sql/99_verification.sql
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
curl http://localhost:3010/api/sante
```

Résultat attendu : `{"statut":"ok","oracle":{...,"PDB":"FREEPDB1","USAGER":"APP3GB"}}`

**Test 3 — nginx relaie vers l'API**

```bash
curl http://localhost:8080/api/etudiants
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

| Ce que vous modifiez | Ce qu'il faut faire |
|---|---|
| `frontend/*.html`, `*.js`, `*.css` | Rien — rafraîchir le navigateur |
| `backend/src/*.js` | Rien — `node --watch` redémarre le serveur |
| `backend/package.json` (nouvelle dépendance) | `docker compose up -d --build api` |
| `nginx/default.conf` | `docker compose restart web` |
| `oracle/app/*.sql` | Rejouer le script avec `docker compose exec` |
| `.env` | `docker compose up -d` (recrée les conteneurs) |

**Attention à `node_modules`.** Les dépendances sont installées **dans l'image**, pas
sur votre poste, et `./backend/node_modules` n'est jamais monté. C'est ce qui permet
au même dépôt de fonctionner sur un Mac ARM et un PC x86 : un `node_modules` installé
sur l'un ne fonctionnerait pas sur l'autre. Si vous faites un `npm install` local pour
l'autocomplétion de VS Code, tant mieux, mais le conteneur l'ignore.

Commandes utiles :

```bash
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
docker compose up -d
```

`-v` détruit le volume `oracle-data`. La base est recréée de zéro, et
`001_schema_base.sql` **se rejoue**. Il faut ensuite refaire l'étape 4.

C'est la manœuvre à faire quand votre base est dans un état incohérent — et c'est
aussi la raison pour laquelle rien d'important ne doit vivre uniquement dans le
conteneur : tout ce qui compte est dans un fichier `.sql` versionné.

---

## 8. Dépannage

**`port is already allocated` / `bind: address already in use`**
Un autre programme occupe 1521, 3010 ou 8080. Changez la valeur dans `.env`
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

**`502 Bad Gateway` sur `http://localhost:8080/api/...`**
nginx est debout, l'API ne l'est pas. `docker compose logs api` — c'est en général le
pool Oracle qui n'a pas pu s'ouvrir.

**Le navigateur sert une vieille version de mon JS**
Le `Cache-Control: no-store` de `nginx/default.conf` devrait l'empêcher. Sinon,
rechargement forcé : Ctrl-Maj-R (Windows) ou Cmd-Maj-R (Mac).

**Mes modifications dans `backend/src` n'ont aucun effet**
Vérifiez que vous éditez bien `backend/src/` et non `backend/`. Sur Windows, vérifiez
aussi le partage de fichiers de Docker Desktop.

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
│   └── app/
│       ├── 10_utilisateur.sql    MANUEL : compte applicatif
│       ├── 20_schema_applicatif.sql  MANUEL : tables + données de test
│       └── 99_verification.sql   MANUEL : test 1 de validation
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── db.js               Pool node-oracledb (mode Thin)
│       └── server.js           Routes REST
├── frontend/
│   ├── index.html              Page de validation
│   ├── app.js                  Appels fetch vers /api
│   └── style.css
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

## Références

- Image Oracle : [gvenzl/oci-oracle-free](https://github.com/gvenzl/oci-oracle-free)
- Pilote Node : [node-oracledb — mode Thin](https://node-oracledb.readthedocs.io/en/latest/user_guide/appendix_a.html)
