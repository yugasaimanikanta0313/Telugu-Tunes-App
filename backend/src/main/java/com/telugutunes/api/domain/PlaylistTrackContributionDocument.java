package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("playlist_track_contributions")
public record PlaylistTrackContributionDocument(
    @Id String id,
    String playlistId,
    String trackId,
    String memberId,
    Instant addedAt) {}
