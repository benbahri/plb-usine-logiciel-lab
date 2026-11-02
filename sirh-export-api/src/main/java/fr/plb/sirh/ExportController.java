package fr.plb.sirh;

import io.swagger.v3.oas.annotations.Operation;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/exports")
public class ExportController {

    private final ExportPaie exportPaie = new ExportPaie();

    @Operation(summary = "Génère l'export paie (format pédagogique) pour les éléments fournis")
    @PostMapping(produces = "text/plain")
    public String exporter(@RequestBody List<ElementDePaie> elements) {
        return exportPaie.exporter(elements);
    }

    @ExceptionHandler(ExportException.class)
    ResponseEntity<String> rejet(ExportException e) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(e.getMessage());
    }
}
