package com.telugutunes.api.api.dto;

import java.util.List;

public record RoomResponse(
    String id,
    String name,
    String hostMemberId,
    String inviteCode,
    boolean publicRoom,
    int listeners,
    TrackResponse track,
    List<TrackResponse> queue,
    long positionMs,
    boolean playing,
    boolean active) {}
