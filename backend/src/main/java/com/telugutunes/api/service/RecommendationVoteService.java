package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.RecommendationVoteRequest;
import com.telugutunes.api.api.dto.RecommendationVoteResponse;
import com.telugutunes.api.api.dto.TrackResponse;
import com.telugutunes.api.domain.RecommendationVoteDocument;
import com.telugutunes.api.domain.RecommendedPlaylistDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.RecommendationVoteRepository;
import com.telugutunes.api.repository.RecommendedPlaylistRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class RecommendationVoteService {
  private static final String PENDING = "PENDING";
  private final RecommendationVoteRepository votes;
  private final RecommendedPlaylistRepository playlists;
  private final RecommendedPlaylistService playlistService;
  private final CatalogService catalog;
  private final AuthService auth;

  public RecommendationVoteService(RecommendationVoteRepository votes,
      RecommendedPlaylistRepository playlists, RecommendedPlaylistService playlistService,
      CatalogService catalog, AuthService auth) {
    this.votes = votes;
    this.playlists = playlists;
    this.playlistService = playlistService;
    this.catalog = catalog;
    this.auth = auth;
  }

  public void vote(String memberId, String trackId, RecommendationVoteRequest request) {
    catalog.trackDocument(trackId);
    var playlist = playlist(request.recommendedPlaylistId());
    if (!playlist.active()) throw new IllegalArgumentException("This recommended playlist is hidden.");
    if (playlist.trackIds() != null && playlist.trackIds().contains(trackId)) {
      throw new IllegalArgumentException("This song is already in that playlist.");
    }
    var existing = votes.findByMemberIdAndTrackIdAndRecommendedPlaylistId(
        memberId, trackId, playlist.id()).orElse(null);
    var now = Instant.now();
    votes.save(new RecommendationVoteDocument(existing == null ? null : existing.id(), memberId,
        trackId, playlist.id(), clean(request.reason()), PENDING,
        existing == null ? now : existing.createdAt(), now, "", null));
  }

  public List<RecommendationVoteResponse> pending(String memberId) {
    auth.requireAdministrator(memberId);
    var groups = new LinkedHashMap<String, List<RecommendationVoteDocument>>();
    for (var vote : votes.findByStatusOrderByUpdatedAtDesc(PENDING)) {
      groups.computeIfAbsent(vote.trackId() + "|" + vote.recommendedPlaylistId(), ignored -> new ArrayList<>()).add(vote);
    }
    var result = new ArrayList<RecommendationVoteResponse>();
    for (var group : groups.values()) {
      var first = group.getFirst();
      var playlist = playlists.findById(first.recommendedPlaylistId()).orElse(null);
      if (playlist == null) continue;
      var track = catalog.trackDocument(first.trackId());
      var reasons = group.stream().map(RecommendationVoteDocument::reason)
          .filter(value -> value != null && !value.isBlank()).distinct().toList();
      result.add(new RecommendationVoteResponse(first.trackId(), playlist.id(), TrackResponse.from(track),
          playlistService.responseFor(playlist), group.size(), reasons));
    }
    return result;
  }

  public void review(String memberId, String playlistId, String trackId, boolean approve) {
    auth.requireAdministrator(memberId);
    catalog.trackDocument(trackId);
    var playlist = playlist(playlistId);
    var pending = votes.findByTrackIdAndRecommendedPlaylistIdAndStatus(trackId, playlistId, PENDING);
    if (pending.isEmpty()) throw new NotFoundException("Pending vote was not found.");
    if (approve && (playlist.trackIds() == null || !playlist.trackIds().contains(trackId))) {
      var ids = new ArrayList<>(playlist.trackIds() == null ? List.<String>of() : playlist.trackIds());
      ids.add(trackId);
      playlists.save(new RecommendedPlaylistDocument(playlist.id(), playlist.name(), playlist.description(),
          playlist.type(), playlist.subtype(), playlist.artworkColor(), playlist.artworkUrl(), ids,
          playlist.active(), playlist.scheduleEnabled(), playlist.scheduleDays(), playlist.scheduleStart(),
          playlist.scheduleEnd(), playlist.createdAt(), Instant.now()));
    }
    var now = Instant.now();
    votes.saveAll(pending.stream().map(value -> new RecommendationVoteDocument(value.id(), value.memberId(),
        value.trackId(), value.recommendedPlaylistId(), value.reason(), approve ? "APPROVED" : "REJECTED",
        value.createdAt(), now, memberId, now)).toList());
  }

  private RecommendedPlaylistDocument playlist(String id) {
    return playlists.findById(id).orElseThrow(() -> new NotFoundException("Recommended playlist not found."));
  }
  private String clean(String value) { return value == null ? "" : value.trim(); }
}
