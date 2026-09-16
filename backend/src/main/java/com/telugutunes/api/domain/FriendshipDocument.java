package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("friendships")
public record FriendshipDocument(
    @Id String id, String requesterId, String recipientId,
    String status, Instant createdAt) {}
