package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateAlbumRequest(
    @NotBlank @Size(max = 160) String title,
    @Size(max = 160) String artist,
    @Size(max = 600) String description,
    @Min(0) @Max(2100) int year,
    @Size(max = 6) String color,
    boolean movie) {}
