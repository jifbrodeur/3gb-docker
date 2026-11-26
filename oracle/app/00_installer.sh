#!/usr/bin/env bash
# =====================================================================
# 00_installer.sh - installe le schema du cours et/ou celui d'une equipe
#
# Joue DANS le conteneur oracle-db : la commande est identique sur
# macOS, Linux, PowerShell et l'invite de commandes Windows.
#
#   docker compose exec oracle-db bash /sql/00_installer.sh            le cours
#   docker compose exec oracle-db bash /sql/00_installer.sh rjwj       une equipe
#   docker compose exec oracle-db bash /sql/00_installer.sh tout       le cours + les 4 equipes
#
# Puis, toujours : docker compose restart api
#
# LE COURS (plage 0-199) : les scripts de oracle/app dans cet ordre
#   10, 15 (SYSTEM)  puis  20, 25, 30, 31, 110 (compte applicatif)
#   10 est saute si le compte existe deja, 25 si logger est deja installe
#   (le rejouer viderait le journal). Les autres sont idempotents.
#
# UNE EQUIPE : tous les scripts de sa plage, dans l'ordre des numeros,
# avec le compte applicatif. Rien a modifier ici quand l'equipe ajoute
# un script : il suffit de le numeroter dans sa plage.
#   SBDD 200-299   RJWJ 300-399   BIBLI 400-499   ACCORD 500-599
#   A numero egal : .sql, puis .spc, puis .bdy.
#   Exemple : 310_rjwj_client.sql, 320_rjwj_client_tapi.spc,
#             320_rjwj_client_tapi.bdy, 330_test_rjwj_client_tapi.spc ...
#
# Le DDL de chaque script defile a l'ecran. L'installation s'arrete au
# premier script en erreur (ORA-, PLS-, SP2-, erreur de compilation).
# =====================================================================

set -u

# Doivent correspondre a 10_utilisateur.sql et au fichier .env
APP_USER="app3gb"
APP_PASSWORD="App3GB_2026"
SYSTEM_PASSWORD="${ORACLE_PASSWORD:?ORACLE_PASSWORD absent du conteneur}"
PDB="//localhost:1521/FREEPDB1"
DOSSIER="/sql"

# ---------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------

# Execute un script et s'arrete s'il echoue. $1 = compte (system|app)
jouer() {
    local compte="$1" fichier="$2" connexion sortie code
    if [ "$compte" = "system" ]; then
        connexion="system/${SYSTEM_PASSWORD}@${PDB}"
    else
        connexion="${APP_USER}/${APP_PASSWORD}@${PDB}"
    fi
    echo
    echo "=================================================================="
    echo "==> ${fichier}   (${compte})"
    echo "=================================================================="
    # < /dev/null : sqlplus se termine meme si le script n'a pas d'EXIT
    sortie=$(sqlplus -s -L "$connexion" "@${DOSSIER}/${fichier}" < /dev/null 2>&1)
    code=$?
    echo "$sortie"
    if [ $code -ne 0 ] || echo "$sortie" | grep -qE '(ORA|PLS|SP2)-[0-9]{4,5}|compilation errors'; then
        echo
        echo "*** ECHEC dans ${fichier} : lire le message ci-dessus."
        echo "*** Corriger le script, puis relancer la meme commande."
        exit 1
    fi
}

# Retourne la premiere colonne d'une requete d'une ligne
valeur() {
    local connexion="$1" requete="$2"
    sqlplus -s -L "$connexion" 2>/dev/null <<SQL | tr -d '[:space:]'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
${requete}
EXIT;
SQL
}

# ---------------------------------------------------------------------
# Le cours
# ---------------------------------------------------------------------
installer_cours() {
    local existe logger
    existe=$(valeur "system/${SYSTEM_PASSWORD}@${PDB}" \
        "SELECT COUNT(*) FROM dba_users WHERE username = UPPER('${APP_USER}');")
    if [ "$existe" = "1" ]; then
        echo "--- 10_utilisateur.sql saute : le compte ${APP_USER} existe deja."
    else
        jouer system 10_utilisateur.sql
    fi
    jouer system 15_privileges_logger.sql
    jouer app    20_schema_applicatif.sql

    logger=$(valeur "${APP_USER}/${APP_PASSWORD}@${PDB}" \
        "SELECT COUNT(*) FROM user_objects WHERE object_name = 'LOGGER' AND object_type = 'PACKAGE BODY' AND status = 'VALID';")
    if [ "$logger" = "1" ]; then
        echo "--- 25_logger_install.sql saute : logger est deja installe."
    else
        jouer app 25_logger_install.sql
    fi

    jouer app 30_cours.sql
    jouer app 31_cours_tapi.spc
    jouer app 31_cours_tapi.bdy
    jouer app 110_etudiant.spc
    jouer app 110_etudiant.bdy
}

# ---------------------------------------------------------------------
# Une equipe : tous les scripts de sa plage, tries par numero puis
# par extension (.sql, .spc, .bdy)
# ---------------------------------------------------------------------
installer_equipe() {
    local nom="$1" debut="$2" fichier base numero rang trouve=0
    echo
    echo "##################################################################"
    echo "## Equipe ${nom} : scripts ${debut} a $((debut + 99))"
    echo "##################################################################"
    while IFS= read -r fichier; do
        trouve=1
        jouer app "$fichier"
    done < <(
        for chemin in "${DOSSIER}"/*; do
            base=$(basename "$chemin")
            [[ "$base" =~ ^([0-9]+)_.*\.(sql|spc|bdy)$ ]] || continue
            numero=$((10#${BASH_REMATCH[1]}))
            [ "$numero" -ge "$debut" ] && [ "$numero" -le $((debut + 99)) ] || continue
            case "${BASH_REMATCH[2]}" in sql) rang=1 ;; spc) rang=2 ;; bdy) rang=3 ;; esac
            printf '%05d %d %s\n' "$numero" "$rang" "$base"
        done | sort | cut -d' ' -f3
    )
    if [ $trouve -eq 0 ]; then
        echo "--- Aucun script dans la plage ${debut}-$((debut + 99))."
    fi
}

equipe() {
    case "$1" in
        sbdd)   installer_equipe SBDD   200 ;;
        rjwj)   installer_equipe RJWJ   300 ;;
        bibli)  installer_equipe BIBLI  400 ;;
        accord) installer_equipe ACCORD 500 ;;
    esac
}

# ---------------------------------------------------------------------
# Programme principal
# ---------------------------------------------------------------------
cible=$(echo "${1:-cours}" | tr '[:upper:]' '[:lower:]')
case "$cible" in
    cours)                  installer_cours ;;
    sbdd|rjwj|bibli|accord) equipe "$cible" ;;
    tout)                   installer_cours
                            for e in sbdd rjwj bibli accord; do equipe "$e"; done ;;
    *)
        echo "Usage : bash /sql/00_installer.sh [cours|sbdd|rjwj|bibli|accord|tout]"
        exit 2 ;;
esac

echo
echo "Installation terminee (${cible}). Redemarrer l'API :"
echo "    docker compose restart api"
