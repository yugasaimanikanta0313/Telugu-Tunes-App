package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.LyricsResponse;
import com.telugutunes.api.api.dto.UpdateLyricsRequest;
import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.LyricsDocument;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.service.lyrics.LrcValidator;
import com.telugutunes.api.service.lyrics.LyricsProvider;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class LyricsService {
  private static final Logger log = LoggerFactory.getLogger(LyricsService.class);
  private final LyricsRepository lyrics;
  private final CatalogService catalog;
  private final AuthService auth;
  private final List<LyricsProvider> providers;
  private final AppProperties properties;

  public LyricsService(
      LyricsRepository lyrics,
      CatalogService catalog,
      AuthService auth,
      List<LyricsProvider> providers,
      AppProperties properties) {
    this.lyrics = lyrics;
    this.catalog = catalog;
    this.auth = auth;
    this.providers = providers;
    this.properties = properties;
  }

  public LyricsResponse get(String trackId) {
    var cached = lyrics.findById(trackId);
    if (cached.isPresent() && isReusable(cached.get())) return response(cached.get());
    return response(resolve(trackId, "system"));
  }

  public LyricsResponse refresh(String memberId, String trackId) {
    auth.requireAdministrator(memberId);
    var cached = lyrics.findById(trackId);
    if (cached.isPresent() && "manual".equals(cached.get().source())) return response(cached.get());
    lyrics.deleteById(trackId);
    return response(resolve(trackId, memberId));
  }

  public LyricsResponse update(String memberId, String trackId, UpdateLyricsRequest request) {
    auth.requireAdministrator(memberId);
    catalog.trackDocument(trackId);
    var document = new LyricsDocument(
        trackId, blankDefault(request.language(), "te"), "manual",
        request.plainLyrics().trim(), request.syncedLyrics().trim(),
        null, 1.0, memberId, Instant.now());
    return response(lyrics.save(document));
  }

  private LyricsDocument resolve(String trackId, String updatedBy) {
    var track = catalog.trackDocument(trackId);
    for (var provider : providers) {
      log.info("Trying lyrics provider={} trackId={}", provider.name(), trackId);
      var match = provider.find(track);
      if (match.isPresent() && LrcValidator.isSynced(match.get().syncedLyrics())) {
        var found = match.get();
        log.info("Lyrics accepted provider={} trackId={} confidence={}",
            provider.name(), trackId, found.confidence());
        return lyrics.save(new LyricsDocument(
            trackId, "te", found.source(),
            blankDefault(found.plainLyrics(), LrcValidator.plainText(found.syncedLyrics())),
            found.syncedLyrics().trim(), found.sourceUrl(), found.confidence(),
            updatedBy, Instant.now()));
      }
      log.info("Lyrics provider miss provider={} trackId={}", provider.name(), trackId);
    }
    log.info("Lyrics unavailable after all providers trackId={}", trackId);
    return lyrics.save(new LyricsDocument(
        trackId, "te", "unavailable", "", "", null, 0.0, updatedBy, Instant.now()));
  }

  private boolean isReusable(LyricsDocument document) {
    if ("manual".equals(document.source())) return true;
    if (!"unavailable".equals(document.source())) {
      return LrcValidator.isSynced(document.syncedLyrics())
          || !blankDefault(document.plainLyrics(), "").isBlank();
    }
    var hours = Math.max(1, properties.getLyrics().getLyricsify().getRetryAfterHours());
    return document.updatedAt() != null
        && document.updatedAt().isAfter(Instant.now().minus(Duration.ofHours(hours)));
  }

  private LyricsResponse response(LyricsDocument value) {
    return new LyricsResponse(
        value.trackId(), value.language(), value.source(),
        blankDefault(value.plainLyrics(), ""), blankDefault(value.syncedLyrics(), ""),
        value.updatedAt());
  }

  private String blankDefault(String value, String fallback) {
    return value == null || value.isBlank() ? fallback : value;
  }
}
