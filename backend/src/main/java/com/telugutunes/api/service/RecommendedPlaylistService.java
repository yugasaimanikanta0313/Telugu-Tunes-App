package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.RecommendedPlaylistRequest;
import com.telugutunes.api.api.dto.RecommendedPlaylistResponse;
import com.telugutunes.api.domain.RecommendedPlaylistDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.RecommendedPlaylistRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class RecommendedPlaylistService {
  private final RecommendedPlaylistRepository repository;
  private final CatalogService catalog;
  private final AuthService auth;

  public RecommendedPlaylistService(RecommendedPlaylistRepository repository, CatalogService catalog, AuthService auth) {
    this.repository = repository;
    this.catalog = catalog;
    this.auth = auth;
  }

  public List<RecommendedPlaylistResponse> publicList() {
    return repository.findByActiveTrueOrderByUpdatedAtDesc().stream().map(this::response).toList();
  }

  public List<RecommendedPlaylistResponse> adminList(String memberId) {
    auth.requireAdministrator(memberId);
    return repository.findAll().stream().map(this::response).toList();
  }

  public RecommendedPlaylistResponse save(String memberId, String id, RecommendedPlaylistRequest request) {
    auth.requireAdministrator(memberId);
    var existing = id == null ? null : repository.findById(id)
        .orElseThrow(() -> new NotFoundException("Recommended playlist not found."));
    var trackIds = request.trackIds() == null ? List.<String>of() : request.trackIds().stream().distinct().toList();
    trackIds.forEach(catalog::trackDocument);
    var now = Instant.now();
    var saved = repository.save(new RecommendedPlaylistDocument(
        existing == null ? null : existing.id(), request.name().trim(), clean(request.description()),
        request.type().trim(), request.subtype().trim(), defaultValue(request.color(), "7C4DFF"),
        clean(request.artworkUrl()), trackIds, request.active() == null || request.active(),
        existing == null ? now : existing.createdAt(), now));
    return response(saved);
  }

  public void delete(String memberId, String id) {
    auth.requireAdministrator(memberId);
    repository.deleteById(id);
  }

  private RecommendedPlaylistResponse response(RecommendedPlaylistDocument value) {
    var tracks = catalog.tracksByIds(value.trackIds() == null ? List.of() : value.trackIds());
    var artwork = clean(value.artworkUrl());
    if (artwork.isBlank()) artwork = tracks.stream().map(t -> t.artworkUrl()).filter(v -> v != null && !v.isBlank()).findFirst().orElse("");
    return new RecommendedPlaylistResponse(value.id(), value.name(), clean(value.description()), value.type(), value.subtype(),
        defaultValue(value.artworkColor(), "7C4DFF"), artwork, tracks, value.active());
  }

  private String clean(String value) { return value == null ? "" : value.trim(); }
  private String defaultValue(String value, String fallback) { return value == null || value.isBlank() ? fallback : value.trim(); }
}
