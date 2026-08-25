package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("listening_rooms")
public record ListeningRoomDocument(
    @Id String id,
    String name,
    String hostMemberId,
    String inviteCode,
    Boolean publicRoom,
    List<String> memberIds,
    String currentTrackId,
    List<String> queueTrackIds,
    Long playbackPositionMs,
    Boolean playbackPlaying,
    Instant playbackUpdatedAt,
    boolean active,
    Instant createdAt,
    Instant updatedAt) {}
