package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.CreatePlaylistRequest;
import com.telugutunes.api.api.dto.PlaylistResponse;
import com.telugutunes.api.service.PlaylistService;
import com.telugutunes.api.config.AuthenticationFilter;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/playlists")
public class PlaylistsController {
  private final PlaylistService playlists;

  public PlaylistsController(PlaylistService playlists) {
    this.playlists = playlists;
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
}
