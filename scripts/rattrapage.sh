#!/usr/bin/env bash
# Script de RATTRAPAGE pour le formateur : recrée l'état attendu à la fin d'un
# jour de formation, pour un stagiaire en retard ou après un incident.
#
# Usage : ./scripts/rattrapage.sh j1     -> site, dossiers, documents (fin du Jour 1)
#         ./scripts/rattrapage.sh j2     -> j1 + utilisateurs, groupe, droits sur Archives (fin du Jour 2)
#
# Prérequis : la pile est démarrée et prête (./scripts/smoke-test.sh), curl et jq installés.
# Le script est idempotent : relancé, il ignore ce qui existe déjà (erreurs 409 ignorées).
set -uo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-}"
[ "$TARGET" = "j1" ] || [ "$TARGET" = "j2" ] || { echo "Usage: $0 j1|j2"; exit 1; }
command -v jq >/dev/null || { echo "jq est requis : sudo apt-get install -y jq"; exit 1; }

API="http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1"
AUTH="admin:admin"
JSON=(-H "Content-Type: application/json")

api() { curl -s -u "$AUTH" "$@"; }

echo "== Rattrapage ${TARGET} =="

echo "-> Site qualite-test"
api -X POST "${JSON[@]}" "$API/sites" \
  -d '{"id":"qualite-test","title":"Qualité-Test","description":"Site du service Qualité (fil rouge)","visibility":"PUBLIC"}' >/dev/null

echo "-> Conteneur documentLibrary"
api -X POST "${JSON[@]}" "$API/sites/qualite-test/containers" -d '{"folderId":"documentLibrary"}' >/dev/null

DL=$(api "$API/nodes/-root-?relativePath=Sites/qualite-test/documentLibrary" | jq -r '.entry.id')
[ -n "$DL" ] && [ "$DL" != "null" ] || { echo "Impossible de trouver documentLibrary"; exit 1; }

mkfolder() {  # mkfolder <parentId> <nom>  -> imprime l'id du dossier (existant ou créé)
  local id
  id=$(api -X POST "${JSON[@]}" "$API/nodes/$1/children" -d "{\"name\":\"$2\",\"nodeType\":\"cm:folder\"}" | jq -r '.entry.id // empty')
  if [ -z "$id" ]; then
    id=$(api "$API/nodes/$1/children?where=(isFolder=true)&maxItems=100" | jq -r ".list.entries[].entry | select(.name==\"$2\") | .id")
  fi
  echo "$id"
}

echo "-> Dossiers Procedures / Enregistrements / Archives"
PROC=$(mkfolder "$DL" "Procedures")
ENR=$(mkfolder "$DL" "Enregistrements")
ARCH=$(mkfolder "$DL" "Archives")

upload() {  # upload <parentId> <fichier>
  local f="$2"
  api -X POST -F "filedata=@${f}" -F "name=$(basename "$f")" -F "autoRename=false" "$API/nodes/$1/children" >/dev/null
}

echo "-> Documents de la procédure"
for f in ressources/documents-qualite/*; do [ -f "$f" ] && upload "$PROC" "$f"; done

if [ "$TARGET" = "j2" ]; then
  echo "-> Utilisateurs anne.moreau et marc.petit"
  for u in "anne.moreau:Anne:Moreau" "marc.petit:Marc:Petit"; do
    IFS=: read -r id fn ln <<<"$u"
    api -X POST "${JSON[@]}" "$API/people" \
      -d "{\"id\":\"$id\",\"firstName\":\"$fn\",\"lastName\":\"$ln\",\"email\":\"$id@formation.local\",\"password\":\"Formation2026\",\"enabled\":true}" >/dev/null
  done

  echo "-> Groupe qualite-lecteurs"
  api -X POST "${JSON[@]}" "$API/groups" -d '{"id":"GROUP_qualite-lecteurs","displayName":"qualite-lecteurs"}' >/dev/null
  for id in anne.moreau marc.petit; do
    api -X POST "${JSON[@]}" "$API/groups/GROUP_qualite-lecteurs/members" -d "{\"id\":\"$id\",\"memberType\":\"PERSON\"}" >/dev/null
  done

  echo "-> Droits sur Archives (héritage coupé, groupe en lecture)"
  api -X PUT "${JSON[@]}" "$API/nodes/$ARCH" -d '{
    "permissions": {
      "isInheritanceEnabled": false,
      "locallySet": [
        {"authorityId":"GROUP_qualite-lecteurs","name":"Consumer","accessStatus":"ALLOWED"},
        {"authorityId":"GROUP_ALFRESCO_ADMINISTRATORS","name":"Coordinator","accessStatus":"ALLOWED"}
      ]
    }}' >/dev/null
fi

echo "Terminé. Vérifiez dans Share : http://localhost:8080/share/page/site/qualite-test/documentlibrary"
