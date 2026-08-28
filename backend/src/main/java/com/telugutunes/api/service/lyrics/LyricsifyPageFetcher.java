package com.telugutunes.api.service.lyrics;

import java.net.URI;
import java.util.Optional;

/** Isolates page retrieval so a browser-backed implementation can be added without changing parsing. */
public interface LyricsifyPageFetcher {
  Optional<String> fetch(URI uri);
}
