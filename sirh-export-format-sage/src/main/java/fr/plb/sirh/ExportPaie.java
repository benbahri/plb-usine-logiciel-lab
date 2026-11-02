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
        long centimes = e.montant().setScale(2, RoundingMode.HALF_UP).movePointRight(2).longValueExact();
        return String.format("%-8.8s%-20.20s%-6.6s%12d%s%s",
                matricule, e.salarie().nom(), e.code(), centimes,
                DATE.format(e.debut()), DATE.format(e.fin()));
    }
}
