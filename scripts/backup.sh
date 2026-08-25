#!/usr/bin/env bash
# Sauvegarde cohérente Base de données + Content Store (Module 7, TP "Installation
# et administration de base"). À exécuter depuis le dossier projet-fil-rouge-docker/.
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="./backups/${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

echo "== Sauvegarde Alfresco — ${TIMESTAMP} =="

echo "-> Dump de la base de données PostgreSQL..."
docker compose exec -T postgres pg_dump -U alfresco -d alfresco -F c -f /tmp/alfresco.dump
docker compose cp postgres:/tmp/alfresco.dump "${BACKUP_DIR}/alfresco.dump"

echo "-> Archivage du Content Store (volume alf-repo-data)..."
docker run --rm \
  -v projet-fil-rouge-docker_alf-repo-data:/data:ro \
  -v "$(pwd)/${BACKUP_DIR}":/backup \
  alpine \
  tar czf /backup/content-store.tar.gz -C /data .

echo ""
echo "Sauvegarde terminée : ${BACKUP_DIR}/"
echo "  - alfresco.dump         (base de données)"
echo "  - content-store.tar.gz  (fichiers)"
echo ""
echo "Rappel pédagogique : les deux fichiers doivent TOUJOURS être restaurés"
echo "ensemble, faute de quoi les métadonnées et les fichiers physiques"
echo "deviennent incohérents (voir Manuel du stagiaire, Module 7)."
