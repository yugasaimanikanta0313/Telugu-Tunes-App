package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("recommended_playlists")
public record RecommendedPlaylistDocument(
    @Id String id,
    String name,
    String description,
    String type,
    String subtype,
    String artworkColor,
    String artworkUrl,
    List<String> trackIds,
    boolean active,
    Boolean scheduleEnabled,
    List<Integer> scheduleDays,
    String scheduleStart,
    String scheduleEnd,
    Instant createdAt,
    Instant updatedAt) {}
