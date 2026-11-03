#!/usr/bin/env bash
# Prépare le dépôt de l'atelier A01 (Git avancé) à partir du code réel de sirh-export.
# Produit, dans ~/lab-git :
#   origin.git/    dépôt « serveur » local (remplace GitLab pour l'atelier)
#   sirh-export/   votre clone de travail, avec une branche feature qui a divergé de main
# Usage (depuis la racine du projet) : bash scripts/ateliers/preparer-atelier-01.sh [dossier-source] [dossier-lab]
# Relancer le script = remise à zéro complète (l'ancien lab est supprimé).
#
# Le code de départ est celui du projet que vous avez reçu (par défaut le dossier qui contient ce
# script). Ce doit être la version « de départ » : sans le builder, la couche JPA, REST Assured ni
# Cucumber, que les ateliers 5, 6, 13 et 14 vous font écrire. Avec les solutions déjà présentes, le
# code que ce script écrit sur la branche feature entrerait en conflit avec elles.
# Côté formateur : produire cette version avec scripts/exporter-projet-depart.sh.
set -euo pipefail

ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="${1:-$ici/../..}"        # racine du projet : scripts/ateliers/ -> ../..
lab="${2:-$HOME/lab-git}"

[ -f "$src/pom.xml" ] || { echo "Projet sirh-export introuvable : $src" >&2; exit 1; }
src="$(cd "$src" && pwd)"
if [ -e "$src/sirh-export-api/src/main/java/fr/plb/sirh/persistance" ] || [ -e "$src/sirh-export-format-sage/src/test/java/fr/plb/sirh/RunCucumberTest.java" ]; then
  echo "Ce projet contient déjà les solutions des ateliers (persistance, Cucumber…) : utilisez la version de départ." >&2
  exit 1
fi

rm -rf "$lab/origin.git" "$lab/sirh-export"
mkdir -p "$lab"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

CORE=sirh-export-core/src/main/java/fr/plb/sirh
CORE_T=sirh-export-core/src/test/java/fr/plb/sirh
SAGE=sirh-export-format-sage/src/main/java/fr/plb/sirh
SAGE_T=sirh-export-format-sage/src/test/java/fr/plb/sirh
API=sirh-export-api/src/main/java/fr/plb/sirh

# commiter <nom> <date> <message...> : identité et dates figées, donc mêmes hash chez tous les stagiaires
commiter() {
  local nom=$1 date=$2; shift 2
  local mail; mail="$(printf %s "$nom" | tr '[:upper:]' '[:lower:]')@example.org"
  GIT_AUTHOR_NAME=$nom GIT_AUTHOR_EMAIL=$mail GIT_AUTHOR_DATE=$date \
  GIT_COMMITTER_NAME=$nom GIT_COMMITTER_EMAIL=$mail GIT_COMMITTER_DATE=$date \
    git commit -q "$@"
}
reglages() { git config core.autocrlf false; git config commit.gpgsign false; git config rebase.autoStash false; }

git init -q --bare -b main "$lab/origin.git"

# ── Le collègue : état initial du projet, tag de la version livrée, branche de maintenance ──
git clone -q -c core.autocrlf=false "$lab/origin.git" "$tmp/collegue" 2>/dev/null
cd "$tmp/collegue"; reglages
git config user.name Collegue; git config user.email collegue@example.org
(cd "$src" && tar cf - --exclude=target --exclude=.git --exclude=.DS_Store --exclude=.env --exclude=lab --exclude=scripts --exclude=docs --exclude=README.md .) | tar xf -
git add -A
commiter Collegue "2026-10-12T09:00:00+0200" -m "chore: import initial de sirh-export 1.0.0"
git tag v1.0.0
git branch release/1.0
git push -q origin main release/1.0 v1.0.0

# ── Vous : un clone, et la branche feature démarrée hier à partir de ce main ──
git clone -q -c core.autocrlf=false "$lab/origin.git" "$lab/sirh-export" 2>/dev/null
cd "$lab/sirh-export"; reglages
git config user.name Stagiaire; git config user.email stagiaire@example.org
git switch -q -c feature/prime-anciennete

# 1/4 — wip prime (le seuil des 10 ans est faux : > au lieu de >=)
cat > $CORE/PrimeAnciennete.java <<'EOF'
package fr.plb.sirh;

import java.math.BigDecimal;

/** Barème de la prime d'ancienneté : 3 % à partir de 3 ans, 5 % à partir de 10 ans. */
public final class PrimeAnciennete {

    public static final String CODE = "PANC";

    private PrimeAnciennete() {
    }

    public static BigDecimal taux(int annees) {
        if (annees < 0) {
            throw new ExportException("Ancienneté négative : " + annees);
        }
        if (annees > 10) {
            return new BigDecimal("0.05");
        }
        if (annees >= 3) {
            return new BigDecimal("0.03");
        }
        return BigDecimal.ZERO;
    }
}
EOF
git add -A; commiter Stagiaire "2026-10-13T10:00:00+0200" -m "wip prime"

