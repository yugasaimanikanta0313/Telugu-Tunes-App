package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("trackLyrics")
public record LyricsDocument(
    @Id String trackId,
    String language,
    String source,
    String plainLyrics,
    String syncedLyrics,
    String sourceUrl,
    Double confidence,
    String updatedByMemberId,
    Instant updatedAt) {}
