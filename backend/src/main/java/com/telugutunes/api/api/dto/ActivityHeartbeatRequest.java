package com.telugutunes.api.api.dto;

public record ActivityHeartbeatRequest(
    Boolean appActive,
    Boolean playing,
    String trackId,
    Integer listenedSeconds,
    String title,
    String artist,
    String album,
    String genre,
    String source) {}
