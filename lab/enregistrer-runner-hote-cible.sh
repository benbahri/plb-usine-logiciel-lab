#!/usr/bin/env bash
# Enregistre un second runner (A12), tag client-recette, qui exécute ses
# jobs sur le moteur Docker de hote-cible (le « client » simulé) plutôt que
# sur celui de l'hôte de formation.
#
# Executor shell, pas docker : un executor docker créerait les conteneurs de
# job à l'intérieur du moteur imbriqué de hote-cible, qui ne connaît pas les
# noms de service du réseau Compose externe (gitlab, nexus) — confirmé par
# test, le clonage échoue. Avec l'executor shell, le script du job tourne
# dans le conteneur du runner lui-même (sur le réseau Compose), avec
# DOCKER_HOST pointé vers hote-cible pour que ses commandes "docker
# compose ..." s'exécutent bien sur le moteur de hote-cible.
#
# Prend en argument le jeton d'accès personnel root créé par
# enregistrer-runner-partage.sh (ou en recrée un si absent).
set -euo pipefail

GITLAB=sirh-export-gitlab-1
GITLAB_URL="http://localhost:8929"
PROJECT_ID="${2:-1}"
PAT="${1:-}"

if [ -z "$PAT" ]; then
  PAT=$(docker exec "$GITLAB" gitlab-rails runner "
token = User.find_by_username('root').personal_access_tokens.create(
  scopes: [:api, :read_repository, :write_repository],
  name: 'automation-hote-cible',
  expires_at: 30.days.from_now
)
puts token.token
" 2>&1 | tail -1)
fi

RUNNER_TOKEN=$(curl -s -X POST "$GITLAB_URL/api/v4/user/runners" \
  -H "PRIVATE-TOKEN: $PAT" \
  -d "runner_type=project_type&project_id=$PROJECT_ID&description=runner-hote-cible&tag_list=client-recette&run_untagged=false" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

docker rm -f runner-hote-cible >/dev/null 2>&1 || true
docker run -d --name runner-hote-cible --network sirh-export_default \
  -e DOCKER_HOST=tcp://hote-cible:2375 \
  gitlab/gitlab-runner:latest

# Image basée sur Debian (via gitlab-runner) : docker.io fournit bien
# /usr/bin/docker ici (vérifié), à la différence de l'image Jenkins
# (jenkins/jenkins:lts-jdk21, Debian différent — voir lab/jenkins/Dockerfile).
# docker.io n'embarque PAS le plugin "docker compose" (paquet docker-compose-plugin,
# absent des dépôts Debian par défaut) — confirmé par test : le job de déploiement
# (A12) échoue avec "unknown command: docker compose". Le binaire est donc extrait
# de l'image officielle docker:27-cli, comme pour le client docker de Jenkins.
docker exec -u root runner-hote-cible sh -c \
  'apt-get update >/dev/null 2>&1 && apt-get install -y --no-install-recommends docker.io >/dev/null 2>&1'
docker exec -u root runner-hote-cible mkdir -p /usr/libexec/docker/cli-plugins
tmp_cli="$(docker create docker:27-cli)"
docker cp "$tmp_cli:/usr/local/libexec/docker/cli-plugins/docker-compose" /tmp/docker-compose-plugin-hote-cible
docker rm -f "$tmp_cli" >/dev/null
docker cp /tmp/docker-compose-plugin-hote-cible runner-hote-cible:/usr/libexec/docker/cli-plugins/docker-compose
docker exec -u root runner-hote-cible chmod +x /usr/libexec/docker/cli-plugins/docker-compose
rm -f /tmp/docker-compose-plugin-hote-cible

docker exec runner-hote-cible gitlab-runner register --non-interactive \
  --url "http://gitlab:8929" \
  --token "$RUNNER_TOKEN" \
  --executor "shell" \
  --description "runner-hote-cible"

docker exec runner-hote-cible sh -c \
  'sed -i "/executor = \"shell\"/a\\  clone_url = \"http://gitlab:8929\"" /etc/gitlab-runner/config.toml'

echo "Runner hote-cible (tag client-recette) enregistré."
