package com.telugutunes.api.api.dto;

import java.util.List;

public record RecommendedPlaylistResponse(
    String id,
    String name,
    String description,
    String type,
    String subtype,
    String color,
    String artworkUrl,
    List<TrackResponse> tracks,
    boolean active) {}
