package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RecommendationVoteRequest(
    @NotBlank String recommendedPlaylistId,
    @Size(max = 240) String reason) {}
