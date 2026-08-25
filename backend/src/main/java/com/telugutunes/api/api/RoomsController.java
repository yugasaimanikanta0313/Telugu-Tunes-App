package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.RoomResponse;
import com.telugutunes.api.api.dto.CreateRoomRequest;
import com.telugutunes.api.api.dto.JoinRoomRequest;
import com.telugutunes.api.api.dto.UpdateRoomPlaybackRequest;
import com.telugutunes.api.service.RoomService;
import com.telugutunes.api.config.AuthenticationFilter;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/rooms")
public class RoomsController {
  private final RoomService rooms;

  public RoomsController(RoomService rooms) {
    this.rooms = rooms;
  }

  @GetMapping
  public List<RoomResponse> mine(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId) {
    return rooms.listForMember(memberId);
  }

  @GetMapping("/public")
  public List<RoomResponse> publicRooms() {
    return rooms.listPublic();
  }

  @GetMapping("/join/{inviteCode}")
  public RoomResponse join(@PathVariable String inviteCode) {
    return rooms.byInvite(inviteCode);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public RoomResponse create(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody CreateRoomRequest request) {
    return rooms.create(memberId, request);
  }

  @PostMapping("/join")
  public RoomResponse join(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody JoinRoomRequest request) {
    return rooms.join(memberId, request.inviteCode());
  }

  @PostMapping("/public/{roomId}/join")
  public RoomResponse joinPublic(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId) {
    return rooms.joinPublic(memberId, roomId);
  }

  @PostMapping("/{roomId}/leave")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void leave(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId) {
    rooms.leave(memberId, roomId);
  }

  @PostMapping("/{roomId}/track/{trackId}")
  public RoomResponse setCurrentTrack(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    return rooms.setCurrentTrack(memberId, roomId, trackId);
  }

  /** Receives the room host's player clock. Only the host can publish it. */
  @PutMapping("/{roomId}/playback")
  public RoomResponse updatePlayback(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @Valid @RequestBody UpdateRoomPlaybackRequest request) {
    return rooms.updatePlayback(memberId, roomId, request);
  }

  @PostMapping("/{roomId}/queue/{trackId}")
  public RoomResponse addToQueue(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    return rooms.addToQueue(memberId, roomId, trackId);
  }

  /** Advances the shared first-in, first-out queue after the host finishes a track. */
  @PostMapping("/{roomId}/queue/advance/{trackId}")
  public RoomResponse advanceQueue(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    return rooms.advanceQueue(memberId, roomId, trackId);
  }
}
