package com.telugutunes.api.domain;

import java.time.Instant;

public record PlaybackHistoryItem(
    String trackId,
    String title,
    String artist,
    String album,
    String genre,
    String source,
    Instant startedAt) {}
