package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateLyricsRequest(
    @NotNull String language,
    @NotNull String plainLyrics,
    @NotNull String syncedLyrics) {}
