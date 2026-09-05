package com.telugutunes.api.domain;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("member_activity")
public record MemberActivityDocument(
    @Id String memberId,
    long listeningSeconds,
    String currentTrackId,
    boolean appActive,
    boolean playing,
    Instant lastSeenAt) {}
