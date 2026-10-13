#!/usr/bin/env bash
# Test de fumée : vérifie en 30 secondes que TOUTE la plateforme de formation
# répond (à lancer chaque matin, et avant chaque TP en cas de doute).
#
# Usage : ./scripts/smoke-test.sh            -> un passage
#         ./scripts/smoke-test.sh --wait     -> attend (max 10 min) que le Repository soit prêt
#
# Code retour : 0 = tout est OK ; 1 = au moins un test en échec.
set -uo pipefail
cd "$(dirname "$0")/.."

HOST=localhost
ALF="http://${HOST}:8080/alfresco/api/-default-/public/alfresco/versions/1"
AUTH="admin:admin"
fails=0

ok()   { printf "  [ OK ] %s\n" "$1"; }
ko()   { printf "  [FAIL] %s\n         -> %s\n" "$1" "$2"; fails=$((fails+1)); }
skip() { printf "  [ -- ] %s\n" "$1"; }

http_code() {   # http_code [options curl...] URL
  curl -s -o /dev/null -w '%{http_code}' -m 10 "$@" 2>/dev/null || echo "000"
}

expect_code() { # expect_code "libellé" "codes attendus (séparés par |)" "aide" [curl...] URL
  local label="$1" expected="$2" help="$3"; shift 3
  local code; code=$(http_code "$@")
  if [[ "|${expected}|" == *"|${code}|"* ]]; then ok "${label} (HTTP ${code})"
  else ko "${label} (HTTP ${code}, attendu ${expected})" "${help}"; fi
}

if [ "${1:-}" = "--wait" ]; then
  echo "Attente du démarrage du Repository (max 10 min)..."
  for i in $(seq 1 60); do
    [ "$(http_code "${ALF}/probes/-ready-")" = "200" ] && break
    printf "."; sleep 10
  done
  echo
fi

echo "== 1. Conteneurs =="
for svc in alfresco share postgres activemq transform-core-aio search content-app proxy openldap mailpit; do
  state=$(docker compose ps --format '{{.State}}' "$svc" 2>/dev/null | head -1)
  if [ "$state" = "running" ]; then ok "$svc"; else ko "$svc (état: ${state:-absent})" "docker compose up -d   puis   docker compose logs $svc"; fi
done

echo "== 2. Repository et interfaces =="
expect_code "Repository prêt (probe -ready-)" "200" "Le Repository démarre encore ? Patientez : docker compose logs -f alfresco" "${ALF}/probes/-ready-"
expect_code "Share (page de connexion)"        "200|302" "docker compose logs share" -L "http://${HOST}:8080/share/"
expect_code "Content App (port 8082)"          "200" "docker compose logs content-app" "http://${HOST}:8082/"
expect_code "API Explorer"                     "200|301|302" "Le Repository est-il prêt ?" -L "http://${HOST}:8080/api-explorer/"
expect_code "API REST authentifiée (admin)"    "200" "Mot de passe admin modifié ?" -u "${AUTH}" "${ALF}/nodes/-root-"

echo "== 3. Services techniques =="
if docker compose exec -T postgres pg_isready -U alfresco >/dev/null 2>&1; then ok "PostgreSQL (pg_isready)"; else ko "PostgreSQL" "docker compose logs postgres"; fi
expect_code "ActiveMQ console (8161)"          "200" "docker compose logs activemq" -u admin:admin "http://${HOST}:8161/admin/"
expect_code "Transform : configuration (8091)" "200" "docker compose logs transform-core-aio" "http://${HOST}:8091/transform/config"
solr=$(curl -s -m 10 -H "X-Alfresco-Search-Secret: secret" "http://${HOST}:8083/solr/admin/cores?action=SUMMARY&wt=json" 2>/dev/null)
if echo "$solr" | grep -q '"alfresco"'; then ok "Solr : coeur 'alfresco' présent"; else ko "Solr : coeur 'alfresco' introuvable" "docker compose logs search"; fi

echo "== 4. Protocoles d'accès =="
expect_code "WebDAV (PROPFIND)"                "207" "Vérifier l'URL /alfresco/webdav/" -X PROPFIND -H "Depth: 0" -u "${AUTH}" "http://${HOST}:8080/alfresco/webdav/"
expect_code "CMIS AtomPub"                     "200" "Repository prêt ?" -u "${AUTH}" "http://${HOST}:8080/alfresco/api/-default-/public/cmis/versions/1.1/atom"
ftp_out=$(curl -s -m 10 --disable-epsv --user "${AUTH}" "ftp://${HOST}:2121/" 2>/dev/null)
if echo "$ftp_out" | grep -qi "alfresco"; then ok "FTP (port 2121)"; else ko "FTP (port 2121)" "ftp.enabled=true dans alfresco-global.properties ? ports 2121 et 21000-21010 publiés ?"; fi
imap_out=$(curl -s -m 10 --user "${AUTH}" "imap://${HOST}:1143/" 2>/dev/null)
if echo "$imap_out" | grep -qi "LIST"; then ok "IMAP (port 1143)"; else skip "IMAP (port 1143) : pas de réponse LIST (non bloquant)"; fi

echo "== 5. Annuaire et messagerie de test =="
ldap_out=$(docker compose exec -T openldap ldapsearch -x -H ldap://localhost -D "cn=admin,dc=formation,dc=local" -w admin -b "ou=people,dc=formation,dc=local" "(objectClass=inetOrgPerson)" uid 2>/dev/null)
n=$(echo "$ldap_out" | grep -c '^uid:')
if [ "$n" -ge 4 ]; then ok "OpenLDAP : ${n} utilisateurs"; else ko "OpenLDAP : ${n} utilisateur(s) trouvé(s) (4 attendus)" "docker compose logs openldap ; ldap/bootstrap.ldif monté ?"; fi
expect_code "Mailpit (interface 8025)"         "200" "docker compose logs mailpit" "http://${HOST}:8025/api/v1/info"

echo "== 6. Données du fil rouge =="
site=$(http_code -u "${AUTH}" "${ALF}/sites/qualite-test")
if [ "$site" = "200" ]; then ok "Site qualite-test présent"; else skip "Site qualite-test absent (normal avant le TP1 du Jour 1)"; fi

echo
if [ "$fails" -eq 0 ]; then echo "RÉSULTAT : tout est OK."; exit 0
else echo "RÉSULTAT : ${fails} test(s) en échec — voir ci-dessus."; exit 1; fi
