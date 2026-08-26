package com.telugutunes.api.api.dto;

import java.util.List;

public record MetadataSuggestionResponse(
    String title,
    String artist,
    String album,
    String singers,
    String musicDirector,
    String genre,
    int year,
    String color,
    String thumbnailUrl,
    String sourceUrl,
    String source,
    boolean generated,
    String notice,
    List<ArtworkCandidate> artworkCandidates) {}
