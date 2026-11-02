# sirh-export — projet fil rouge de la formation

Export de paie au format texte à colonnes fixes (format **pédagogique**, pas le format Sage réel).
Projet Maven multi-module, Java 21, Spring Boot 4.0.9. Ce dossier vous est fourni séparément
des énoncés d'ateliers : **toutes les commandes se lancent depuis sa racine** (là où se trouve ce
fichier), sauf indication contraire.

## Arborescence

```
sirh-export/
├── README.md                    ce fichier
├── pom.xml                      POM parent : versions, modules, BOM
├── sirh-export-core/            modèle (Salarie, ElementDePaie, ExportException)
├── sirh-export-format-sage/     format d'export (ExportPaie)        → dépend de core
├── sirh-export-api/             API REST Spring Boot + Swagger UI   → dépend de format-sage
├── Dockerfile                   image de l'API (multi-stage)
├── docker-compose.yml           environnement de lab (voir lab/README.md)
├── .env.example                 à copier en .env (jamais versionné)
├── docs/
│   └── guide-installation.md    prérequis du poste, aide-mémoire des commandes
├── scripts/
│   ├── poste/                   installation et vérification du poste (Windows / Git Bash)
│   └── ateliers/                préparation d'un atelier (preparer-atelier-01.sh)
└── lab/                         services Docker : Nexus, SonarQube, GitLab CE, Jenkins, runners
    ├── README.md                ordre de démarrage, RAM, mots de passe, pièges
    ├── verifier-services.sh
    ├── enregistrer-runner-*.sh
    └── jenkins/                 image Jenkins personnalisée
```

## Démarrage

```bash
bash scripts/poste/verifier-prerequis.sh      # ou scripts\poste\verifier-prerequis.ps1 sous PowerShell
cp .env.example .env
docker compose up -d                          # voir lab/README.md pour l'ordre complet
mvn -B verify                                 # 4 tests attendus
```

## Où se passent les ateliers

| Atelier | Dossier / outil |
|---|---|
| A01 Git avancé | dépôt jetable `~/lab-git`, créé par `scripts/ateliers/preparer-atelier-01.sh` |
| A02 Prise en main | racine du projet, `docker-compose.yml`, `.env` |
| A03 Réacteur Maven | `pom.xml` parent et trois modules |
| A04, A09, A10 | `pom.xml` (publication), `Dockerfile`, Nexus (`lab/`) |
| A05, A06, A13, A14 | tests des modules `format-sage` et `api` |
| A07, A08, A11 | `.gitlab-ci.yml` et `Jenkinsfile` à créer à la racine ; SonarQube, GitLab, Jenkins (`lab/`) |
| A12 | `deploy/docker-compose.yml` à créer ; `hote-cible` (`lab/`) |
