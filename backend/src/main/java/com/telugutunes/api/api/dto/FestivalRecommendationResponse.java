package com.telugutunes.api.api.dto;

import java.util.List;

public record FestivalRecommendationResponse(
    FestivalGreetingResponse festival,
    List<RecommendedPlaylistResponse> playlists) {}
