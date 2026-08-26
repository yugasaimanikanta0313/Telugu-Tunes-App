package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.TrackDocument;

public record TrackResponse(
    String id,
    String title,
    String artist,
    String album,
    String albumId,
    String duration,
    String color,
    String singers,
    String musicDirector,
    String genre,
    String artworkUrl,
    String sourceUrl,
    String audioVersion,
    boolean downloaded) {

  public static TrackResponse from(TrackDocument track) {
    return new TrackResponse(
        track.id(),
        track.title(),
        track.artist(),
        track.album(),
        track.albumId(),
        track.duration(),
        track.artworkColor(),
        track.singers(),
        track.musicDirector(),
        track.genre(),
        track.artworkUrl(),
        track.sourceUrl(),
        Integer.toHexString(java.util.Objects.hash(track.driveFileId(), track.mimeType())),
        false);
  }
}
