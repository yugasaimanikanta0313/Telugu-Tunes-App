package com.telugutunes.api.service;

import com.telugutunes.api.config.AppProperties;
import java.net.URI;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Retrieves publicly exposed YouTube video metadata. It never downloads audio or video; uploaded
 * audio remains in the member's private Google Drive folder.
 */
@Service
public class YouTubeMetadataService {
  private static final Logger log = LoggerFactory.getLogger(YouTubeMetadataService.class);
  private final AppProperties properties;
  private final RestClient client;

  public YouTubeMetadataService(AppProperties properties) {
    this.properties = properties;
    this.client = RestClient.builder().baseUrl("https://www.googleapis.com/youtube/v3").build();
  }

  public Optional<VideoMetadata> find(String query) {
    if (!isConfigured() || query == null || query.isBlank()) return Optional.empty();
    try {
      var videoId = videoIdFromUrl(query);
      if (videoId.isEmpty()) videoId = searchFirstVideo(query.trim());
      return videoId.flatMap(this::videoById);
    } catch (RuntimeException exception) {
      // The caller still returns editable filename/Gemini suggestions when YouTube is unavailable.
      log.warn("YouTube metadata lookup failed: {}", exception.getMessage());
      return Optional.empty();
    }
  }

  public boolean isConfigured() {
    var apiKey = properties.getYoutube().getApiKey();
    return apiKey != null && !apiKey.isBlank();
  }

  private Optional<String> searchFirstVideo(String query) {
    Map<?, ?> response =
        client
            .get()
            .uri(
                builder ->
                    builder
                        .path("/search")
                        .queryParam("part", "snippet")
                        .queryParam("type", "video")
                        .queryParam("videoCategoryId", "10")
                        .queryParam("relevanceLanguage", "te")
                        .queryParam("maxResults", 1)
                        .queryParam("q", query)
                        .queryParam("key", properties.getYoutube().getApiKey())
                        .build())
            .retrieve()
            .body(Map.class);
    return firstMap(response, "items")
        .flatMap(item -> map(item.get("id")))
        .map(id -> string(id.get("videoId")))
        .filter(value -> !value.isBlank());
  }

  private Optional<VideoMetadata> videoById(String videoId) {
    Map<?, ?> response =
        client
            .get()
            .uri(
                builder ->
                    builder
                        .path("/videos")
                        .queryParam("part", "snippet")
                        .queryParam("id", videoId)
                        .queryParam("key", properties.getYoutube().getApiKey())
                        .build())
            .retrieve()
            .body(Map.class);
    return firstMap(response, "items")
        .flatMap(item -> map(item.get("snippet")))
        .map(snippet -> fromSnippet(videoId, snippet));
  }

  private VideoMetadata fromSnippet(String videoId, Map<?, ?> snippet) {
    var thumbnail = thumbnailUrl(map(snippet.get("thumbnails")).orElse(Map.of()));
    var publishedAt = string(snippet.get("publishedAt"));
    var year = 0;
    try {
      year = OffsetDateTime.parse(publishedAt).getYear();
    } catch (RuntimeException ignored) {
      // A missing or malformed date should not prevent useful title/thumbnail metadata.
    }
    return new VideoMetadata(
        string(snippet.get("title")),
        string(snippet.get("channelTitle")),
        string(snippet.get("description")),
        year,
        thumbnail,
        "https://www.youtube.com/watch?v=" + videoId);
  }

  private Optional<String> videoIdFromUrl(String value) {
    try {
      var uri = URI.create(value.trim());
      var host = uri.getHost() == null ? "" : uri.getHost().toLowerCase();
      if (host.equals("youtu.be")) {
        var path = uri.getPath();
        return path == null || path.length() <= 1 ? Optional.empty() : Optional.of(path.substring(1));
      }
      if (host.endsWith("youtube.com")) {
        if ("/watch".equals(uri.getPath()) && uri.getQuery() != null) {
          for (var part : uri.getQuery().split("&")) {
            if (part.startsWith("v=") && part.length() > 2) return Optional.of(part.substring(2));
          }
        }
        if (uri.getPath() != null && uri.getPath().startsWith("/shorts/")) {
          return Optional.of(uri.getPath().substring("/shorts/".length()).split("/")[0]);
        }
      }
    } catch (IllegalArgumentException ignored) {
      // It is a song title rather than a URL.
    }
    return Optional.empty();
  }

  private String thumbnailUrl(Map<?, ?> thumbnails) {
    for (var quality : List.of("maxres", "standard", "high", "medium", "default")) {
      var image = map(thumbnails.get(quality));
      if (image.isPresent()) {
        var url = string(image.get().get("url"));
        if (!url.isBlank()) return url;
      }
    }
    return "";
  }

  private Optional<Map<?, ?>> firstMap(Map<?, ?> response, String key) {
    if (response == null || !(response.get(key) instanceof List<?> items) || items.isEmpty()) {
      return Optional.empty();
    }
    return map(items.getFirst());
  }

  private Optional<Map<?, ?>> map(Object value) {
    return value instanceof Map<?, ?> valueMap ? Optional.of(valueMap) : Optional.empty();
  }

  private String string(Object value) {
    return value == null ? "" : value.toString().trim();
  }

  public record VideoMetadata(
      String title,
      String channelTitle,
      String description,
      int year,
      String thumbnailUrl,
      String sourceUrl) {}
}
