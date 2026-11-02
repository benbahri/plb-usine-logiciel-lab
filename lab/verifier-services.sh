#!/usr/bin/env bash
# Vérifie que tous les services de la pile de lab répondent.
# Usage : bash lab/verifier-services.sh
set -uo pipefail

ok=0
ko=0

verifier() {
  local nom="$1" url="$2" attendu="${3:-200}"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null)
  if [ "$code" = "$attendu" ]; then
    echo "OK   $nom ($url -> $code)"
    ok=$((ok + 1))
  else
    echo "KO   $nom ($url -> $code, attendu $attendu)"
    ko=$((ko + 1))
  fi
}

echo "=== Services HTTP ==="
verifier "Nexus"               "http://localhost:8081/service/rest/v1/status"
verifier "SonarQube"            "http://localhost:9000/api/system/status"
verifier "GitLab"               "http://localhost:8929/users/sign_in"
verifier "Jenkins"              "http://localhost:8090/login"

echo ""
echo "=== PostgreSQL ==="
if docker compose exec -T postgres psql -U sirh -c 'select 1' >/dev/null 2>&1; then
  echo "OK   PostgreSQL (select 1)"
  ok=$((ok + 1))
else
  echo "KO   PostgreSQL (select 1)"
  ko=$((ko + 1))
fi

echo ""
echo "=== Runners GitLab ==="
echo "   (vérifier manuellement : GitLab -> Admin -> CI/CD -> Runners, ou"
echo "    docker exec <conteneur-gitlab-runner> gitlab-runner verify)"

echo ""
echo "=== hote-cible (dind) ==="
if docker exec sirh-export-hote-cible-1 docker version >/dev/null 2>&1; then
  echo "OK   hote-cible répond à 'docker version' en interne"
  ok=$((ok + 1))
else
  echo "KO   hote-cible ne répond pas"
  ko=$((ko + 1))
fi

echo ""
echo "=== Résumé : $ok OK, $ko KO ==="
[ "$ko" -eq 0 ]
