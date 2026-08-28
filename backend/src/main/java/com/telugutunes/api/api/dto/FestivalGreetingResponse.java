package com.telugutunes.api.api.dto;

import java.time.LocalDate;

public record FestivalGreetingResponse(
    String id,
    LocalDate date,
    String festival,
    String greeting,
    String artworkUrl,
    String color,
    boolean enabled,
    boolean builtIn) {}
