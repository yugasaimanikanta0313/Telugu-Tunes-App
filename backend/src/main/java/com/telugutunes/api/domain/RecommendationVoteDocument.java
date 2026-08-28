package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("recommendation_votes")
public record RecommendationVoteDocument(
    @Id String id,
    String memberId,
    String trackId,
    String recommendedPlaylistId,
    String reason,
    String status,
    Instant createdAt,
    Instant updatedAt,
    String reviewedBy,
    Instant reviewedAt) {}
