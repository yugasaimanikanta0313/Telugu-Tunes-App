package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.MetadataCatalogImportResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.domain.MetadataCatalogEntry;
import com.telugutunes.api.service.MetadataCatalogService;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/admin/metadata-catalog")
public class MetadataCatalogController {
  private final MetadataCatalogService catalog;
  public MetadataCatalogController(MetadataCatalogService catalog) { this.catalog = catalog; }

  @PostMapping("/upload")
  public MetadataCatalogImportResponse upload(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId,
      @RequestParam("file") MultipartFile file) {
    return catalog.upload(administratorId, file);
  }

  @GetMapping("/match")
  public ResponseEntity<MetadataCatalogEntry> match(@RequestParam String fileName) {
    return catalog.match(fileName).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.noContent().build());
  }

  @GetMapping("/export")
  public ResponseEntity<byte[]> export(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String administratorId) {
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION,
            "attachment; filename=telugu-tunes-song-catalog.xlsx")
        .contentType(MediaType.parseMediaType(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
        .body(catalog.exportCurrentSongs(administratorId));
  }
}
