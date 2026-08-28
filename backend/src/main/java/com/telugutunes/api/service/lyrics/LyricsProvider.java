package com.telugutunes.api.service.lyrics;

import com.telugutunes.api.domain.TrackDocument;
import java.util.Optional;

public interface LyricsProvider {
  String name();
  Optional<LyricsMatch> find(TrackDocument track);

  record LyricsMatch(
      String source, String sourceUrl, String plainLyrics, String syncedLyrics, double confidence) {}
}
