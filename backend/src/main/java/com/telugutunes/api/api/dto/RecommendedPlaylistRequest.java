package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record RecommendedPlaylistRequest(
    @NotBlank @Size(max = 100) String name,
    @Size(max = 300) String description,
    @NotBlank @Size(max = 60) String type,
    @NotBlank @Size(max = 80) String subtype,
    @Size(max = 7) String color,
    @Size(max = 2000) String artworkUrl,
    List<String> trackIds,
    Boolean active,
    Boolean scheduleEnabled,
    List<Integer> scheduleDays,
    @Size(max = 5) String scheduleStart,
    @Size(max = 5) String scheduleEnd) {}
