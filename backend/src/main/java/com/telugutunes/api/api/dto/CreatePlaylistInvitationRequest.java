package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record CreatePlaylistInvitationRequest(@NotBlank @Email String email) {}
