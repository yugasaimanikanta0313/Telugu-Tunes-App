package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.AlbumDocument;
import com.telugutunes.api.domain.LyricsDocument;
import com.telugutunes.api.domain.PlaylistDocument;
import com.telugutunes.api.domain.RecommendedPlaylistDocument;
import com.telugutunes.api.domain.TrackDocument;
import java.time.Instant;
import java.util.List;

/** Metadata backup only. Passwords, API keys, sessions, and audio bytes are never exported. */
public record BackupSnapshot(
    int schemaVersion,
    Instant exportedAt,
    List<TrackDocument> tracks,
    List<AlbumDocument> albums,
    List<PlaylistDocument> playlists,
    List<RecommendedPlaylistDocument> recommendedPlaylists,
    List<LyricsDocument> lyrics) {}
