# Environnement de lab — services Docker Compose

Ce dossier documente la pile `docker-compose.yml` à la racine de `sirh-export` :
PostgreSQL, Nexus (Maven + Docker, remplace Artifactory), SonarQube, GitLab CE,
un runner GitLab partagé, Jenkins, et `hote-cible` (l'hôte Docker du « client »
simulé pour A12).

## Pourquoi Nexus et pas Artifactory

L'image `artifactory-jcr` sans licence a deux défauts bloquants, confirmés par
test :
1. Elle ne démarre pas sans base PostgreSQL câblée (refuse Derby).
2. Une fois démarrée, elle refuse la création de **tout** dépôt (Maven comme
   Docker) via l'API : « This REST API is available only in Artifactory Pro ».

Nexus OSS couvre les deux usages (A04 : dépôts Maven hosted/proxy/group créés
par défaut ; A09/A10 : dépôt Docker hosted à créer) sans licence. **Ce
remplacement touche les ateliers A04, A09 et A10 et doit être validé avec le
client** avant de remplacer définitivement les supports qui mentionnent encore
Artifactory.

## RAM nécessaire

| Service | RAM mesurée en fonctionnement | Remarque |
|---|---|---|
| PostgreSQL | ~65 Mo | |
| Nexus | ~1,2 Go (limité par `INSTALL4J_ADD_VM_PARAMS`) | |
| SonarQube | ~2,6 Go | |
| GitLab CE | ~2,5 à 4 Go selon la charge | le plus gourmand, prévoir 4 Go dédiés |
| Jenkins | ~0,5 Go à vide | plus avec un agent Docker actif |
| hote-cible (dind) | ~0,1 Go à vide | plus les conteneurs qu'il héberge |
| gitlab-runner / gitlab-runner (hote-cible) | négligeable au repos | |

**総 recommandé : 16 Go de RAM alloués à Docker Desktop au minimum, 24-32 Go
pour un confort réel si GitLab CE et SonarQube tournent en même temps que des
builds actifs.** Mesuré sur une machine à 32 Go : la pile complète tourne,
mais GitLab CE seul en consomme une part significative au démarrage (3-5 min).

## Ordre de démarrage

GitLab CE est le plus long à démarrer (3-5 min, healthcheck). Démarrer dans
cet ordre pour paralléliser l'attente :

```bash
# depuis la racine du projet sirh-export (là où se trouve docker-compose.yml)

# 1. Les services rapides, en parallèle de GitLab (le plus lent)
docker compose up -d postgres sonarqube hote-cible nexus
docker compose up -d gitlab          # 3-5 min, healthcheck

# 2. Jenkins doit être construit avant de démarrer (image personnalisée)
docker compose build jenkins
docker compose up -d jenkins gitlab-runner

# 3. Vérifier que tout répond
bash lab/verifier-services.sh
```

## Mots de passe / jetons générés au premier démarrage

- **Nexus** : utilisateur `admin`, mot de passe dans
  `MSYS_NO_PATHCONV=1 docker exec <conteneur-nexus> cat /nexus-data/admin.password`
  (préfixe nécessaire sous Git Bash — confirmé par test ;
  à changer au premier login, le fichier disparaît ensuite).
- **GitLab** : utilisateur `root`, mot de passe = `GITLAB_ROOT_PASSWORD`
  (variable d'environnement, défaut `changeme123` — à changer avant toute
  séance réelle, ou passer une vraie valeur via `.env`).
- **Jenkins** : `admin` / `admin1234` (fixés dans
  `lab/jenkins/init.groovy.d/basic-security.groovy`, assistant de
  configuration désactivé). **Lab uniquement**, à ne jamais reproduire
  ailleurs.

## Configurer Nexus (A02/A04/A09/A10)

Nécessaire une fois après chaque démarrage sur un volume `nexus-data` neuf
(premier `docker compose up -d`, ou toute perte de ce volume — **constaté une
fois sans `docker compose down -v` explicite**, probablement un redémarrage de
Docker Desktop/WSL2 qui a recréé le volume : le symptôme est un mot de passe
admin qui ne correspond plus à celui attendu et une liste de dépôts revenue
aux seuls dépôts par défaut de Nexus) :

```bash
bash lab/configurer-nexus.sh
```

