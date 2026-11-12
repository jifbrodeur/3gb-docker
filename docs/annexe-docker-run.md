# Annexe pédagogique — les mêmes conteneurs, sans Compose

Le fichier `docker-compose.yml` n'a rien de magique : c'est la **traduction
déclarative** d'une série de commandes `docker`. Cette annexe monte le même
environnement à la main, dans l'ordre.

Objectif : comprendre ce que Compose fait à votre place. Vous n'aurez pas à
retaper ces commandes en laboratoire.

> **Windows.** Les commandes ci-dessous sont écrites à la mode bash/zsh : le `\` en
> fin de ligne est un caractère de continuation, et `$(pwd)` désigne le répertoire
> courant. En PowerShell, la continuation est l'accent grave `` ` `` et le répertoire
> courant s'écrit `${PWD}`; dans `cmd.exe`, c'est `^` et `%cd%`. Le plus sûr : recollez
> chaque commande sur une seule ligne et remplacez `$(pwd)` par `${PWD}`.

---

## 1. Le réseau

Sans réseau nommé, les conteneurs ne peuvent pas se joindre par leur nom. C'est
le premier service que Compose crée, et il le fait en silence.

```bash
docker network create 3gb-net
```

Le réseau `bridge` par défaut de Docker ne fournit **pas** la résolution DNS par
nom de conteneur ; un réseau créé par l'usager, oui. C'est ce qui rend possible
`oracle-db:1521` dans le code Node.

---

## 2. Le volume de la base

```bash
docker volume create oracle-data
```

Un volume nommé vit **en dehors** du conteneur. Il survit à `docker rm`, et c'est
exactement ce qu'on veut pour une base de données.

---

## 3. Oracle

```bash
docker run -d \
  --name 3gb-oracle \
  --network 3gb-net \
  -p 127.0.0.1:1521:1521 \
  -e ORACLE_PASSWORD=Oracle3GB_2026 \
  -v oracle-data:/opt/oracle/oradata \
  -v "$(pwd)/oracle/init:/container-entrypoint-initdb.d:ro" \
  -v "$(pwd)/oracle/app:/sql:ro" \
  gvenzl/oracle-free:23.26.3-slim
```

> Compose lit cette version dans la variable `ORACLE_TAG` du `.env` (par défaut
> `23.26.3-slim`) : une base ne fonctionne qu'avec la version d'image qui l'a créée.

Décortiquons :

| Option | Équivalent Compose | Rôle |
|---|---|---|
| `-d` | (implicite) | Détaché : rend la main tout de suite |
| `--name` | `container_name:` | Nom fixe, sinon Docker en invente un |
| `--network` | `networks:` | Sans ça, le conteneur est isolé des deux autres |
| `-p 127.0.0.1:1521:1521` | `ports:` | `ip:hôte:conteneur` — publie vers votre poste seulement |
| `-e` | `environment:` | Variable lue par le point d'entrée de l'image |
| `-v oracle-data:...` | `volumes:` | Volume **nommé** : persistance |
| `-v "$(pwd)/...:...:ro"` | `volumes:` | **Bind mount** : un dossier de votre poste, en lecture seule |

Surveillez la création de la base :

```bash
docker logs -f 3gb-oracle      # attendre « DATABASE IS READY TO USE! »
```

> Sur Windows PowerShell, remplacez `$(pwd)` par `${PWD}`.

---

## 4. L'API Node

L'image doit d'abord être construite — Compose le faisait via `build: ./backend`.

```bash
docker build -t 3gb-api ./backend

docker run -d \
  --name 3gb-api \
  --network 3gb-net \
  -p 127.0.0.1:3010:3010 \
  -e PORT=3010 \
  -e DB_CONNECT_STRING=oracle-db:1521/FREEPDB1 \
  -e DB_USER=app3gb \
  -e DB_PASSWORD=App3GB_2026 \
  --init \
  --network-alias api \
  -v "$(pwd)/backend/logs:/app/logs" \
  -v "$(pwd)/backend/src:/app/src" \
  3gb-api
```

| Option | Équivalent Compose | Rôle |
|---|---|---|
| `--init` | `init: true` | Petit processus init en PID 1 : relaie SIGTERM à Node pour un arrêt propre |
| `--network-alias api` | nom du service `api` | nginx relaie vers `http://api:3010` |
| `-v .../backend/logs:...` | `volumes:` | `serveur.log` visible sur votre poste |
| `-v .../backend/src:...` | `develop.watch` | Voir le point 3 ci-dessous |

Trois points à noter :

1. **`DB_CONNECT_STRING=oracle-db:1521/...`** — mais le conteneur Oracle s'appelle
   `3gb-oracle` ! Avec `docker run`, le DNS interne résout le **nom du conteneur**.
   Avec Compose, il résout le **nom du service** (`oracle-db`) *et* le nom du
   conteneur. Pour que cette commande fonctionne, il faut donc soit nommer le
   conteneur Oracle `oracle-db`, soit ajouter `--network-alias oracle-db` à
   l'étape 3. C'est précisément le genre de détail que Compose gère seul.

2. **Il n'y a pas de `depends_on`.** Si vous lancez l'API avant qu'Oracle soit prêt,
   elle échoue — d'où les tentatives répétées dans `db.js`. Compose, lui, sait
   attendre le `healthcheck`.

3. **Le code est monté, pas synchronisé.** `docker run` ne sait que monter
   `backend/src` (*bind mount*). Sur Mac, `node --watch-path` voit les sauvegardes ;
   sur Windows (WSL 2), il ne les voit pas. C'est pourquoi le `docker-compose.yml`
   ne monte **pas** `backend/src` : il le **copie** dans le conteneur à chaque
   sauvegarde, grâce à `develop.watch` et à la commande `docker compose watch`,
   qui n'a pas d'équivalent `docker run`.

---

## 5. nginx

```bash
docker run -d \
  --name 3gb-web \
  --network 3gb-net \
  -p 127.0.0.1:8080:8080 \
  -v "$(pwd)/frontend:/usr/share/nginx/html:ro" \
  -v "$(pwd)/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:1.30.6-alpine
```

Le second `-v` monte **un seul fichier**, pas un dossier — c'est permis, et c'est le
moyen habituel d'injecter une configuration dans une image officielle. Revers : un
éditeur qui *remplace* le fichier en sauvegardant laisse le conteneur sur l'ancienne
version ; il faut alors recréer le conteneur.

---

## 6. Nettoyage

```bash
docker rm -f 3gb-web 3gb-api 3gb-oracle
docker network rm 3gb-net
docker volume rm oracle-data          # détruit la base
```

Soit six commandes, dans le bon ordre, sans se tromper. Compose fait la même chose
avec `docker compose down -v`.

---

## Ce qu'il faut retenir

| Concept | `docker run` | Compose |
|---|---|---|
| Réseau | `docker network create` + `--network` | créé automatiquement |
| Résolution par nom | nom du conteneur / `--network-alias` | nom du **service** |
| Ordre de démarrage | à votre charge | `depends_on` + `healthcheck` |
| Reconstruction | `docker build` puis `docker run` | `up -d --build` |
| Code synchronisé | *bind mount* seulement | `develop.watch` + `docker compose watch` |
| Reproductibilité | un fichier texte à part, ou votre mémoire | le `docker-compose.yml`, versionné |

La dernière ligne est la vraie raison d'être de Compose : l'environnement devient un
**fichier versionné**, revu, corrigé et identique pour les 30 postes du laboratoire.
