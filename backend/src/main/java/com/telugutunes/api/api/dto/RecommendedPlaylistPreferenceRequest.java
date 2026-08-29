package com.telugutunes.api.api.dto;

import java.util.List;

public record RecommendedPlaylistPreferenceRequest(
    Boolean enabled,
    List<Integer> scheduleDays,
    String scheduleStart,
    String scheduleEnd) {}