Le script attend que Nexus réponde, lit le mot de passe initial dans le
conteneur s'il existe encore (sinon suppose que le mot de passe est déjà celui
qu'il fixe, `admin123` par défaut), le change, puis crée les dépôts Maven
(`sirh-snapshots`, `sirh-releases`, `sirh-promoted`, `sirh-maven-public`) et
le dépôt Docker `sirh-docker` (port 8083), et active le *Docker Bearer Token
Realm* (sinon `docker login` renvoie 401 même avec le bon mot de passe). Il
peut être relancé sans risque : les dépôts déjà existants répondent 400 et
sont ignorés. Reporter le mot de passe affiché en fin de script dans
`NEXUS_TOKEN` (variable d'environnement lue par `~/.m2/settings.xml`, voir A04).

## Enregistrer le runner GitLab partagé (A08)

Nécessaire une fois après chaque `docker compose down -v` (le jeton du runner
ne survit pas à la suppression du volume `gitlab-data`) :

```bash
bash lab/enregistrer-runner-partage.sh
```

Le script attend que GitLab soit prêt, crée un jeton de runner d'instance via
`gitlab-rails runner`, enregistre `gitlab-runner` (executor `docker`, réseau
`sirh-export_default` pour résoudre `gitlab`/`sonarqube`/`nexus` par leur nom
de service), et affiche le jeton généré pour copie dans `.env` si besoin.

### Pièges rencontrés en testant A08, à connaître avant la séance

- **Auto DevOps** est activé par défaut sur un nouveau projet GitLab CE : tant
  qu'aucun `.gitlab-ci.yml` n'existe, GitLab lance sa propre pipeline
  (sécurité, code quality…) qui échoue sans rapport avec l'atelier et peut
  dérouter les stagiaires. Désactiver dans *Settings → CI/CD → Auto DevOps*
  avant l'atelier, ou l'expliquer en une phrase.
- **`CI_REPOSITORY_URL` pointe sur `localhost:8929`** (l'`external_url` réglé
  pour le navigateur du poste), inatteignable depuis les conteneurs de job sur
  le réseau Docker. Le runner est configuré avec `clone_url =
  "http://gitlab:8929"` dans son `config.toml` (fait par le script) — sans ce
  réglage, le clonage échoue avec `Could not connect to server`.
- **Testcontainers (A06) dans un job GitLab CI** : le job tourne lui-même dans
  un conteneur (executor `docker`), qui doit accéder au moteur Docker pour
  lancer `postgres:17` — le runner monte déjà `/var/run/docker.sock` dans les
  conteneurs de job (fait par le script). Il faut en plus dire à Testcontainers
  comment joindre les conteneurs qu'il démarre : `TESTCONTAINERS_HOST_OVERRIDE:
  host.docker.internal` dans les `variables` du `.gitlab-ci.yml` (sinon
  `Connection refused` sur l'adresse de passerelle devinée, ou même échec
  total selon le contexte). Même variable nécessaire côté Jenkins (A11).

## Jenkins (A11)

Image personnalisée dans `lab/jenkins/` (JDK 21 hérité de l'image de base,
Maven, client Docker copié depuis `docker:27-cli` — **le paquet Debian
`docker.io` seul n'inclut plus `/usr/bin/docker`**, vérifié). Le socket Docker
de l'hôte est monté dans le conteneur Jenkins ; l'utilisateur `jenkins` est
ajouté au groupe `root` pour pouvoir s'en servir (le socket appartient à
`root:root` sur Docker Desktop — lab uniquement, à ne pas reproduire en
production).

## Runner sur `hote-cible` (A12)

`hote-cible` (image `docker:dind`) simule l'hôte du client, avec son propre
moteur Docker interne. Le runner qui s'y enregistre doit utiliser l'**executor
`shell`** (pas `docker`) : un executor `docker` créerait les conteneurs de job
*à l'intérieur* du moteur imbriqué de `hote-cible`, qui n'a aucune
connaissance des noms de service du réseau Compose externe (`gitlab`, `nexus`)
— confirmé par test, le clonage échoue sans solution simple. Avec l'executor
`shell`, le script du job tourne directement dans le conteneur du runner, qui
lui *est* sur le réseau Compose et peut résoudre les noms de service ; il lui
suffit de pointer `DOCKER_HOST` vers `tcp://hote-cible:2375` pour que ses
commandes `docker compose ...` s'exécutent sur le moteur de `hote-cible`.

```bash
bash lab/enregistrer-runner-hote-cible.sh
```

Le registre Docker (Nexus, port 8083) est déclaré non sécurisé pour le moteur
de `hote-cible` (`command: ["--insecure-registry=nexus:8083"]` dans
`docker-compose.yml`) — sans cela, le `docker compose pull` du job de
déploiement échoue (pas de TLS en lab).

## Nettoyage complet

```bash
docker compose down -v   # supprime aussi les données GitLab/Nexus/SonarQube
```
