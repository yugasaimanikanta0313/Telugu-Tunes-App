package com.telugutunes.api.api.dto;

import java.util.List;

public record HomeResponse(
    List<CollectionResponse> collections,
    List<AlbumResponse> featuredAlbums,
    List<TrackResponse> recentlyPlayed) {}
