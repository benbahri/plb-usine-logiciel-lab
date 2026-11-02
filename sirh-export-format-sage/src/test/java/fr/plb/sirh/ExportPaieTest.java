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
}
