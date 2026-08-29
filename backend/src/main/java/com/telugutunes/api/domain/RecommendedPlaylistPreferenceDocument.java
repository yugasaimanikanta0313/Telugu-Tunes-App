package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("recommended_playlist_preferences")
public record RecommendedPlaylistPreferenceDocument(
    @Id String id,
    String memberId,
    String playlistId,
    boolean enabled,
    List<Integer> scheduleDays,
    String scheduleStart,
    String scheduleEnd,
    Instant updatedAt) {}
