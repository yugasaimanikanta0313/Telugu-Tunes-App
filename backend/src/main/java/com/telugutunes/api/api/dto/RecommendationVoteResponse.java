package com.telugutunes.api.api.dto;

import java.util.List;

public record RecommendationVoteResponse(
    String trackId,
    String recommendedPlaylistId,
    TrackResponse track,
    RecommendedPlaylistResponse playlist,
    long voteCount,
    List<String> reasons) {}
