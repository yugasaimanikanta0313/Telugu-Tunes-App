package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ActivityHeartbeatRequest;
import com.telugutunes.api.api.dto.MemberStatisticsResponse;
import com.telugutunes.api.domain.DailyListeningDocument;
import com.telugutunes.api.domain.PlaybackHistoryItem;
import com.telugutunes.api.repository.DailyListeningRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class ListeningStatisticsService {
  private static final int HISTORY_LIMIT_PER_DAY = 250;
  private final DailyListeningRepository statistics;
  private final AuthService auth;

  public ListeningStatisticsService(DailyListeningRepository statistics, AuthService auth) {
    this.statistics = statistics;
    this.auth = auth;
  }

  public synchronized void record(String memberId, ActivityHeartbeatRequest request, int seconds) {
    if (seconds <= 0 || request == null || clean(request.trackId()).isEmpty()) return;
    var date = LocalDate.now(ZoneOffset.UTC).toString();
    var id = memberId + ":" + date;
    var previous = statistics.findById(id).orElse(new DailyListeningDocument(
        id, memberId, date, 0, Map.of(), Map.of(), List.of()));
    var categories = new LinkedHashMap<>(safe(previous.categorySeconds()));
    var sources = new LinkedHashMap<>(safe(previous.sourceSeconds()));
    categories.merge(label(request.genre(), "Uncategorised"), (long) seconds, Long::sum);
    sources.merge(sourceType(request.source()), (long) seconds, Long::sum);
    var history = new ArrayList<>(previous.playbackOrder() == null ? List.<PlaybackHistoryItem>of() : previous.playbackOrder());
    var last = history.isEmpty() ? null : history.get(history.size() - 1);
    if (last == null || !last.trackId().equals(request.trackId()) || !last.source().equals(clean(request.source()))) {
      history.add(new PlaybackHistoryItem(clean(request.trackId()), label(request.title(), "Unknown song"),
          label(request.artist(), "Unknown artist"), label(request.album(), "Unknown album"),
          label(request.genre(), "Uncategorised"), sourceType(request.source()), Instant.now()));
      if (history.size() > HISTORY_LIMIT_PER_DAY) history.remove(0);
    }
    statistics.save(new DailyListeningDocument(id, memberId, date,
        previous.listeningSeconds() + seconds, categories, sources, history));
  }

  public MemberStatisticsResponse statistics(String administratorId, String memberId, int requestedDays) {
    auth.requireAdministrator(administratorId);
    int days = Math.max(7, Math.min(90, requestedDays));
    var rows = statistics.findByMemberIdAndDateGreaterThanEqualOrderByDateAsc(
        memberId, LocalDate.now(ZoneOffset.UTC).minusDays(days - 1L).toString());
    var dailyByDate = new LinkedHashMap<String, Long>();
    var categories = new LinkedHashMap<String, Long>();
    var sources = new LinkedHashMap<String, Long>();
    var order = new ArrayList<PlaybackHistoryItem>();
    for (int offset = days - 1; offset >= 0; offset--) {
      dailyByDate.put(LocalDate.now(ZoneOffset.UTC).minusDays(offset).toString(), 0L);
    }
    for (var row : rows) {
      dailyByDate.put(row.date(), row.listeningSeconds());
      safe(row.categorySeconds()).forEach((key, value) -> categories.merge(key, value, Long::sum));
      safe(row.sourceSeconds()).forEach((key, value) -> sources.merge(key, value, Long::sum));
      if (row.playbackOrder() != null) order.addAll(row.playbackOrder());
    }
    var daily = dailyByDate.entrySet().stream()
        .map(entry -> new MemberStatisticsResponse.DailyPoint(entry.getKey(), entry.getValue()))
        .toList();
    order.sort((a, b) -> b.startedAt().compareTo(a.startedAt()));
    if (order.size() > 200) order = new ArrayList<>(order.subList(0, 200));
    return new MemberStatisticsResponse(memberId, days,
        rows.stream().mapToLong(DailyListeningDocument::listeningSeconds).sum(),
        daily, categories, sources, order);
  }

  private Map<String, Long> safe(Map<String, Long> value) {
    return value == null ? Map.of() : value;
  }

  private String clean(String value) { return value == null ? "" : value.trim(); }
  private String label(String value, String fallback) { var clean = clean(value); return clean.isEmpty() ? fallback : clean; }
  private String sourceType(String value) {
    var clean = clean(value).toLowerCase(java.util.Locale.ROOT);
    if (clean.startsWith("recommended")) return "Recommended playlist";
    if (clean.startsWith("personal")) return "Personal playlist";
    if (clean.startsWith("album")) return "Album";
    return "Catalog / search";
  }
}
