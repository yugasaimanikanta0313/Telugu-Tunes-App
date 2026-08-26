package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.AlbumResponse;
import com.telugutunes.api.api.dto.HomeResponse;
import com.telugutunes.api.api.dto.TrackResponse;
import com.telugutunes.api.api.dto.TrackAudioReplacementResponse;
import com.telugutunes.api.api.dto.UpdateAlbumRequest;
import com.telugutunes.api.api.dto.UpdateTrackRequest;
import com.telugutunes.api.service.CatalogService;
import com.telugutunes.api.config.AuthenticationFilter;
import java.util.List;
import java.io.IOException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestPart;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class CatalogController {
  private final CatalogService catalog;

  public CatalogController(CatalogService catalog) {
    this.catalog = catalog;
  }

  @GetMapping("/home")
  public HomeResponse home() {
    return catalog.home();
  }

  @GetMapping("/tracks/search")
  public List<TrackResponse> search(@RequestParam(defaultValue = "") String q) {
    return catalog.search(q);
  }

  @GetMapping("/albums")
  public List<AlbumResponse> albums() {
    return catalog.home().featuredAlbums();
  }

  @GetMapping("/albums/{id}")
  public AlbumResponse album(@PathVariable String id) {
    return catalog.album(id);
  }

  @PutMapping("/albums/{id}")
  public AlbumResponse updateAlbum(
      @PathVariable String id,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody UpdateAlbumRequest request) {
    return catalog.updateAlbum(memberId, id, request);
  }

  @DeleteMapping("/albums/{id}")
  @org.springframework.web.bind.annotation.ResponseStatus(HttpStatus.NO_CONTENT)
  public void deleteAlbum(
      @PathVariable String id,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    catalog.removeAlbum(memberId, id);
  }

  @PutMapping("/tracks/{id}")
  public TrackResponse updateTrack(
      @PathVariable String id,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody UpdateTrackRequest request) {
    return catalog.updateTrack(memberId, id, request);
  }

  @PutMapping(value = "/tracks/{id}/audio", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public TrackAudioReplacementResponse replaceTrackAudio(
      @PathVariable String id,
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @RequestPart("file") MultipartFile file)
      throws IOException {
    return catalog.replaceTrackAudio(memberId, id, file);
  }

  @DeleteMapping("/tracks/{id}")
  @org.springframework.web.bind.annotation.ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(
      @PathVariable String id,
      @org.springframework.web.bind.annotation.RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId)
      throws IOException {
    catalog.deleteTrack(memberId, id);
  }
}
