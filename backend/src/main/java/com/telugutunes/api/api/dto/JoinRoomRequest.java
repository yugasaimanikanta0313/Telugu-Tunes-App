package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;

public record JoinRoomRequest(@NotBlank String inviteCode) {}
