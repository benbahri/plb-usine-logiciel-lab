package fr.plb.sirh;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Élément de paie (prime, heures, retenue...) rattaché à un salarié sur une période. */
public record ElementDePaie(Salarie salarie, String code, BigDecimal montant,
                            LocalDate debut, LocalDate fin) {
}
