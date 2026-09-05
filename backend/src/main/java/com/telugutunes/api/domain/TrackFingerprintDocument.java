package com.telugutunes.api.domain;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("track_fingerprints")
public record TrackFingerprintDocument(
    @Id String id,
    String trackId,
    String fileSha256,
    List<Integer> acousticFingerprint,
    int durationSeconds,
    Instant createdAt) {}
