#!/usr/bin/env bash
# Configure Nexus pour les ateliers 2/4/9/10 : change le mot de passe admin,
# crée les dépôts Maven (sirh-snapshots, sirh-releases, sirh-promoted,
# sirh-maven-public) et le dépôt Docker (sirh-docker, port 8083), active le
# Docker Bearer Token Realm (sinon docker login échoue en 401).
#
# À lancer une fois après tout démarrage de Nexus sur un volume neuf (premier
# `docker compose up -d`, ou après un `docker compose down -v`/perte du
# volume `*_nexus-data` — ça arrive même sans -v explicite).
# Démarche vérifiée manuellement pas à pas (revalidation du 2026-11-02) ;
# ce script la rejoue. Peut être relancé : les dépôts déjà existants
# répondent 400 et sont ignorés (set -e ne s'applique pas au code HTTP,
# seulement à un échec de curl lui-même).
set -euo pipefail

NEXUS=${NEXUS_CONTAINER:-sirh-export-nexus-1}
NEXUS_URL=${NEXUS_URL:-http://localhost:8081}
NOUVEAU_MDP=${1:-admin123}

echo "Attente de Nexus ($NEXUS_URL)..."
until curl -s -o /dev/null "$NEXUS_URL/service/rest/v1/status"; do sleep 3; done

MDP_INITIAL=$(MSYS_NO_PATHCONV=1 docker exec "$NEXUS" cat /nexus-data/admin.password 2>/dev/null || true)
if [ -n "$MDP_INITIAL" ]; then
  echo "Mot de passe initial détecté (premier démarrage) : changement vers le mot de passe connu."
  curl -s -o /dev/null -w "change-password: %{http_code}\n" -u "admin:$MDP_INITIAL" \
    -X PUT -H "Content-Type: text/plain" --data-raw "$NOUVEAU_MDP" \
    "$NEXUS_URL/service/rest/v1/security/users/admin/change-password"
else
  echo "Pas de mot de passe initial (Nexus déjà configuré) : on suppose que le mot de passe admin est déjà '$NOUVEAU_MDP'."
fi

AUTH="admin:$NOUVEAU_MDP"
MAVEN_BASE="$NEXUS_URL/service/rest/v1/repositories/maven"

creer_maven_hosted() {
  local nom=$1 politique=$2 ecriture=$3
  curl -s -o /dev/null -w "$nom: %{http_code}\n" -u "$AUTH" -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"$nom\",\"online\":true,\"storage\":{\"blobStoreName\":\"default\",\"strictContentTypeValidation\":true,\"writePolicy\":\"$ecriture\"},\"maven\":{\"versionPolicy\":\"$politique\",\"layoutPolicy\":\"STRICT\"}}" \
    "$MAVEN_BASE/hosted"
}

creer_maven_hosted sirh-snapshots SNAPSHOT ALLOW
creer_maven_hosted sirh-releases RELEASE ALLOW_ONCE
creer_maven_hosted sirh-promoted RELEASE ALLOW_ONCE

curl -s -o /dev/null -w "sirh-maven-public: %{http_code}\n" -u "$AUTH" -X POST -H "Content-Type: application/json" \
  -d '{"name":"sirh-maven-public","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":true},"group":{"memberNames":["sirh-releases","sirh-snapshots","maven-central"]}}' \
  "$MAVEN_BASE/group"

curl -s -o /dev/null -w "sirh-docker: %{http_code}\n" -u "$AUTH" -X POST -H "Content-Type: application/json" \
  -d '{"name":"sirh-docker","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":true,"writePolicy":"ALLOW"},"docker":{"v1Enabled":false,"forceBasicAuth":true,"httpPort":8083}}' \
  "$NEXUS_URL/service/rest/v1/repositories/docker/hosted"

curl -s -o /dev/null -w "realm Docker Bearer Token: %{http_code}\n" -u "$AUTH" -X PUT -H "Content-Type: application/json" \
  -d '["NexusAuthenticatingRealm","DockerToken"]' \
  "$NEXUS_URL/service/rest/v1/security/realms/active"

echo "Terminé. Mot de passe admin : $NOUVEAU_MDP (à reporter dans NEXUS_TOKEN et ~/.m2/settings.xml)."
