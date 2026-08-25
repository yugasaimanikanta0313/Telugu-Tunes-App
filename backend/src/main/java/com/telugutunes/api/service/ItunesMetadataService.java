package com.telugutunes.api.service;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * A no-credential catalogue fallback for album and genre. It uses only the public iTunes Search
 * response and never attempts playback, downloading, or account access.
 */
@Service
public class ItunesMetadataService {
  private final RestClient client = RestClient.builder().baseUrl("https://itunes.apple.com").build();

  public Optional<TrackMetadata> find(String query) {
    if (query == null || query.isBlank()) return Optional.empty();
    try {
      Map<?, ?> response = client.get()
          .uri(builder -> builder.path("/search")
              .queryParam("term", query.trim())
              .queryParam("country", "IN")
              .queryParam("media", "music")
              .queryParam("entity", "song")
              .queryParam("limit", 8)
              .build())
          .retrieve()
          .body(Map.class);
      if (response == null || !(response.get("results") instanceof List<?> results)) {
        return Optional.empty();
      }
      return results.stream()
          .filter(Map.class::isInstance)
          .map(Map.class::cast)
          .map(this::metadata)
          .max((left, right) -> Integer.compare(score(left, query), score(right, query)));
    } catch (RuntimeException ignored) {
      // Apple is optional. The existing YouTube and Gemini lookup still completes normally.
      return Optional.empty();
    }
  }

  private TrackMetadata metadata(Map<?, ?> result) {
    return new TrackMetadata(
        value(result, "trackName"),
        value(result, "artistName"),
        value(result, "collectionName"),
        value(result, "primaryGenreName"),
        value(result, "artworkUrl100"),
        value(result, "trackViewUrl"));
  }

  private int score(TrackMetadata result, String query) {
    var needle = normalized(query);
    var title = normalized(result.title());
    var score = 0;
    if (!needle.isBlank() && (title.contains(needle) || needle.contains(title))) score += 8;
    for (var token : needle.split(" ")) {
      if (token.length() > 2 && title.contains(token)) score++;
    }
    if (!result.collection().isBlank()) score++;
    if (!result.genre().isBlank()) score++;
    return score;
  }

  private String normalized(String value) {
    return value == null ? "" : value.toLowerCase(Locale.ROOT)
        .replaceAll("https?://\\S+", " ")
        .replaceAll("[^a-z0-9\\s]", " ")
        .replaceAll("\\s+", " ").trim();
  }

  private String value(Map<?, ?> item, String key) {
    var value = item.get(key);
    return value == null ? "" : value.toString().trim();
  }

  public record TrackMetadata(
      String title, String artist, String collection, String genre, String artworkUrl, String sourceUrl) {}
}
