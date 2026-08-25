package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("auth_sessions")
public record AuthSessionDocument(
    @Id String id, String tokenHash, String memberId, Instant expiresAt, Instant createdAt) {}
