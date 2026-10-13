#!/usr/bin/env bash
# Restauration Base de données + Content Store à partir d'une sauvegarde
# produite par backup.sh.
#
# Usage : ./scripts/restore.sh backups/20260907-143000 [--yes] [--reset-index]
#   --yes          ne pose pas la question de confirmation
#   --reset-index  vide l'index Solr après restauration (il sera reconstruit
#                  automatiquement : recommandé si la recherche semble incohérente)
set -euo pipefail

cd "$(dirname "$0")/.."

BACKUP_DIR=""
ASSUME_YES=0
RESET_INDEX=0
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --reset-index) RESET_INDEX=1 ;;
    -*) echo "Option inconnue : $arg"; exit 1 ;;
    *) BACKUP_DIR="$arg" ;;
  esac
done

if [ -z "${BACKUP_DIR}" ]; then
  echo "Usage: $0 <dossier-de-sauvegarde> [--yes] [--reset-index]"
  echo "Exemple: $0 backups/20260907-143000"
  exit 1
fi

if [ ! -f "${BACKUP_DIR}/alfresco.dump" ] || [ ! -f "${BACKUP_DIR}/content-store.tar.gz" ]; then
  echo "Sauvegarde incomplète dans ${BACKUP_DIR} — les deux fichiers sont requis."
  exit 1
fi

ALF_CID=$(docker compose ps -a -q alfresco)
if [ -z "${ALF_CID}" ]; then
  echo "ERREUR : le conteneur alfresco n'existe pas. Lancez d'abord : docker compose up -d" >&2
  exit 1
fi
CONTENT_VOLUME=$(docker inspect "${ALF_CID}" \
  --format '{{range .Mounts}}{{if eq .Destination "/usr/local/tomcat/alf_data"}}{{.Name}}{{end}}{{end}}')

echo "== Restauration Alfresco depuis ${BACKUP_DIR} =="
echo "   Volume du content store : ${CONTENT_VOLUME}"
echo "ATTENTION : ceci écrase les données actuelles (base + content store)."
if [ "${ASSUME_YES}" -ne 1 ]; then
  read -r -p "Continuer ? (o/N) " confirm
  if [[ ! "$confirm" =~ ^[oO]$ ]]; then
    echo "Annulé."
    exit 0
  fi
fi

echo "-> Arrêt d'Alfresco et Share (le conteneur Postgres reste actif)..."
docker compose stop alfresco share

echo "-> Restauration de la base de données..."
docker compose cp "${BACKUP_DIR}/alfresco.dump" postgres:/tmp/alfresco.dump
docker compose exec -T postgres bash -c "
  dropdb --force -U alfresco alfresco &&
  createdb -U alfresco alfresco &&
  pg_restore -U alfresco -d alfresco /tmp/alfresco.dump
"

echo "-> Restauration du Content Store..."
docker run --rm \
  -v "${CONTENT_VOLUME}":/data \
  -v "$(pwd)/${BACKUP_DIR}":/backup \
  alpine \
  sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/content-store.tar.gz -C /data"

if [ "${RESET_INDEX}" -eq 1 ]; then
  echo "-> Réinitialisation de l'index Solr (reconstruction automatique ensuite)..."
  SEARCH_CID=$(docker compose ps -a -q search)
  SOLR_VOLUME=$(docker inspect "${SEARCH_CID}" \
    --format '{{range .Mounts}}{{if eq .Destination "/opt/alfresco-search-services/data"}}{{.Name}}{{end}}{{end}}')
  docker compose stop search
  docker compose rm -f search >/dev/null
  docker volume rm "${SOLR_VOLUME}" >/dev/null
  docker compose up -d search
fi

echo "-> Redémarrage d'Alfresco et Share..."
docker compose start alfresco share

echo ""
echo "Restauration terminée. Attendez 2 à 5 minutes (démarrage du Repository),"
echo "puis vérifiez avec : ./scripts/smoke-test.sh --wait"