# 2/4 — wip export PANC (enrichit le message de la ligne que le refactor de main modifie aussi : source du conflit)
cat > $SAGE/ExportPaie.java <<'EOF'
package fr.plb.sirh;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Format PÉDAGOGIQUE simplifié (colonnes fixes) — ce n'est PAS le format d'import Sage réel.
 * Un enregistrement par élément de paie :
 * matricule(8) nom(20) code(6) montant(12, centimes, cadré à droite) début(8 yyyyMMdd) fin(8 yyyyMMdd)
 */
public class ExportPaie {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    public String exporter(List<ElementDePaie> elements) {
        return elements.stream().map(this::ligne).collect(Collectors.joining("\n"));
    }

    String ligne(ElementDePaie e) {
        String matricule = e.salarie().matricule();
        if (matricule == null || matricule.isBlank()) {
            throw new ExportException("Matricule manquant pour " + e.salarie().nom() + " (élément " + e.code() + ")");
        }
        if (PrimeAnciennete.CODE.equals(e.code()) && e.montant().signum() < 0) {
            throw new ExportException("Prime d'ancienneté négative pour " + matricule);
        }
        long centimes = e.montant().setScale(2, RoundingMode.HALF_UP).movePointRight(2).longValueExact();
        return String.format("%-8.8s%-20.20s%-6.6s%12d%s%s",
                matricule, e.salarie().nom(), e.code(), centimes,
                DATE.format(e.debut()), DATE.format(e.fin()));
    }
}
EOF
cat > $SAGE_T/ExportPaiePrimeTest.java <<'EOT'
package fr.plb.sirh;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class ExportPaiePrimeTest {

    private final ExportPaie export = new ExportPaie();

    private ElementDePaie prime(String montant) {
        return new ElementDePaie(new Salarie("M0001", "DURAND", "Alice"), PrimeAnciennete.CODE,
                new BigDecimal(montant), LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31));
    }

    @Test
    void exporteUnePrimeDAnciennete() {
        assertThat(export.exporter(List.of(prime("50")))).contains("PANC");
    }

    @Test
    void refuseUnePrimeDAncienneteNegative() {
        assertThatThrownBy(() -> export.exporter(List.of(prime("-50"))))
                .isInstanceOf(ExportException.class);
    }
}
EOT
git add -A; commiter Stagiaire "2026-10-13T14:00:00+0200" -m "wip export PANC"

# 3/4 — tests prime (rouge : le test à 10 ans échoue à cause du bug de l'étape 1)
cat > $CORE_T/PrimeAncienneteTest.java <<'EOF'
package fr.plb.sirh;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.api.Test;

class PrimeAncienneteTest {

    @ParameterizedTest
    @CsvSource({"0,0", "2,0", "3,0.03", "9,0.03", "10,0.05", "25,0.05"})
    void appliqueLeBareme(int annees, BigDecimal attendu) {
        assertThat(PrimeAnciennete.taux(annees)).isEqualByComparingTo(attendu);
    }

    @Test
    void refuseUneAncienneteNegative() {
        assertThatThrownBy(() -> PrimeAnciennete.taux(-1)).isInstanceOf(ExportException.class);
    }
}
EOF
git add -A; commiter Stagiaire "2026-10-14T09:30:00+0200" -m "tests prime"

# 4/4 — oups seuil
sed -i.bak 's/annees > 10/annees >= 10/' $CORE/PrimeAnciennete.java && rm -f $CORE/PrimeAnciennete.java.bak
git add -A; commiter Stagiaire "2026-10-14T10:15:00+0200" -m "oups seuil"

git push -q -u origin feature/prime-anciennete

# ── Pendant ce temps, le collègue a fait avancer main (le clone du stagiaire ne le sait pas encore) ──
cd "$tmp/collegue"; git config user.name Collegue; git config user.email collegue@example.org

# M1 — correctif de recette (à reporter aussi sur release/1.0)
cat > $SAGE/ExportPaie.java <<'EOF'
package fr.plb.sirh;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Format PÉDAGOGIQUE simplifié (colonnes fixes) — ce n'est PAS le format d'import Sage réel.
 * Un enregistrement par élément de paie :
 * matricule(8) nom(20) code(6) montant(12, centimes, cadré à droite) début(8 yyyyMMdd) fin(8 yyyyMMdd)
 */
public class ExportPaie {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    public String exporter(List<ElementDePaie> elements) {
        return elements.stream().map(this::ligne).collect(Collectors.joining("\n"));
    }

