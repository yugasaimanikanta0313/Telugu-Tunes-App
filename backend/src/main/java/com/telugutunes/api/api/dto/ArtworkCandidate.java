package com.telugutunes.api.api.dto;

public record ArtworkCandidate(
    String imageUrl,
    String title,
    String artist,
    String album,
    String source,
    String sourceUrl) {}
