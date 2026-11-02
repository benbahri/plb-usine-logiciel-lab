# Glossaire — les notions utilisées dans les ateliers

Ce document explique en mots simples les termes qui reviennent dans les ateliers. Vous n'avez pas besoin de savoir programmer en Java pour suivre la formation : on lit du code, on le modifie à la marge, mais l'objectif est de comprendre **comment il est construit, testé et livré**.

## Le projet en une phrase
`sirh-export` transforme une liste d'**éléments de paie** (une prime, une retenue…) en un fichier texte où chaque ligne a toujours la même largeur. C'est ce type de fichier qu'un logiciel de paie sait importer. Le format de la formation est **inventé pour l'occasion** (ce n'est pas le format Sage réel).

Exemple de ligne produite (62 caractères, sans séparateur entre les colonnes) :
```
M0001   DURAND              PRIME1       123452026100120261031
```
Elle se lit ainsi :

| Colonnes | Largeur | Contenu | Dans l'exemple |
|---|---|---|---|
| 1 à 8 | 8 | matricule, complété par des espaces à droite | `M0001   ` |
| 9 à 28 | 20 | nom, complété par des espaces (coupé au-delà de 20) | `DURAND              ` |
| 29 à 34 | 6 | code de l'élément de paie | `PRIME1` |
| 35 à 46 | 12 | montant en centimes, cadré à droite | `       12345` |
| 47 à 54 | 8 | date de début `aaaammjj` | `20261001` |
| 55 à 62 | 8 | date de fin `aaaammjj` | `20261031` |

Le montant est écrit en **centimes** (123,45 € → `12345`), cadré à droite. Les dates sont au format `aaaammjj`.

## Java : ce qu'il faut savoir lire
| Terme | Ce que c'est | Où le voir dans le projet |
|---|---|---|
| **Classe** | Un fichier `.java` qui regroupe des données et du comportement. Le nom du fichier est celui de la classe. | `ExportPaie.java` |
| **Record** | Une classe très courte qui ne fait que porter des données. Une ligne suffit à déclarer ses champs. | `Salarie.java`, `ElementDePaie.java` |
| **Méthode** | Une fonction rattachée à une classe. | `exporter(...)`, `ligne(...)` dans `ExportPaie` |
| **Exception** | Un signal d'erreur « je refuse de continuer ». `throw` la déclenche. | `ExportException` : levée si le matricule est vide |
| **Package** | Un « dossier logique » (`fr.plb.sirh`) qui range les classes. Il correspond à l'arborescence `fr/plb/sirh/`. | en-tête de chaque fichier |
| **Annotation** | Une étiquette `@Quelquechose` posée sur une classe ou méthode pour lui donner un rôle. | `@Test`, `@RestController`, `@PostMapping` |
| **BigDecimal** | Un nombre décimal exact, utilisé pour l'argent (un `double` fait des erreurs d'arrondi). | le montant d'un `ElementDePaie` |
| **JAR** | Un fichier `.jar` est un paquet de classes Java compilées, comme un `.zip`. Un JAR « exécutable » se lance avec `java -jar`. | `sirh-export-api/target/*.jar` |
| **JDK / JRE** | Le JDK sert à **compiler** et construire ; le JRE suffit à **exécuter**. | image Docker : JDK pour construire, JRE pour exécuter |

## Maven : l'outil de construction
| Terme | Ce que c'est |
|---|---|
| **Maven** | L'outil qui compile le code, lance les tests et fabrique le JAR. On le pilote en ligne de commande avec `mvn`. |
| **POM** (`pom.xml`) | Le fichier qui décrit un projet : son nom, sa version, ses dépendances, ses plugins. |
| **Module** | Un sous-projet avec son propre `pom.xml`. Ici : `core`, `format-sage`, `api`. |
| **POM parent** | Le `pom.xml` de la racine : il liste les modules et fixe les versions communes. Les modules en héritent. |
| **Réacteur (reactor)** | La partie de Maven qui calcule l'**ordre** de construction des modules d'après leurs dépendances. |
| **Dépendance** | Une bibliothèque (ou un autre module) dont le code a besoin. Maven la télécharge automatiquement. |
| **Coordonnées** | `groupId:artifactId:version`, l'« adresse » unique d'un artefact. |
| **Artefact** | Le résultat d'une construction (un JAR, un POM) qu'on peut publier et réutiliser. |
| **`~/.m2`** | Le dossier local où Maven garde les dépendances téléchargées (le « dépôt local »). |
| **SNAPSHOT** | Une version en cours de développement (`1.0.0-SNAPSHOT`), qui peut être republiée. Sans ce suffixe : une **release**, figée. |
| **Phase / goal** | `mvn verify` exécute toutes les phases jusqu'à `verify` (compiler, tester, empaqueter, vérifier). Un *goal* est une action précise d'un plugin. |
| **Plugin** | Un module d'extension de Maven (compilation, tests, couverture, publication…). |

