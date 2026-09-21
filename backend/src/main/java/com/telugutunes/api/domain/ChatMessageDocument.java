package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.Map;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("chat_messages")
public record ChatMessageDocument(
    @Id String id, String conversationId, String senderId, String clientId,
    String kind, String text, String mediaId, String fileName,
    String replyToId, String replyText, Map<String, String> reactions,
    Instant seenAt, Instant createdAt) {}
