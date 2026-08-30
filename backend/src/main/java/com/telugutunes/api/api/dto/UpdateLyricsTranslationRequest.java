package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateLyricsTranslationRequest(
    @NotNull String englishPlainLyrics,
    @NotNull String englishSyncedLyrics) {}
