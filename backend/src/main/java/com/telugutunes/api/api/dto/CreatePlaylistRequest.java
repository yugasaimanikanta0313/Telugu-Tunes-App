package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreatePlaylistRequest(
    @NotBlank @Size(max = 100) String name,
    @Size(max = 300) String description,
    @Size(max = 7) String color) {}
