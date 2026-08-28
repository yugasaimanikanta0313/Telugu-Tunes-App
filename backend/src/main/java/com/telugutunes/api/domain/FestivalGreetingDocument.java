package com.telugutunes.api.domain;

import java.time.Instant;
import java.time.LocalDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("festival_greetings")
public record FestivalGreetingDocument(
    @Id String id,
    LocalDate date,
    String festival,
    String greeting,
    String artworkUrl,
    String color,
    boolean enabled,
    Instant updatedAt) {}
