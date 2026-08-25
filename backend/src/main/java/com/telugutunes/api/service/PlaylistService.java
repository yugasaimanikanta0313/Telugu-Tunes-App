package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.CreatePlaylistRequest;
import com.telugutunes.api.api.dto.PlaylistResponse;
import com.telugutunes.api.domain.PlaylistDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.PlaylistRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class PlaylistService {
  private final PlaylistRepository playlists;
  private final CatalogService catalog;

  public PlaylistService(PlaylistRepository playlists, CatalogService catalog) {
    this.playlists = playlists;
    this.catalog = catalog;
  }

  public List<PlaylistResponse> list(String memberId) {
    return playlists.findByOwnerMemberIdOrSharedWithMemberIdsContains(memberId, memberId).stream()
        .map(this::response)
        .toList();
  }

  public PlaylistResponse create(String memberId, CreatePlaylistRequest request) {
    var now = Instant.now();
    var playlist =
        playlists.save(
            new PlaylistDocument(
                null,
                memberId,
                request.name().trim(),
                request.description() == null ? "" : request.description().trim(),
                request.color() == null || request.color().isBlank() ? "7C4DFF" : request.color(),
                List.of(),
                List.of(),
                now,
                now));
    return response(playlist);
  }

  public PlaylistResponse addTrack(String memberId, String playlistId, String trackId) {
    var playlist =
        playlists.findById(playlistId).orElseThrow(() -> new NotFoundException("Playlist not found."));
    if (!playlist.ownerMemberId().equals(memberId)
        && !playlist.sharedWithMemberIds().contains(memberId)) {
      throw new IllegalArgumentException("This member cannot change the playlist.");
    }
    catalog.trackDocument(trackId);
    var ids = new ArrayList<>(playlist.trackIds());
    if (!ids.contains(trackId)) {
      ids.add(trackId);
    }
    return response(
        playlists.save(
            new PlaylistDocument(
                playlist.id(),
                playlist.ownerMemberId(),
                playlist.name(),
                playlist.description(),
                playlist.artworkColor(),
                ids,
                playlist.sharedWithMemberIds(),
                playlist.createdAt(),
                Instant.now())));
  }

  private PlaylistResponse response(PlaylistDocument playlist) {
    return new PlaylistResponse(
        playlist.id(),
        playlist.name(),
        playlist.description(),
        playlist.artworkColor(),
        catalog.tracksByIds(playlist.trackIds()),
        playlist.sharedWithMemberIds());
  }
}
