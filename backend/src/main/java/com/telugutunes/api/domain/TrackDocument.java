package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("tracks")
public record TrackDocument(
    @Id String id,
    String title,
    String artist,
    String album,
    String albumId,
    String duration,
    int durationSeconds,
    String artworkColor,
    String singers,
    String musicDirector,
    String genre,
    String artworkUrl,
    String sourceUrl,
    String driveFileId,
    String mimeType,
    String uploadedByMemberId,
    Instant createdAt) {}
