#!/usr/bin/env bash
# Construit le module d'extension : extensions/formation-fournisseur.jar
# Un JAR est une simple archive ZIP : la commande "zip" suffit (pas besoin de Maven).
# Usage (depuis la racine du projet) : ./ressources/module-fournisseur/build.sh
set -euo pipefail
cd "$(dirname "$0")/src"
OUT="$(cd ../../.. && pwd)/extensions/formation-fournisseur.jar"
rm -f "$OUT"
zip -r -X -q "$OUT" alfresco
echo "Module construit : $OUT"
unzip -l "$OUT"
