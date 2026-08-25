package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.ImportReferenceRequest;
import com.telugutunes.api.api.dto.ImportResponse;
import com.telugutunes.api.service.ImportService;
import com.telugutunes.api.config.AuthenticationFilter;
import jakarta.validation.Valid;
import java.io.IOException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/imports")
public class ImportsController {
  private final ImportService imports;

  public ImportsController(ImportService imports) {
    this.imports = imports;
  }

  @PostMapping(value = "/audio", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  @ResponseStatus(HttpStatus.ACCEPTED)
  public ImportResponse importAudio(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @RequestPart("file") MultipartFile file,
      @RequestPart(value = "title", required = false) String title,
      @RequestPart(value = "artist", required = false) String artist,
      @RequestPart(value = "album", required = false) String album,
      @RequestPart(value = "color", required = false) String color,
      @RequestPart(value = "singers", required = false) String singers,
      @RequestPart(value = "musicDirector", required = false) String musicDirector,
      @RequestPart(value = "genre", required = false) String genre,
      @RequestPart(value = "artworkUrl", required = false) String artworkUrl,
      @RequestPart(value = "sourceUrl", required = false) String sourceUrl)
      throws IOException {
    return imports.importAudio(
        memberId, file, title, artist, album, color, singers, musicDirector, genre, artworkUrl, sourceUrl);
  }

  @PostMapping("/reference")
  @ResponseStatus(HttpStatus.ACCEPTED)
  public ImportResponse reference(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody ImportReferenceRequest request) {
    return imports.addReference(memberId, request);
  }
}
