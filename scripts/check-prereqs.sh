#!/usr/bin/env bash
# Vérifie que la VM/poste stagiaire respecte les prérequis avant de lancer
# le projet fil rouge (voir Besoins_VM_Ubuntu_Alfresco_Fil_Rouge.pdf).
# Usage : ./scripts/check-prereqs.sh
set -uo pipefail

cd "$(dirname "$0")/.."

echo "== Vérification des prérequis — Formation Alfresco Administrateur =="

fail=0
warn=0

check() {            # check "libellé" commande...   (obligatoire)
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[OK]   $label"
  else
    echo "[FAIL] $label"
    fail=1
  fi
}

optional() {         # optional "libellé" commande...   (recommandé)
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[OK]   $label"
  else
    echo "[WARN] $label (recommandé)"
    warn=1
  fi
}

check    "Docker installé"                     command -v docker
check    "Docker Compose v2 (docker compose)"  docker compose version
check    "Docker daemon actif et accessible sans sudo" docker info
check    "Git installé"                        command -v git
check    "curl installé"                       command -v curl
optional "jq installé (lecture des réponses JSON)" command -v jq
optional "zip installé (TP Module 8)"          command -v zip
optional "unzip installé"                      command -v unzip

# --- Mémoire ----------------------------------------------------------------
total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$total_mem_kb" -eq 0 ]; then
  total_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)       # macOS
  total_mem_gb=$(( total_mem_bytes / 1024 / 1024 / 1024 ))
else
  total_mem_gb=$(( total_mem_kb / 1024 / 1024 ))
fi
if [ "$total_mem_gb" -ge 8 ]; then
  echo "[OK]   RAM >= 8 Go (${total_mem_gb} Go détectés)"
else
  echo "[WARN] RAM détectée: ${total_mem_gb} Go — 8 Go minimum, 16 Go recommandés pour la pile complète"
  warn=1
fi

# --- Disque -----------------------------------------------------------------
free_space_gb=$(df -Pk . | awk 'NR==2 {print int($4/1024/1024)}')
if [ "$free_space_gb" -ge 40 ]; then
  echo "[OK]   Espace disque libre >= 40 Go (${free_space_gb} Go détectés)"
else
  echo "[WARN] Espace disque libre: ${free_space_gb} Go — 40 Go recommandés (images + volumes + sauvegardes)"
  warn=1
fi

# --- Ports ------------------------------------------------------------------
# Les ports utilisés par la pile doivent être libres AVANT le premier démarrage.
if docker compose ps -q 2>/dev/null | grep -q .; then
  echo "[INFO] Une pile est déjà démarrée : contrôle des ports ignoré."
else
  busy=""
  for p in 8080 8081 8082 8083 8091 8161 5433 2121 1143 3389 8025; do
    if (command -v ss >/dev/null 2>&1 && ss -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN) \
       || (command -v lsof >/dev/null 2>&1 && lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1); then
      busy="$busy $p"
    fi
  done
  if [ -z "$busy" ]; then
    echo "[OK]   Ports 8080 8081 8082 8083 8091 8161 5433 2121 1143 3389 8025 libres"
  else
    echo "[FAIL] Ports déjà utilisés :$busy"
    fail=1
  fi
fi

# --- Accès Internet (téléchargement des images) -------------------------------
optional "Accès à Docker Hub (registry-1.docker.io)" curl -sS -m 8 -o /dev/null https://registry-1.docker.io/v2/

echo ""
if [ "$fail" -ne 0 ]; then
  echo "Des prérequis obligatoires sont manquants — voir Besoins_VM_Ubuntu_Alfresco_Fil_Rouge.pdf"
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "Prérequis obligatoires OK (avertissements ci-dessus à examiner)."
else
  echo "Prérequis techniques satisfaits."
fi
echo "Étape suivante : docker compose pull   puis   docker compose up -d"
