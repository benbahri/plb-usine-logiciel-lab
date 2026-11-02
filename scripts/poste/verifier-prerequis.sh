#!/usr/bin/env bash
# Vérifie le poste (Git Bash sous Windows, ou Linux/macOS) pour la formation sirh-export.
# Usage : bash verifier-prerequis.sh        Code retour : 0 = OK, 1 = bloquant
fail=0
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$1"; }
ko()   { printf '\033[31m[FAIL]\033[0m %s\n' "$1"; fail=$((fail+1)); }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

# Git >= 2.40
if v=$(git --version 2>/dev/null); then
  maj=$(sed -E 's/[^0-9]*([0-9]+)\.([0-9]+).*/\1/' <<<"$v"); min=$(sed -E 's/[^0-9]*([0-9]+)\.([0-9]+).*/\2/' <<<"$v")
  if [ "$maj" -gt 2 ] || { [ "$maj" -eq 2 ] && [ "$min" -ge 40 ]; }; then ok "$v"; else ko "$v (>= 2.40 requis)"; fi
else ko "Git absent"; fi

# Visual Studio Code (non bloquant : tout autre éditeur convient)
if command -v code >/dev/null; then ok "VS Code : $(code --version 2>/dev/null | head -1)"; else warn "VS Code absent ou 'code' hors PATH (rouvrir le terminal après l'installation)"; fi

# Java 21
if v=$(java -version 2>&1 | head -1) && command -v java >/dev/null; then
  if grep -q '"21\.' <<<"$v"; then ok "Java : $v"; else ko "Java : $v (21 requis)"; fi
else ko "Java absent (JDK 21 requis)"; fi

# Maven (facultatif avec le conteneur)
if command -v mvn >/dev/null; then
  v=$(mvn -v 2>&1 | head -1)
  if grep -Eq 'Apache Maven 3\.(9|[1-9][0-9])' <<<"$v"; then ok "$v"; else warn "$v (3.9+ recommandé)"; fi
else warn "Maven absent : utiliser le conteneur maven:3.9-eclipse-temurin-21"; fi

# Docker
if command -v docker >/dev/null; then
  ok "$(docker --version)"
  if docker info >/dev/null 2>&1; then
    ok "Démon Docker joignable"
    docker compose version >/dev/null 2>&1 && ok "$(docker compose version)" || ko "Docker Compose v2 absent"
    mem=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
    if [ -n "$mem" ]; then
      go=$(( mem / 1024 / 1024 / 1024 ))
      if [ "$go" -ge 7 ]; then ok "Mémoire allouée à Docker : ~${go} Go"; else ko "Mémoire allouée à Docker : ~${go} Go (8 Go minimum, 16 Go recommandés pour la pile complète ; .wslconfig [wsl2] memory=16GB)"; fi
    fi
  else ko "Le démon Docker ne répond pas (lancer Docker Desktop)"; fi
else ko "Docker absent"; fi

# Ports du lab (netstat sous Git Bash/Windows, ss ou lsof ailleurs)
listening() {
  if command -v netstat >/dev/null; then netstat -an 2>/dev/null | grep -E "[:.]$1 .*LISTEN" >/dev/null
  elif command -v ss >/dev/null; then ss -ltn 2>/dev/null | grep -E ":$1 " >/dev/null
  else lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; fi
}
for p in 5432 8080 8081 8083 8090 8091 8929 9000; do
  if listening "$p"; then warn "Port $p déjà utilisé"; else ok "Port $p libre"; fi
done

# Accès sortant
for u in https://repo.maven.apache.org/maven2/ https://registry-1.docker.io/v2/; do
  code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$u")
  if [ "$code" != "000" ]; then ok "Accès à $u (HTTP $code)"; else warn "Pas d'accès à $u (proxy ?)"; fi
done

echo
if [ "$fail" -eq 0 ]; then echo "Poste prêt."; exit 0; fi
echo "$fail élément(s) bloquant(s). Voir installer-outils.sh"; exit 1
