package fr.plb.sirh;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SalarieTest {

    @Test
    void conserveSesValeurs() {
        Salarie s = new Salarie("M0001", "DURAND", "Alice");
        assertThat(s.matricule()).isEqualTo("M0001");
    }
}
