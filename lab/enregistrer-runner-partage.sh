#!/usr/bin/env bash
# Enregistre le runner GitLab partagé (A08) : attend que GitLab soit prêt,
# crée un jeton d'accès personnel root (console Rails) puis un jeton de
# runner d'instance (API), enregistre gitlab-runner en executor docker sur
# le réseau sirh-export_default (pour résoudre gitlab/sonarqube/nexus par
# leur nom de service), et règle clone_url (CI_REPOSITORY_URL pointe sur
# localhost, inatteignable depuis les conteneurs de job).
#
# Démarche vérifiée manuellement pas à pas ; ce script la rejoue.
set -euo pipefail

GITLAB=sirh-export-gitlab-1
RUNNER=sirh-export-gitlab-runner-1
GITLAB_URL="http://localhost:8929"

echo "Attente de GitLab (peut prendre plusieurs minutes au premier démarrage)..."
until docker exec "$GITLAB" gitlab-rails runner "puts 'ready'" >/dev/null 2>&1; do
  sleep 5
done

PAT=$(docker exec "$GITLAB" gitlab-rails runner "
token = User.find_by_username('root').personal_access_tokens.create(
  scopes: [:api, :read_repository, :write_repository],
  name: 'automation',
  expires_at: 30.days.from_now
)
puts token.token
" 2>&1 | tail -1)
echo "Jeton d'accès personnel root créé (non affiché)."

RUNNER_TOKEN=$(curl -s -X POST "$GITLAB_URL/api/v4/user/runners" \
  -H "PRIVATE-TOKEN: $PAT" \
  -d "runner_type=instance_type&description=runner-partage&tag_list=docker&run_untagged=true" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

docker exec "$RUNNER" gitlab-runner register --non-interactive \
  --url "http://gitlab:8929" \
  --token "$RUNNER_TOKEN" \
  --executor "docker" \
  --docker-image "maven:3.9-eclipse-temurin-21" \
  --docker-network-mode "sirh-export_default" \
  --description "runner-partage"

# clone_url : CI_REPOSITORY_URL dérive de external_url (localhost:8929, pour
# le navigateur), inatteignable depuis un conteneur de job sur le réseau
# Compose. Sans ce réglage, le clonage échoue ("Could not connect to server").
docker exec "$RUNNER" sh -c \
  'sed -i "/executor = \"docker\"/a\\  clone_url = \"http://gitlab:8929\"" /etc/gitlab-runner/config.toml'

# Socket Docker dans les conteneurs de job eux-mêmes (pas seulement dans le
# conteneur du runner) : nécessaire pour Testcontainers (A06). Voir aussi
# TESTCONTAINERS_HOST_OVERRIDE à déclarer dans .gitlab-ci.yml (lab/README.md).
docker exec "$RUNNER" sh -c \
  'sed -i "s#volumes = \[\"/cache\"\]#volumes = [\"/cache\", \"/var/run/docker.sock:/var/run/docker.sock\"]#" /etc/gitlab-runner/config.toml'

echo "Runner partagé enregistré. Jeton d'accès personnel root (à garder, expire dans 30 jours) :"
echo "$PAT"
