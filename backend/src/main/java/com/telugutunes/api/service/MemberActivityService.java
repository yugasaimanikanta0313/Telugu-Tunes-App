package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ActivityHeartbeatRequest;
import com.telugutunes.api.domain.MemberActivityDocument;
import com.telugutunes.api.repository.MemberActivityRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

@Service
public class MemberActivityService {
  private static final Duration ONLINE_WINDOW = Duration.ofSeconds(75);
  private final MemberActivityRepository activities;
  private final ListeningStatisticsService statistics;

  public MemberActivityService(MemberActivityRepository activities, ListeningStatisticsService statistics) {
    this.activities = activities;
    this.statistics = statistics;
  }

  public void heartbeat(String memberId, ActivityHeartbeatRequest request) {
    if (request == null) return;
    var previous = activities.findById(memberId).orElse(null);
    var listened = previous == null ? 0L : previous.listeningSeconds();
    var increment = 0;
    if (Boolean.TRUE.equals(request.appActive()) && Boolean.TRUE.equals(request.playing())) {
      increment = Math.max(0, Math.min(60, request.listenedSeconds() == null ? 0 : request.listenedSeconds()));
      listened += increment;
    }
    statistics.record(memberId, request, increment);
    activities.save(new MemberActivityDocument(
        memberId,
        listened,
        clean(request.trackId()),
        Boolean.TRUE.equals(request.appActive()),
        Boolean.TRUE.equals(request.playing()),
        Instant.now()));
  }

  public Map<String, MemberActivityDocument> allByMemberId() {
    return activities.findAll().stream()
        .collect(Collectors.toMap(MemberActivityDocument::memberId, Function.identity()));
  }

  public boolean online(MemberActivityDocument activity, Instant now) {
    return activity != null && activity.appActive() && activity.lastSeenAt() != null
        && activity.lastSeenAt().isAfter(now.minus(ONLINE_WINDOW));
  }

  private String clean(String value) {
    return value == null ? "" : value.trim();
  }
}
