package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.PlaylistInvitationResponse;
import com.telugutunes.api.domain.PlaylistDocument;
import com.telugutunes.api.domain.PlaylistInvitationDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.MemberRepository;
import com.telugutunes.api.repository.PlaylistInvitationRepository;
import com.telugutunes.api.repository.PlaylistRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class PlaylistInvitationService {
  private static final String PENDING = "PENDING";
  private final PlaylistInvitationRepository invitations;
  private final PlaylistRepository playlists;
  private final MemberRepository members;

  public PlaylistInvitationService(
      PlaylistInvitationRepository invitations,
      PlaylistRepository playlists,
      MemberRepository members) {
    this.invitations = invitations;
    this.playlists = playlists;
    this.members = members;
  }

  public PlaylistInvitationResponse invite(String memberId, String playlistId, String email) {
    var playlist = playlist(playlistId);
    if (!playlist.ownerMemberId().equals(memberId)) {
      throw new IllegalArgumentException("Only the playlist owner can invite collaborators.");
    }
    var invitee = members.findByEmailIgnoreCase(email.trim())
        .filter(value -> value.active())
        .orElseThrow(() -> new NotFoundException("No active Telugu Tunes account uses that email."));
    if (invitee.id().equals(memberId)) throw new IllegalArgumentException("You already own this playlist.");
    if (playlist.sharedWithMemberIds().contains(invitee.id())) {
      throw new IllegalStateException("That member already collaborates on this playlist.");
    }
    if (invitations.findByPlaylistIdAndInviteeMemberIdAndStatus(playlistId, invitee.id(), PENDING).isPresent()) {
      throw new IllegalStateException("An invitation is already waiting for that member.");
    }
    return response(invitations.save(new PlaylistInvitationDocument(
        null, playlistId, memberId, invitee.id(), PENDING, Instant.now(), null)));
  }

  public List<PlaylistInvitationResponse> pending(String memberId) {
    return invitations.findByInviteeMemberIdAndStatusOrderByCreatedAtDesc(memberId, PENDING)
        .stream().map(this::response).toList();
  }

  public PlaylistInvitationResponse respond(String memberId, String invitationId, boolean accept) {
    var invitation = invitations.findById(invitationId)
        .orElseThrow(() -> new NotFoundException("Playlist invitation not found."));
    if (!invitation.inviteeMemberId().equals(memberId) || !PENDING.equals(invitation.status())) {
      throw new IllegalArgumentException("This invitation is no longer available.");
    }
    if (accept) {
      var playlist = playlist(invitation.playlistId());
      var shared = new ArrayList<>(playlist.sharedWithMemberIds());
      if (!shared.contains(memberId)) shared.add(memberId);
      playlists.save(new PlaylistDocument(
          playlist.id(), playlist.ownerMemberId(), playlist.name(), playlist.description(),
          playlist.artworkColor(), playlist.artworkUrl(), playlist.trackIds(), List.copyOf(shared),
          playlist.createdAt(), Instant.now()));
    }
    return response(invitations.save(new PlaylistInvitationDocument(
        invitation.id(), invitation.playlistId(), invitation.inviterMemberId(),
        invitation.inviteeMemberId(), accept ? "ACCEPTED" : "REJECTED",
        invitation.createdAt(), Instant.now())));
  }

  private PlaylistDocument playlist(String id) {
    return playlists.findById(id).orElseThrow(() -> new NotFoundException("Playlist not found."));
  }

  private PlaylistInvitationResponse response(PlaylistInvitationDocument invitation) {
    var playlist = playlist(invitation.playlistId());
    var inviter = members.findById(invitation.inviterMemberId())
        .map(value -> value.displayName()).orElse("A Telugu Tunes member");
    return new PlaylistInvitationResponse(invitation.id(), playlist.id(), playlist.name(),
        inviter, invitation.status(), invitation.createdAt());
  }
}
