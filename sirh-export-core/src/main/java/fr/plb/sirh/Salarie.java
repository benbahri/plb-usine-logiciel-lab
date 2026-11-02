package fr.plb.sirh;

/** Salarié exportable. Le matricule est obligatoire pour l'export paie. */
public record Salarie(String matricule, String nom, String prenom) {
}
