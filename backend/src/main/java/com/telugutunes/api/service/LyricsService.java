package com.telugutunes.api.service;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.telugutunes.api.api.dto.LyricsResponse;
import com.telugutunes.api.api.dto.UpdateLyricsRequest;
import com.telugutunes.api.domain.LyricsDocument;
import com.telugutunes.api.repository.LyricsRepository;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import org.springframework.stereotype.Service;

@Service
public class LyricsService {
  private static final String LRCLIB = "https://lrclib.net/api/get";
  private final LyricsRepository lyrics;
  private final CatalogService catalog;
  private final AuthService auth;
  private final ObjectMapper json;
  private final HttpClient http = HttpClient.newBuilder()
      .connectTimeout(Duration.ofSeconds(5))
      .build();

  public LyricsService(
      LyricsRepository lyrics, CatalogService catalog, AuthService auth, ObjectMapper json) {
    this.lyrics = lyrics;
    this.catalog = catalog;
    this.auth = auth;
    this.json = json;
  }

  public LyricsResponse get(String trackId) {
    return response(lyrics.findById(trackId).orElseGet(() -> importFromLrclib(trackId, "system")));
  }

  public LyricsResponse refresh(String memberId, String trackId) {
    auth.requireAdministrator(memberId);
    lyrics.deleteById(trackId);
    return response(importFromLrclib(trackId, memberId));
  }

  public LyricsResponse update(String memberId, String trackId, UpdateLyricsRequest request) {
    auth.requireAdministrator(memberId);
    catalog.trackDocument(trackId);
    var document = new LyricsDocument(
        trackId,
        blankDefault(request.language(), "te"),
        "manual",
        request.plainLyrics().trim(),
        request.syncedLyrics().trim(),
        memberId,
        Instant.now());
    return response(lyrics.save(document));
  }

  private LyricsDocument importFromLrclib(String trackId, String updatedBy) {
    var track = catalog.trackDocument(trackId);
    var now = Instant.now();
    try {
      var uri = URI.create(LRCLIB
          + "?track_name=" + encode(track.title())
          + "&artist_name=" + encode(track.artist())
          + "&album_name=" + encode(track.album())
          + "&duration=" + Math.max(0, track.durationSeconds()));
      var request = HttpRequest.newBuilder(uri)
          .timeout(Duration.ofSeconds(8))
          .header("Accept", "application/json")
          .header("User-Agent", "TeluguTunes/1.0 (https://github.com/yugasaimanikanta0313/Telugu-Tunes-App)")
          .GET()
          .build();
      var result = http.send(request, HttpResponse.BodyHandlers.ofString());
      if (result.statusCode() >= 200 && result.statusCode() < 300) {
        JsonNode body = json.readTree(result.body());
        var plain = body.path("plainLyrics").asText("").trim();
        var synced = body.path("syncedLyrics").asText("").trim();
        return lyrics.save(new LyricsDocument(
            trackId, "te", "lrclib", plain, synced, updatedBy, now));
      }
    } catch (Exception ignored) {
      // An empty cached result keeps playback independent from the community API.
    }
    return lyrics.save(new LyricsDocument(
        trackId, "te", "unavailable", "", "", updatedBy, now));
  }

  private LyricsResponse response(LyricsDocument value) {
    return new LyricsResponse(
        value.trackId(), value.language(), value.source(),
        blankDefault(value.plainLyrics(), ""), blankDefault(value.syncedLyrics(), ""),
        value.updatedAt());
  }

  private String encode(String value) {
    return URLEncoder.encode(blankDefault(value, ""), StandardCharsets.UTF_8);
  }

  private String blankDefault(String value, String fallback) {
    return value == null || value.isBlank() ? fallback : value;
  }
}
