#!/usr/bin/env bash
# Installe les outils depuis Git Bash sous Windows (délègue à winget via PowerShell).
# Git Bash est livré avec Git for Windows : si ce script tourne, il est déjà là.
# Outils : Git, Visual Studio Code, JDK 21, Docker Desktop (winget), Maven (installer-maven.ps1).
# Usage : bash installer-outils.sh [--sans-docker] [--dry-run]
# Les identifiants winget n'ont pas été testés depuis le poste de rédaction.
set -u
sans_docker=0; dry=0
for a in "$@"; do case "$a" in --sans-docker) sans_docker=1;; --dry-run) dry=1;; esac; done

if ! command -v winget >/dev/null 2>&1 && ! command -v winget.exe >/dev/null 2>&1; then
  echo "winget introuvable (Windows 10/11 requis). Installer les outils manuellement."; exit 1
fi

installer() { # nom id commande
  if command -v "$3" >/dev/null 2>&1; then echo "[skip] $1 déjà présent"; return; fi
  echo "[inst] $1 ($2)"
  [ "$dry" -eq 1 ] && return
  winget.exe install --id "$2" -e --accept-source-agreements --accept-package-agreements \
    || echo "Échec pour $1 (vérifier 'winget search')"
}

installer "Git (inclut Git Bash)" Git.Git git
installer "Visual Studio Code" Microsoft.VisualStudioCode code
installer "JDK 21 (Temurin)" EclipseAdoptium.Temurin.21.JDK java
# Maven : pas de paquet winget fiable, installation directe depuis Maven Central (script PowerShell)
if command -v mvn >/dev/null 2>&1; then echo "[skip] Maven déjà présent"; else
  echo "[inst] Maven (Maven Central)"
  if [ "$dry" -eq 0 ]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$(dirname "$0")/installer-maven.ps1")" \
      || echo "Échec pour Maven (voir installer-maven.ps1, ou utiliser le conteneur Maven)"
  fi
fi
[ "$sans_docker" -eq 0 ] && installer "Docker Desktop" Docker.DockerDesktop docker

echo
echo "Rouvrir Git Bash (PATH), lancer Docker Desktop une fois, puis : bash verifier-prerequis.sh"
