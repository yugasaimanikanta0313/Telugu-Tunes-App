package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/** The host's current player state. Guests use it to follow the same moment. */
public record UpdateRoomPlaybackRequest(
    @NotBlank String trackId, @Min(0) long positionMs, boolean playing) {}
