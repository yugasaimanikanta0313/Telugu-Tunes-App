package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ArtworkCandidate;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/** Optional free catalogue fallback backed by MusicBrainz and the Cover Art Archive. */
@Service
public class MusicBrainzCoverService {
  private static final Logger log = LoggerFactory.getLogger(MusicBrainzCoverService.class);
  private final RestClient musicBrainz = RestClient.builder()
      .baseUrl("https://musicbrainz.org")
      .defaultHeader("User-Agent", "TeluguTunes/1.0 (https://github.com/yugasaimanikanta0313/Telugu-Tunes-App)")
      .requestFactory(requestFactory())
      .build();
  private final RestClient covers = RestClient.builder()
      .baseUrl("https://coverartarchive.org")
      .requestFactory(requestFactory())
      .build();

  private static SimpleClientHttpRequestFactory requestFactory() {
    var factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(3));
    factory.setReadTimeout(Duration.ofSeconds(5));
    return factory;
  }

  public List<ArtworkCandidate> find(String query) {
    if (query == null || query.isBlank()) return List.of();
    try {
      Map<?, ?> response = musicBrainz.get()
          .uri(builder -> builder.path("/ws/2/release-group")
              .queryParam("query", query.trim())
              .queryParam("fmt", "json")
              .queryParam("limit", 5)
              .build())
          .retrieve()
          .body(Map.class);
      if (response == null || !(response.get("release-groups") instanceof List<?> groups)) {
        return List.of();
      }
      var results = new ArrayList<ArtworkCandidate>();
      for (var value : groups) {
        if (!(value instanceof Map<?, ?> group) || results.size() >= 2) continue;
        var id = text(group, "id");
        var imageUrl = coverUrl(id);
        if (imageUrl.isBlank()) continue;
        var title = text(group, "title");
        results.add(new ArtworkCandidate(
            imageUrl, title, artist(group), title, "MusicBrainz",
            "https://musicbrainz.org/release-group/" + id));
      }
      return results;
    } catch (RuntimeException exception) {
      log.debug("MusicBrainz cover lookup unavailable: {}", exception.getMessage());
      return List.of();
    }
  }

  private String coverUrl(String id) {
    if (id.isBlank()) return "";
    try {
      Map<?, ?> response = covers.get()
          .uri("/release-group/{id}", id)
          .retrieve()
          .body(Map.class);
      if (response == null || !(response.get("images") instanceof List<?> images)) return "";
      for (var value : images) {
        if (!(value instanceof Map<?, ?> image) || !Boolean.TRUE.equals(image.get("front"))) continue;
        if (image.get("thumbnails") instanceof Map<?, ?> thumbnails) {
          var large = thumbnails.get("1200");
          if (large == null) large = thumbnails.get("500");
          if (large != null && !large.toString().isBlank()) return large.toString();
        }
        return text(image, "image");
      }
      return "";
    } catch (RuntimeException ignored) {
      return "";
    }
  }

  private String artist(Map<?, ?> group) {
    if (!(group.get("artist-credit") instanceof List<?> credits) || credits.isEmpty()) return "";
    var first = credits.getFirst();
    if (!(first instanceof Map<?, ?> credit)) return "";
    var name = text(credit, "name");
    if (!name.isBlank()) return name;
    return credit.get("artist") instanceof Map<?, ?> artist ? text(artist, "name") : "";
  }

  private String text(Map<?, ?> value, String key) {
    var item = value.get(key);
    return item == null ? "" : item.toString().trim();
  }
}
