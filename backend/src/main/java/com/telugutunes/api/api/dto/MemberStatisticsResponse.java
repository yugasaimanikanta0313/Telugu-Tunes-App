package com.telugutunes.api.api.dto;

import com.telugutunes.api.domain.PlaybackHistoryItem;
import java.util.List;
import java.util.Map;

public record MemberStatisticsResponse(
    String memberId,
    int days,
    long totalSeconds,
    List<DailyPoint> daily,
    Map<String, Long> categories,
    Map<String, Long> sources,
    List<PlaybackHistoryItem> playbackOrder) {

  public record DailyPoint(String date, long seconds) {}
}
