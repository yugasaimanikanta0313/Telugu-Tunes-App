package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.CreatePlaylistRequest;
import com.telugutunes.api.api.dto.PlaylistResponse;
import com.telugutunes.api.service.PlaylistService;
import com.telugutunes.api.service.PlaylistInvitationService;
import com.telugutunes.api.api.dto.CreatePlaylistInvitationRequest;
import com.telugutunes.api.api.dto.PlaylistInvitationResponse;
import com.telugutunes.api.config.AuthenticationFilter;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/playlists")
public class PlaylistsController {
  private final PlaylistService playlists;
  private final PlaylistInvitationService invitations;

  public PlaylistsController(PlaylistService playlists, PlaylistInvitationService invitations) {
    this.playlists = playlists;
    this.invitations = invitations;
  }

  @GetMapping
  public List<PlaylistResponse> list(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return playlists.list(memberId);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public PlaylistResponse create(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody CreatePlaylistRequest request) {
    return playlists.create(memberId, request);
  }

  @PostMapping("/{playlistId}/tracks/{trackId}")
  public PlaylistResponse addTrack(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String playlistId,
      @PathVariable String trackId) {
    return playlists.addTrack(memberId, playlistId, trackId);
  }

  @PutMapping("/{playlistId}")
  public PlaylistResponse update(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String playlistId,
      @Valid @RequestBody CreatePlaylistRequest request) {
    return playlists.update(memberId, playlistId, request);
  }

  @PostMapping("/{playlistId}/invitations")
  @ResponseStatus(HttpStatus.CREATED)
  public PlaylistInvitationResponse invite(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String playlistId,
      @Valid @RequestBody CreatePlaylistInvitationRequest request) {
    return invitations.invite(memberId, playlistId, request.email());
  }

  @GetMapping("/invitations")
  public List<PlaylistInvitationResponse> invitations(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return invitations.pending(memberId);
  }

  @PostMapping("/invitations/{invitationId}/accept")
  public PlaylistInvitationResponse accept(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String invitationId) {
    return invitations.respond(memberId, invitationId, true);
  }

  @PostMapping("/invitations/{invitationId}/reject")
  public PlaylistInvitationResponse reject(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String invitationId) {
    return invitations.respond(memberId, invitationId, false);
  }
}
