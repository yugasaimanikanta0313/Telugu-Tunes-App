package com.telugutunes.api.service.lyrics;

import com.telugutunes.api.config.AppProperties;
import com.telugutunes.api.domain.TrackDocument;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Component
@Order(20)
public class LyricsifyLyricsProvider implements LyricsProvider {
  private static final Logger log = LoggerFactory.getLogger(LyricsifyLyricsProvider.class);
  private static final URI BASE = URI.create("https://www.lyricsify.com/");
  private final LyricsifyPageFetcher fetcher;
  private final LyricsifyParser parser;
  private final AppProperties.Lyricsify properties;

  public LyricsifyLyricsProvider(
      LyricsifyPageFetcher fetcher, LyricsifyParser parser, AppProperties properties) {
    this.fetcher = fetcher;
    this.parser = parser;
    this.properties = properties.getLyrics().getLyricsify();
  }

  @Override public String name() { return "lyricsify"; }

  @Override
  public Optional<LyricsMatch> find(TrackDocument track) {
    if (!properties.isEnabled()) return Optional.empty();
    var candidates = new LinkedHashMap<URI, LyricsifyParser.Candidate>();
    for (var query : queries(track)) {
      var searchUri = BASE.resolve("search?q=" + URLEncoder.encode(query, StandardCharsets.UTF_8));
      fetcher.fetch(searchUri).ifPresent(html -> parser.searchResults(html, BASE)
          .forEach(candidate -> candidates.putIfAbsent(candidate.uri(), candidate)));
      if (!candidates.isEmpty()) break;
    }
    LyricsifyParser.Candidate selected = null; double selectedScore = 0;
    for (var candidate : candidates.values()) {
      var score = confidence(track, candidate);
      log.info("Lyricsify candidate score={} title={}", String.format("%.2f", score), candidate.title());
      if (score > selectedScore) { selected = candidate; selectedScore = score; }
    }
    if (selected == null || selectedScore < properties.getMinimumConfidence()) {
      log.info("Lyricsify miss for {}", track.title());
      return Optional.empty();
    }
    var page = fetcher.fetch(selected.uri());
    if (page.isEmpty()) return Optional.empty();
    var extracted = parser.extract(page.get(), selected.uri());
    var lrc = extracted.lrc();
    if (lrc.isEmpty() && extracted.rawLrcUri().isPresent()) {
      lrc = fetcher.fetch(extracted.rawLrcUri().get()).filter(LrcValidator::isSynced).map(String::trim);
    }
    if (lrc.isEmpty() || !LrcValidator.isSynced(lrc.get())) return Optional.empty();
    log.info("Lyricsify LRC accepted for trackId={}", track.id());
    return Optional.of(new LyricsMatch("lyricsify", selected.uri().toString(),
        LrcValidator.plainText(lrc.get()), lrc.get(), selectedScore));
  }

  double confidence(TrackDocument track, LyricsifyParser.Candidate candidate) {
    var artist = track.singers() == null || track.singers().isBlank() ? track.artist() : track.singers();
    var title = LyricsSimilarity.score(track.title(), candidate.title());
    var artistScore = LyricsSimilarity.score(artist, candidate.artist());
    var album = LyricsSimilarity.score(track.album(), candidate.album());
    if (candidate.album().isBlank()) album = 0.5;
    var duration = durationScore(track.durationSeconds(), candidate.durationSeconds());
    return 0.50 * title + 0.25 * artistScore + 0.15 * album + 0.10 * duration;
  }

  private double durationScore(int wanted, int found) {
    if (wanted <= 0 || found <= 0) return 0.5;
    var difference = Math.abs(wanted - found);
    return difference <= 2 ? 1 : difference <= 10 ? 0.6 : 0;
  }

  private List<String> queries(TrackDocument track) {
    var artist = track.singers() == null || track.singers().isBlank() ? track.artist() : track.singers();
    return List.of(track.title() + " " + artist,
        track.title() + " " + track.album(), track.title() + " " + artist + " " + track.album());
  }
}
