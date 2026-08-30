package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("playlist_invitations")
public record PlaylistInvitationDocument(
    @Id String id,
    String playlistId,
    String inviterMemberId,
    String inviteeMemberId,
    String status,
    Instant createdAt,
    Instant respondedAt) {}
