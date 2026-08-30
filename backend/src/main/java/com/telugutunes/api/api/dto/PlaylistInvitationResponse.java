package com.telugutunes.api.api.dto;

import java.time.Instant;

public record PlaylistInvitationResponse(
    String id,
    String playlistId,
    String playlistName,
    String inviterName,
    String status,
    Instant createdAt) {}
