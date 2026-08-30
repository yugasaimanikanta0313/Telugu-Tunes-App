package com.telugutunes.api.api.dto;

import java.util.List;
import java.util.Map;

public record PlaylistResponse(
    String id,
    String name,
    String description,
    String color,
    String artworkUrl,
    List<TrackResponse> tracks,
    List<String> sharedWithMemberIds,
    String ownerMemberId,
    Map<String, String> trackAddedByNames) {}
