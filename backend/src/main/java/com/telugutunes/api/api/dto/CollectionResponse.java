package com.telugutunes.api.api.dto;

import java.util.List;

public record CollectionResponse(
    String id, String title, String subtitle, String color, String kind, List<TrackResponse> tracks) {}
