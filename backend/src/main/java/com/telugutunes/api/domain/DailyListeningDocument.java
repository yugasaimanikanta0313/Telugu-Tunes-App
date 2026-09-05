package com.telugutunes.api.domain;

import java.util.List;
import java.util.Map;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("daily_listening_statistics")
public record DailyListeningDocument(
    @Id String id,
    String memberId,
    String date,
    long listeningSeconds,
    Map<String, Long> categorySeconds,
    Map<String, Long> sourceSeconds,
    List<PlaybackHistoryItem> playbackOrder) {}
