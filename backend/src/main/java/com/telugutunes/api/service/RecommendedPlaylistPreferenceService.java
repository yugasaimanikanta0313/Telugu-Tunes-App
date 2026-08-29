package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.RecommendedPlaylistPreferenceRequest;
import com.telugutunes.api.api.dto.RecommendedPlaylistPreferenceResponse;
import com.telugutunes.api.domain.RecommendedPlaylistPreferenceDocument;
import com.telugutunes.api.repository.RecommendedPlaylistPreferenceRepository;
import com.telugutunes.api.repository.RecommendedPlaylistRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class RecommendedPlaylistPreferenceService {
  private final RecommendedPlaylistPreferenceRepository preferences;
  private final RecommendedPlaylistRepository playlists;

  public RecommendedPlaylistPreferenceService(
      RecommendedPlaylistPreferenceRepository preferences,
      RecommendedPlaylistRepository playlists) {
    this.preferences = preferences;
    this.playlists = playlists;
  }

  public List<RecommendedPlaylistPreferenceResponse> list(String memberId) {
    return preferences.findAllByMemberId(memberId).stream().map(this::response).toList();
  }

  public RecommendedPlaylistPreferenceResponse save(
      String memberId, String playlistId, RecommendedPlaylistPreferenceRequest request) {
    if (!playlists.existsById(playlistId)) {
      throw new IllegalArgumentException("Recommended playlist not found.");
    }
    var saved = preferences.save(new RecommendedPlaylistPreferenceDocument(
        id(memberId, playlistId), memberId, playlistId,
        request.enabled() == null || request.enabled(), validDays(request.scheduleDays()),
        clean(request.scheduleStart()), clean(request.scheduleEnd()), Instant.now()));
    return response(saved);
  }

  public void reset(String memberId, String playlistId) {
    preferences.deleteById(id(memberId, playlistId));
  }

  private RecommendedPlaylistPreferenceResponse response(RecommendedPlaylistPreferenceDocument value) {
    return new RecommendedPlaylistPreferenceResponse(value.playlistId(), value.enabled(),
        validDays(value.scheduleDays()), clean(value.scheduleStart()), clean(value.scheduleEnd()));
  }

  private String id(String memberId, String playlistId) { return memberId + ":" + playlistId; }
  private String clean(String value) { return value == null ? "" : value.trim(); }
  private List<Integer> validDays(List<Integer> days) {
    if (days == null) return List.of();
    return days.stream().filter(day -> day != null && day >= 1 && day <= 7).distinct().sorted().toList();
  }
}