    String ligne(ElementDePaie e) {
        String matricule = e.salarie().matricule();
        if (matricule == null || matricule.isBlank()) {
            throw new ExportException("Matricule manquant pour " + e.salarie().nom());
        }
        if (e.fin().isBefore(e.debut())) {
            throw new ExportException("Période invalide pour " + matricule + " : la fin précède le début");
        }
        long centimes = e.montant().setScale(2, RoundingMode.HALF_UP).movePointRight(2).longValueExact();
        return String.format("%-8.8s%-20.20s%-6.6s%12d%s%s",
                matricule, e.salarie().nom(), e.code(), centimes,
                DATE.format(e.debut()), DATE.format(e.fin()));
    }
}
EOF
cat > $SAGE_T/ExportPaieTest.java <<'EOF'
package fr.plb.sirh;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class ExportPaieTest {

    private final ExportPaie export = new ExportPaie();

    private ElementDePaie element(String matricule, String montant) {
        return new ElementDePaie(new Salarie(matricule, "DURAND", "Alice"), "PRIME1",
                new BigDecimal(montant), LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31));
    }

    @Test
    void produitUneLigneAColonnesFixes() {
        String ligne = export.exporter(List.of(element("M0001", "123.45")));
        assertThat(ligne).isEqualTo("M0001   DURAND              PRIME1" + "       12345" + "20261001" + "20261031");
    }

    @Test
    void refuseUnSalarieSansMatricule() {
        assertThatThrownBy(() -> export.exporter(List.of(element(" ", "10"))))
                .isInstanceOf(ExportException.class);
    }

    @Test
    void refuseUneFinAvantLeDebut() {
        ElementDePaie inverse = new ElementDePaie(new Salarie("M0001", "DURAND", "Alice"), "PRIME1",
                BigDecimal.TEN, LocalDate.of(2026, 10, 31), LocalDate.of(2026, 10, 1));
        assertThatThrownBy(() -> export.exporter(List.of(inverse)))
                .isInstanceOf(ExportException.class);
    }
}
EOF
git add -A
commiter Collegue "2026-10-14T11:00:00+0200" -m "fix(format-sage): rejeter un élément de paie dont la fin précède le début" \
  -m "Constaté en recette : un export avec des dates inversées passait sans erreur."

# M2 — refactor : ExportException porte un code d'erreur (le constructeur à un argument disparaît)
cat > $CORE/ExportException.java <<'EOF'
package fr.plb.sirh;

public class ExportException extends RuntimeException {

    private final String code;

    public ExportException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
EOF
sed -i.bak \
  -e 's/new ExportException("Matricule manquant/new ExportException("MATRICULE_MANQUANT", "Matricule manquant/' \
  -e 's/new ExportException("Période invalide/new ExportException("PERIODE_INVALIDE", "Période invalide/' \
  $SAGE/ExportPaie.java && rm -f $SAGE/ExportPaie.java.bak
sed -i.bak 's/\.body(e\.getMessage())/.body(e.getCode() + " : " + e.getMessage())/' $API/ExportController.java \
  && rm -f $API/ExportController.java.bak
cat > $SAGE_T/ExportPaieTest.java <<'EOT'
package fr.plb.sirh;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class ExportPaieTest {

    private final ExportPaie export = new ExportPaie();

    private ElementDePaie element(String matricule, String montant) {
        return new ElementDePaie(new Salarie(matricule, "DURAND", "Alice"), "PRIME1",
                new BigDecimal(montant), LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31));
    }

    @Test
    void produitUneLigneAColonnesFixes() {
        String ligne = export.exporter(List.of(element("M0001", "123.45")));
        assertThat(ligne).isEqualTo("M0001   DURAND              PRIME1" + "       12345" + "20261001" + "20261031");
    }

    @Test
    void refuseUnSalarieSansMatricule() {
        assertThatThrownBy(() -> export.exporter(List.of(element(" ", "10"))))
                .isInstanceOf(ExportException.class)
                .hasFieldOrPropertyWithValue("code", "MATRICULE_MANQUANT");
    }

    @Test
    void refuseUneFinAvantLeDebut() {
        ElementDePaie inverse = new ElementDePaie(new Salarie("M0001", "DURAND", "Alice"), "PRIME1",
                BigDecimal.TEN, LocalDate.of(2026, 10, 31), LocalDate.of(2026, 10, 1));
        assertThatThrownBy(() -> export.exporter(List.of(inverse)))
                .isInstanceOf(ExportException.class)
                .hasFieldOrPropertyWithValue("code", "PERIODE_INVALIDE");
    }
}
EOT
git add -A
commiter Collegue "2026-10-14T15:00:00+0200" -m "refactor(core): ExportException porte un code d'erreur stable" \
  -m "Le support filtre désormais sur le code, plus sur le libellé. Le constructeur à un seul argument est supprimé."
git push -q origin main

# ── Le stagiaire n'a rien récupéré : son main local est en retard, comme dans la vraie vie ──
cd "$lab/sirh-export"
echo
echo "Dépôt prêt : $lab/sirh-export  (remote : $lab/origin.git)"
echo "Branche courante : $(git branch --show-current)"
echo "Étape suivante  : cd $lab/sirh-export && git fetch"
