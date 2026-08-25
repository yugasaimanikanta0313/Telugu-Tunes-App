package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateRoomRequest(@NotBlank String name, String currentTrackId, boolean publicRoom) {}
