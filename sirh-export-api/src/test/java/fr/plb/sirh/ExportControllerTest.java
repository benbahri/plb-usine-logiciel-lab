package fr.plb.sirh;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class ExportControllerTest {

    @Autowired
    MockMvc mvc;

    @Test
    void rejetteUnSalarieSansMatricule() throws Exception {
        String json = """
            [{"salarie":{"matricule":"","nom":"DURAND","prenom":"Alice"},"code":"P1",
              "montant":10,"debut":"2026-10-01","fin":"2026-10-31"}]""";
        mvc.perform(post("/exports").contentType(MediaType.APPLICATION_JSON).content(json))
                .andExpect(status().isUnprocessableEntity());
    }
}
