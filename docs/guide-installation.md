# Guide stagiaire — installation et aide-mémoire

## Prérequis poste
- Docker Desktop avec 8 Go de RAM au minimum (16 Go recommandés pour la pile complète avec GitLab CE : voir `lab/README.md`), Git ≥ 2.40 (avec **Git Bash** sous Windows), **Visual Studio Code**, accès GitLab.
- Sous Windows, tous les ateliers se lancent depuis **Git Bash** (pas depuis `cmd` ni PowerShell) : les commandes du support sont en bash.
- Java 21 + Maven 3.9 **ou** utiliser le conteneur : `MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD":/w -w /w maven:3.9-eclipse-temurin-21 mvn -B verify` (le préfixe `MSYS_NO_PATHCONV=1` est **obligatoire** sous Git Bash). **À partir de l'atelier 6** (le projet contient alors `PersistanceIT`, qui démarre un PostgreSQL via Testcontainers), cette commande ne suffit plus : ajouter `-v /var/run/docker.sock:/var/run/docker.sock -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal`, sinon `ContainerFetchException: Can't get Docker image` (confirmé par test). Commande complète valable à tout moment du parcours :
  ```bash
  MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$PWD":/w -w /w \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal \
    maven:3.9-eclipse-temurin-21 mvn -B verify
  ```

## Démarrer
```bash
cp .env.example .env     # renseigner le mot de passe PostgreSQL (versions d'images fournies en séance si besoin)
docker compose up -d
```
Nexus http://localhost:8081 · SonarQube http://localhost:9000 · GitLab http://localhost:8929 · Jenkins http://localhost:8090 (détails et ordre de démarrage : `lab/README.md`)

## Aide-mémoire
| Besoin | Commande |
|---|---|
| Ordre du réacteur | `mvn validate` |
| Un module et ses dépendances | `mvn -pl <module> -am verify` |
| Les dépendants d'un module | `mvn -pl <module> -amd test` |
| Rebase interactif | `git rebase -i $(git merge-base main HEAD)` |
| Reporter un commit | `git cherry-pick <hash>` |
| Annuler un rebase | `git rebase --abort` |
| Rebaser en vérifiant le build à chaque commit | `git rebase main --exec "mvn -B -q verify"` |
| Réinitialiser le dépôt de l'atelier A01 | `bash scripts/ateliers/preparer-atelier-01.sh` |
| Déploiement Compose | `docker compose pull && docker compose up -d` |

## Scripts du poste (dossier `scripts/poste/`, à lancer depuis la racine du projet)
| Besoin | PowerShell | Git Bash |
|---|---|---|
| Installer Git (avec Git Bash), VS Code, JDK 21, Maven, Docker Desktop (winget) | `powershell -ExecutionPolicy Bypass -File .\scripts\poste\installer-outils.ps1` | `bash scripts/poste/installer-outils.sh` |
| Vérifier le poste | `powershell -ExecutionPolicy Bypass -File .\scripts\poste\verifier-prerequis.ps1` | `bash scripts/poste/verifier-prerequis.sh` |

Maven n'a pas de paquet winget fiable : l'installeur le télécharge depuis Maven Central (somme SHA-512 vérifiée) dans `%LOCALAPPDATA%\Programs` via `scripts/poste/installer-maven.ps1`, sans droits administrateur. Rouvrir le terminal ensuite (`mvn -v`). En cas d'échec, utiliser le conteneur Maven indiqué plus haut.

Options d'installation : `-SansDocker` / `-DryRun` (ps1), `--sans-docker` / `--dry-run` (sh). Docker Desktop demande WSL2 (`wsl --install` en administrateur) et peut exiger un redémarrage ; réserver la mémoire (`%UserProfile%\.wslconfig` : `[wsl2]` `memory=16GB` pour la pile complète, `8GB` au minimum).

## Git Bash et VS Code
- **Git Bash** est installé avec Git for Windows. Ouvrir : menu Démarrer → « Git Bash », ou clic droit dans un dossier → *Open Git Bash here*.
- **VS Code** : `code .` ouvre le dossier courant. Pour faire de Git Bash le terminal intégré : `Ctrl+Maj+P` → *Terminal: Select Default Profile* → *Git Bash*.
- Éditeur des commits et des rebases interactifs (atelier 1) : `git config --global core.editor "code --wait"`.
- Ne pas confondre avec `bash.exe` de WSL : dans Git Bash, `uname -o` doit répondre `Msys`.
