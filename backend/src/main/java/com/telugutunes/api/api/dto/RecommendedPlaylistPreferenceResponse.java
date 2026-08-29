package com.telugutunes.api.api.dto;

import java.util.List;

public record RecommendedPlaylistPreferenceResponse(
    String playlistId,
    boolean enabled,
    List<Integer> scheduleDays,
    String scheduleStart,
    String scheduleEnd) {}