Les options à retenir : `-pl <module>` (construire seulement ce module), `-am` (et les modules dont il dépend), `-amd` (et ceux qui dépendent de lui), `-B` (mode batch, sans couleurs, pour la CI), `-q` (silencieux), `-DskipTests` (ne pas lancer les tests).

## Tests
| Terme | Ce que c'est |
|---|---|
| **Test unitaire** | Un petit programme qui appelle **une** méthode et vérifie son résultat. Rapide, sans réseau ni base. |
| **JUnit 5** | La bibliothèque qui exécute les tests (`@Test`). |
| **AssertJ** | Une bibliothèque pour écrire les vérifications de façon lisible : `assertThat(x).isEqualTo(y)`. |
| **Test d'intégration** | Un test qui fait travailler plusieurs briques ensemble (le code **et** une vraie base de données, par exemple). Plus lent. Par convention, son nom finit par `IT`. |
| **Testcontainers** | Une bibliothèque qui démarre un conteneur Docker (ici PostgreSQL) le temps d'un test, puis le supprime. |
| **Couverture** | Le pourcentage de lignes de code exécutées par les tests. Mesurée par JaCoCo. |
| **Mock / double de test** | Un faux composant qui remplace un vrai pendant un test. |

## Git
| Terme | Ce que c'est |
|---|---|
| **Commit** | Un instantané de l'arbre de fichiers, avec un message et un auteur. |
| **Branche** | Une ligne de commits indépendante ; `main` est la branche de référence. |
| **Rebase** | Rejouer les commits d'une branche **par-dessus** une autre : l'historique reste linéaire, mais les commits sont recréés (nouveaux identifiants). |
| **Merge** | Réunir deux branches avec un commit de fusion, sans toucher à l'historique existant. |
| **Cherry-pick** | Copier **un seul** commit sur une autre branche. |
| **Tag** | Une étiquette fixe sur un commit (par exemple `v1.0.0`). |
| **MR (merge request)** | Dans GitLab, la demande de fusion d'une branche, avec revue et pipeline. |

## Intégration continue (CI)
| Terme | Ce que c'est |
|---|---|
| **Pipeline** | La suite automatique d'étapes (construire, tester, analyser, empaqueter) lancée à chaque modification. |
| **Stage / job** | Un *stage* est une étape du pipeline ; un *job* est une tâche qui s'y exécute. |
| **Runner** | Le programme qui exécute les jobs sur une machine. |
| **`.gitlab-ci.yml`** | Le fichier, à la racine du dépôt, qui décrit le pipeline GitLab. |
| **Cache / artifact** | Le cache accélère les builds (non garanti). Un artifact est un fichier produit par un job et conservé ou transmis aux jobs suivants. |
| **Quality gate** | Un ensemble de seuils (couverture, bugs…) que l'analyse SonarQube doit respecter. Sinon le pipeline passe au rouge. |
| **Jenkinsfile** | L'équivalent Jenkins du `.gitlab-ci.yml`. |

## Docker
| Terme | Ce que c'est |
|---|---|
| **Image** | Le modèle figé d'une application et de son environnement. |
| **Conteneur** | Une instance en cours d'exécution d'une image. |
| **Dockerfile** | La recette qui décrit comment construire une image. |
| **Multi-stage** | Un Dockerfile en plusieurs étapes : la première construit (gros outils), la dernière ne garde que le nécessaire (image finale plus petite). |
| **Volume** | Un espace de stockage qui survit à la suppression du conteneur (les données PostgreSQL y vivent). |
| **Docker Compose** | Un fichier `docker-compose.yml` qui décrit plusieurs conteneurs et les démarre ensemble (`docker compose up -d`). |
| **Registre** | Un serveur qui stocke des images (`docker push` / `docker pull`). Ici : Nexus. |
| **Tag d'image** | Le nom de version d'une image (`sirh-export-api:3fa2c1b`). `latest` est un tag mobile : à éviter pour tracer une version. |

## Outils du lab
| Outil | Rôle |
|---|---|
| **Nexus** | Stocke les artefacts Maven (JAR) et les images Docker. |
| **SonarQube** | Analyse la qualité du code et mesure la couverture. |
| **GitLab** | Héberge le dépôt Git et exécute les pipelines. |
| **Jenkins** | Autre serveur de CI, vu à l'atelier 11 pour comparaison. |
| **PostgreSQL** | La base de données relationnelle. |
| **Swagger UI** | Une page web générée à partir de l'API, qui permet de l'essayer sans écrire de code. |
