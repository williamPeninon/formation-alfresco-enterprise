#!/usr/bin/env bash
# Vérifie que la VM/poste stagiaire respecte les prérequis avant de lancer
# le projet fil rouge (voir Besoins_VM_Outils_Formation_Alfresco).
set -euo pipefail

echo "== Vérification des prérequis — Formation Alfresco Administrateur =="

fail=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[OK]   $label"
  else
    echo "[FAIL] $label"
    fail=1
  fi
}

check "Docker installé"        command -v docker
check "Docker Compose v2"      docker compose version
check "Docker daemon actif"    docker info

total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$total_mem_kb" -eq 0 ]; then
  # macOS fallback
  total_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  total_mem_gb=$(( total_mem_bytes / 1024 / 1024 / 1024 ))
else
  total_mem_gb=$(( total_mem_kb / 1024 / 1024 ))
fi

if [ "$total_mem_gb" -ge 8 ]; then
  echo "[OK]   RAM disponible >= 8 Go (${total_mem_gb} Go détectés)"
else
  echo "[WARN] RAM détectée: ${total_mem_gb} Go — 8 Go minimum recommandés pour la pile complète"
fi

free_space_gb=$(df -Pk . | awk 'NR==2 {print int($4/1024/1024)}')
if [ "$free_space_gb" -ge 20 ]; then
  echo "[OK]   Espace disque libre >= 20 Go (${free_space_gb} Go détectés)"
else
  echo "[WARN] Espace disque libre: ${free_space_gb} Go — 20 Go minimum recommandés (images + volumes)"
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Des prérequis obligatoires sont manquants — voir Besoins_VM_Outils_Formation_Alfresco.pdf"
  exit 1
fi

echo ""
echo "Prérequis techniques satisfaits — vous pouvez lancer : docker compose up -d"
