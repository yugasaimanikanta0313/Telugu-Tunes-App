package com.telugutunes.api.service.lyrics;

import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.TrackDocument;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Component
@Order(10)
public class LrclibLyricsProvider implements LyricsProvider {
  private static final Logger log = LoggerFactory.getLogger(LrclibLyricsProvider.class);
  private final ObjectMapper json;
  private final AppProperties.Provider properties;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

  public LrclibLyricsProvider(ObjectMapper json, AppProperties properties) {
    this.json = json;
    this.properties = properties.getLyrics().getLrclib();
  }

  @Override public String name() { return "lrclib"; }

  @Override
  public Optional<LyricsMatch> find(TrackDocument track) {
    if (!properties.isEnabled()) return Optional.empty();
    try {
      var exact = URI.create("https://lrclib.net/api/get?track_name=" + encode(track.title())
          + "&artist_name=" + encode(track.artist()) + "&album_name=" + encode(track.album())
          + "&duration=" + Math.max(0, track.durationSeconds()));
      var match = request(exact);
      var sourceUrl = exact.toString();
      if (match == null) {
        var search = URI.create("https://lrclib.net/api/search?track_name=" + encode(track.title())
            + "&artist_name=" + encode(track.artist()));
        match = best(request(search), track);
        sourceUrl = search.toString();
      }
      if (match == null) {
        var search = URI.create("https://lrclib.net/api/search?q=" + encode(track.title() + " " + track.artist()));
        match = best(request(search), track);
        sourceUrl = search.toString();
      }
      if (match != null) {
        var synced = match.path("syncedLyrics").asText("").trim();
        if (LrcValidator.isSynced(synced)) {
          var plain = match.path("plainLyrics").asText("").trim();
          return Optional.of(new LyricsMatch("lrclib", sourceUrl,
              plain.isBlank() ? LrcValidator.plainText(synced) : plain, synced, 1.0));
        }
      }
    } catch (Exception exception) {
      log.info("LRCLIB lookup failed for {}: {}", track.title(), exception.getClass().getSimpleName());
    }
    log.info("LRCLIB miss for {}", track.title());
    return Optional.empty();
  }

  private JsonNode request(URI uri) throws Exception {
    var request = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(8))
        .header("Accept", "application/json")
        .header("User-Agent", "TeluguTunes/1.0 (+https://github.com/yugasaimanikanta0313/Telugu-Tunes-App)")
        .GET().build();
    var response = http.send(request, HttpResponse.BodyHandlers.ofString());
    return response.statusCode() >= 200 && response.statusCode() < 300 ? json.readTree(response.body()) : null;
  }

  private JsonNode best(JsonNode results, TrackDocument track) {
    if (results == null || !results.isArray()) return null;
    JsonNode best = null; double bestScore = 0;
    for (var candidate : results) {
      if (!LrcValidator.isSynced(candidate.path("syncedLyrics").asText(""))) continue;
      var score = 0.65 * LyricsSimilarity.score(track.title(), candidate.path("trackName").asText(""))
          + 0.25 * LyricsSimilarity.score(track.artist(), candidate.path("artistName").asText(""));
      var candidateDuration = candidate.path("duration").asInt(0);
      score += 0.10 * durationScore(track.durationSeconds(), candidateDuration);
      if (score > bestScore) { bestScore = score; best = candidate; }
    }
    return bestScore >= 0.60 ? best : null;
  }

  private double durationScore(int wanted, int found) {
    if (wanted <= 0 || found <= 0) return 0.5;
    var difference = Math.abs(wanted - found);
    return difference <= 2 ? 1 : difference <= 10 ? 0.6 : 0;
  }

  private String encode(String value) {
    return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
  }
}
