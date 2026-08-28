package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.TrackResponse;
import com.telugutunes.api.domain.FavoriteDocument;
import com.telugutunes.api.repository.FavoriteRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class FavoriteService {
  private final FavoriteRepository favorites;
  private final CatalogService catalog;

  public FavoriteService(FavoriteRepository favorites, CatalogService catalog) {
    this.favorites = favorites;
    this.catalog = catalog;
  }

  public List<TrackResponse> list(String memberId) {
    var ids = favorites.findAllByMemberId(memberId).stream()
        .map(FavoriteDocument::trackId).toList();
    return catalog.tracksByIds(ids);
  }

  public List<TrackResponse> add(String memberId, String trackId) {
    catalog.trackDocument(trackId);
    var id = id(memberId, trackId);
    if (!favorites.existsById(id)) {
      favorites.save(new FavoriteDocument(id, memberId, trackId, Instant.now()));
    }
    return list(memberId);
  }

  public List<TrackResponse> remove(String memberId, String trackId) {
    favorites.deleteById(id(memberId, trackId));
    return list(memberId);
  }

  private String id(String memberId, String trackId) {
    return memberId + ":" + trackId;
  }
}
