package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateTrackRequest(
    @NotBlank @Size(max = 220) String title,
    @Size(max = 160) String artist,
    @Size(max = 160) String album,
    @Size(max = 220) String singers,
    @Size(max = 160) String musicDirector,
    @Size(max = 100) String genre,
    @Size(max = 6) String color,
    @Size(max = 2000) String artworkUrl,
    @Size(max = 2000) String sourceUrl) {}
