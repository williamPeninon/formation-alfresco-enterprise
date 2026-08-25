#!/usr/bin/env bash
# Restauration Base de données + Content Store à partir d'une sauvegarde
# produite par backup.sh. Usage : ./scripts/restore.sh backups/20260907-143000
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <dossier-de-sauvegarde>"
  echo "Exemple: $0 backups/20260907-143000"
  exit 1
fi

BACKUP_DIR="$1"

if [ ! -f "${BACKUP_DIR}/alfresco.dump" ] || [ ! -f "${BACKUP_DIR}/content-store.tar.gz" ]; then
  echo "Sauvegarde incomplète dans ${BACKUP_DIR} — les deux fichiers sont requis."
  exit 1
fi

echo "== Restauration Alfresco depuis ${BACKUP_DIR} =="
echo "ATTENTION : ceci écrase les données actuelles du conteneur."
read -r -p "Continuer ? (o/N) " confirm
if [[ ! "$confirm" =~ ^[oO]$ ]]; then
  echo "Annulé."
  exit 0
fi

echo "-> Arrêt d'Alfresco (le conteneur Postgres reste actif)..."
docker compose stop alfresco share

echo "-> Restauration de la base de données..."
docker compose cp "${BACKUP_DIR}/alfresco.dump" postgres:/tmp/alfresco.dump
docker compose exec -T postgres bash -c "
  dropdb -U alfresco alfresco &&
  createdb -U alfresco alfresco &&
  pg_restore -U alfresco -d alfresco /tmp/alfresco.dump
"

echo "-> Restauration du Content Store..."
docker run --rm \
  -v projet-fil-rouge-docker_alf-repo-data:/data \
  -v "$(pwd)/${BACKUP_DIR}":/backup \
  alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/content-store.tar.gz -C /data"

echo "-> Redémarrage d'Alfresco..."
docker compose start alfresco share

echo ""
echo "Restauration terminée."
