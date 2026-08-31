package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.CreatePlaylistRequest;
import com.telugutunes.api.api.dto.PlaylistResponse;
import com.telugutunes.api.domain.PlaylistDocument;
import com.telugutunes.api.domain.PlaylistTrackContributionDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.PlaylistRepository;
import com.telugutunes.api.repository.PlaylistInvitationRepository;
import com.telugutunes.api.repository.PlaylistTrackContributionRepository;
import com.telugutunes.api.repository.MemberRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlaylistService {
  private final PlaylistRepository playlists;
  private final CatalogService catalog;
  private final PlaylistInvitationRepository invitations;
  private final PlaylistTrackContributionRepository contributions;
  private final MemberRepository members;

  public PlaylistService(
      PlaylistRepository playlists,
      CatalogService catalog,
      PlaylistInvitationRepository invitations,
      PlaylistTrackContributionRepository contributions,
      MemberRepository members) {
    this.playlists = playlists;
    this.catalog = catalog;
    this.invitations = invitations;
    this.contributions = contributions;
    this.members = members;
  }

  public List<PlaylistResponse> list(String memberId) {
    var accessible = new LinkedHashMap<String, PlaylistDocument>();
    playlists.findByOwnerMemberIdOrSharedWithMemberIdsContains(memberId, memberId)
        .forEach(value -> accessible.put(value.id(), value));
    invitations.findByInviteeMemberIdAndStatusOrderByCreatedAtDesc(memberId, "ACCEPTED")
        .forEach(invitation -> playlists.findById(invitation.playlistId())
            .ifPresent(value -> accessible.put(value.id(), value)));
    return accessible.values().stream().map(value -> response(value, memberId)).toList();
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
                request.artworkUrl() == null ? "" : request.artworkUrl().trim(),
                List.of(),
                List.of(),
                now,
                now));
    return response(playlist, memberId);
  }

  public PlaylistResponse addTrack(String memberId, String playlistId, String trackId) {
    var playlist =
        playlists.findById(playlistId).orElseThrow(() -> new NotFoundException("Playlist not found."));
    if (!hasWriteAccess(playlist, memberId)) {
      throw new IllegalArgumentException("This member cannot change the playlist.");
    }
    catalog.trackDocument(trackId);
    var ids = new ArrayList<>(playlist.trackIds());
    if (!ids.contains(trackId)) {
      ids.add(trackId);
    }
    var saved = playlists.save(
        new PlaylistDocument(
            playlist.id(),
            playlist.ownerMemberId(),
            playlist.name(),
            playlist.description(),
            playlist.artworkColor(),
            playlist.artworkUrl(),
            ids,
            playlist.sharedWithMemberIds(),
            playlist.createdAt(),
            Instant.now()));
    if (!playlist.trackIds().contains(trackId)
        && contributions.findByPlaylistIdAndTrackId(playlistId, trackId).isEmpty()) {
      contributions.save(new PlaylistTrackContributionDocument(
          null, playlistId, trackId, memberId, Instant.now()));
    }
    return response(saved, memberId);
  }

  public PlaylistResponse update(
      String memberId, String playlistId, CreatePlaylistRequest request) {
    var playlist = playlists.findById(playlistId)
        .orElseThrow(() -> new NotFoundException("Playlist not found."));
    if (!playlist.ownerMemberId().equals(memberId)) {
      throw new IllegalArgumentException("Only the playlist owner can edit its cover and details.");
    }
    return response(playlists.save(new PlaylistDocument(
        playlist.id(),
        playlist.ownerMemberId(),
        request.name().trim(),
        request.description() == null ? "" : request.description().trim(),
        request.color() == null || request.color().isBlank()
            ? playlist.artworkColor()
            : request.color().trim(),
        request.artworkUrl() == null ? playlist.artworkUrl() : request.artworkUrl().trim(),
        playlist.trackIds(),
        playlist.sharedWithMemberIds(),
        playlist.createdAt(),
        Instant.now())), memberId);
  }

  @Transactional
  public void delete(String memberId, String playlistId) {
    var playlist = playlists.findById(playlistId)
        .orElseThrow(() -> new NotFoundException("Playlist not found."));
    if (!playlist.ownerMemberId().equals(memberId)) {
      throw new IllegalArgumentException("Only the playlist owner can delete it.");
    }
    contributions.deleteByPlaylistId(playlistId);
    invitations.deleteByPlaylistId(playlistId);
    playlists.delete(playlist);
  }

  private PlaylistResponse response(PlaylistDocument playlist, String memberId) {
    var tracks = catalog.tracksByIds(playlist.trackIds());
    var artworkUrl = playlist.artworkUrl() == null ? "" : playlist.artworkUrl().trim();
    if (artworkUrl.isBlank()) {
      artworkUrl = tracks.stream()
          .map(com.telugutunes.api.api.dto.TrackResponse::artworkUrl)
          .filter(value -> value != null && !value.isBlank())
          .findFirst()
          .orElse("");
    }
    return new PlaylistResponse(
        playlist.id(),
        playlist.name(),
        playlist.description(),
        playlist.artworkColor(),
        artworkUrl,
        tracks,
        playlist.sharedWithMemberIds(),
        playlist.ownerMemberId(),
        playlist.ownerMemberId().equals(memberId),
        contributionNames(playlist));
  }

  private boolean hasWriteAccess(PlaylistDocument playlist, String memberId) {
    if (playlist.ownerMemberId().equals(memberId)
        || playlist.sharedWithMemberIds().contains(memberId)) return true;
    return invitations.findByPlaylistIdAndInviteeMemberIdAndStatus(
        playlist.id(), memberId, "ACCEPTED").isPresent();
  }

  private Map<String, String> contributionNames(PlaylistDocument playlist) {
    var memberByTrack = new LinkedHashMap<String, String>();
    playlist.trackIds().forEach(trackId -> memberByTrack.put(trackId, playlist.ownerMemberId()));
    contributions.findByPlaylistId(playlist.id())
        .forEach(value -> memberByTrack.put(value.trackId(), value.memberId()));

    var memberIds = new LinkedHashSet<>(memberByTrack.values());
    var names = new LinkedHashMap<String, String>();
    members.findAllById(memberIds).forEach(member -> names.put(member.id(), member.displayName()));

    var result = new LinkedHashMap<String, String>();
    memberByTrack.forEach((trackId, memberId) ->
        result.put(trackId, names.getOrDefault(memberId, "Playlist member")));
    return result;
  }
}
