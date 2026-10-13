#!/usr/bin/env bash
# Sauvegarde cohérente Base de données + Content Store (Module 7).
# À lancer depuis n'importe où : le script se place tout seul à la racine du projet.
#
# Ordre volontaire : 1) base de données  2) content store.
# Le content store ne fait que grossir : si des fichiers arrivent entre les deux
# étapes, ils seront sauvegardés sans être référencés (inoffensif). L'inverse
# (métadonnées sans fichier) serait une incohérence grave.
set -euo pipefail

cd "$(dirname "$0")/.."

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="./backups/${TIMESTAMP}"

# Le nom du volume dépend du nom du dossier du projet : on le retrouve
# automatiquement à partir du conteneur "alfresco".
ALF_CID=$(docker compose ps -a -q alfresco)
if [ -z "${ALF_CID}" ]; then
  echo "ERREUR : le conteneur alfresco n'existe pas. Lancez d'abord : docker compose up -d" >&2
  exit 1
fi
CONTENT_VOLUME=$(docker inspect "${ALF_CID}" \
  --format '{{range .Mounts}}{{if eq .Destination "/usr/local/tomcat/alf_data"}}{{.Name}}{{end}}{{end}}')
if [ -z "${CONTENT_VOLUME}" ]; then
  echo "ERREUR : volume du content store introuvable." >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
echo "== Sauvegarde Alfresco — ${TIMESTAMP} =="
echo "   Volume du content store : ${CONTENT_VOLUME}"

echo "-> Dump de la base de données PostgreSQL..."
docker compose exec -T postgres pg_dump -U alfresco -d alfresco -F c -f /tmp/alfresco.dump
docker compose cp postgres:/tmp/alfresco.dump "${BACKUP_DIR}/alfresco.dump"

echo "-> Archivage du Content Store (volume ${CONTENT_VOLUME})..."
docker run --rm \
  -v "${CONTENT_VOLUME}":/data:ro \
  -v "$(pwd)/${BACKUP_DIR}":/backup \
  alpine \
  tar czf /backup/content-store.tar.gz -C /data .

echo ""
echo "Sauvegarde terminée : ${BACKUP_DIR}/"
ls -lh "${BACKUP_DIR}"
echo ""
echo "  - alfresco.dump         (base de données)"
echo "  - content-store.tar.gz  (fichiers)"
echo ""
echo "Rappel pédagogique : les deux fichiers doivent TOUJOURS être restaurés"
echo "ensemble, faute de quoi les métadonnées et les fichiers physiques"
echo "deviennent incohérents (voir Manuel du stagiaire, Module 7)."
echo "L'index de recherche (Solr) n'est PAS sauvegardé : il se reconstruit."
