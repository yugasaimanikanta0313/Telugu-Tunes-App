package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("favorites")
public record FavoriteDocument(
    @Id String id,
    String memberId,
    String trackId,
    Instant createdAt) {}
