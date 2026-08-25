package com.telugutunes.api.api.dto;

import java.util.List;

public record PlaylistResponse(
    String id,
    String name,
    String description,
    String color,
    List<TrackResponse> tracks,
    List<String> sharedWithMemberIds) {}
