package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.AlbumDocument;
import java.util.List;

public record AlbumResponse(
    String id,
    String title,
    String artist,
    String description,
    int year,
    String color,
    String artworkUrl,
    boolean movie,
    List<TrackResponse> tracks) {}
