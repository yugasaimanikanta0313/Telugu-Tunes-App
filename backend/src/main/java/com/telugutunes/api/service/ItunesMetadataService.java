package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ArtworkCandidate;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * A no-credential catalogue fallback for album and genre. It uses only the public iTunes Search
 * response and never attempts playback, downloading, or account access.
 */
@Service
public class ItunesMetadataService {
  private final RestClient client = RestClient.builder()
      .baseUrl("https://itunes.apple.com")
      .requestFactory(requestFactory())
      .build();

  private static SimpleClientHttpRequestFactory requestFactory() {
    var factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(3));
    factory.setReadTimeout(Duration.ofSeconds(5));
    return factory;
  }

  public Optional<TrackMetadata> find(String query) {
    return findCandidates(query).stream().findFirst();
  }

  public List<TrackMetadata> findCandidates(String query) {
    if (query == null || query.isBlank()) return List.of();
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
        return List.of();
      }
      var matches = results.stream()
          .filter(Map.class::isInstance)
          .map(Map.class::cast)
          .map(this::metadata)
          .sorted(Comparator.comparingInt((TrackMetadata item) -> score(item, query)).reversed())
          .toList();
      var seen = new HashSet<String>();
      var unique = new ArrayList<TrackMetadata>();
      for (var match : matches) {
        if (match.artworkUrl().isBlank() || !seen.add(match.artworkUrl())) continue;
        unique.add(match);
        if (unique.size() == 3) break;
      }
      return unique;
    } catch (RuntimeException ignored) {
      // Apple is optional. The existing YouTube and Gemini lookup still completes normally.
      return List.of();
    }
  }

  public ArtworkCandidate artworkCandidate(TrackMetadata item) {
    return new ArtworkCandidate(item.artworkUrl(), item.title(), item.artist(),
        item.collection(), "Apple Music", item.sourceUrl());
  }

  private TrackMetadata metadata(Map<?, ?> result) {
    return new TrackMetadata(
        value(result, "trackName"),
        value(result, "artistName"),
        value(result, "collectionName"),
        value(result, "primaryGenreName"),
        highResolutionArtwork(value(result, "artworkUrl100")),
        value(result, "trackViewUrl"));
  }

  /** Apple returns a square 100 px URL even when a larger rendition is available. */
  private String highResolutionArtwork(String value) {
    if (value == null || value.isBlank()) return "";
    return value
        .replaceFirst("\\d+x\\d+bb", "1000x1000bb")
        .replaceFirst("\\d+x\\d+-\\d+", "1000x1000-999");
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
