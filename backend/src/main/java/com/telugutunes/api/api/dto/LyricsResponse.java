package com.telugutunes.api.api.dto;

import java.time.Instant;

public record LyricsResponse(
    String trackId,
    String language,
    String source,
    String plainLyrics,
    String syncedLyrics,
    Instant updatedAt) {}
