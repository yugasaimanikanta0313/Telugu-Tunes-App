package com.telugutunes.api.api.dto;

import java.time.Instant;

public record BackupPreviewResponse(
    int schemaVersion,
    Instant exportedAt,
    int tracks,
    int albums,
    int playlists,
    int recommendedPlaylists,
    int lyrics,
    boolean safeMerge) {}
