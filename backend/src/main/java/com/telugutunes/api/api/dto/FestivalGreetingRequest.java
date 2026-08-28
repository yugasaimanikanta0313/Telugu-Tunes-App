package com.telugutunes.api.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record FestivalGreetingRequest(
    @NotNull LocalDate date,
    @NotBlank String festival,
    @NotBlank String greeting,
    String artworkUrl,
    String color,
    Boolean enabled) {}
