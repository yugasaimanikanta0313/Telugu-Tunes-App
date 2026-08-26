package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("playlists")
public record PlaylistDocument(
    @Id String id,
    String ownerMemberId,
    String name,
    String description,
    String artworkColor,
    String artworkUrl,
    List<String> trackIds,
    List<String> sharedWithMemberIds,
    Instant createdAt,
    Instant updatedAt) {}
