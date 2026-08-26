package com.telugutunes.api.api.dto;

public record TrackAudioReplacementResponse(
    TrackResponse track, long originalBytes, long storedBytes, boolean compressed) {}
