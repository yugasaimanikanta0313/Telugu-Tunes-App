package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("albums")
public record AlbumDocument(
    @Id String id,
    String title,
    String artist,
    String description,
    int year,
    String artworkColor,
    String artworkUrl,
    boolean movie,
    List<String> trackIds,
    Instant createdAt) {}
