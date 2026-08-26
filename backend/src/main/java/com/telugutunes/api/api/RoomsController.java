package com.telugutunes.api.api;

import com.telugutunes.api.api.dto.RoomResponse;
import com.telugutunes.api.api.dto.CreateRoomRequest;
import com.telugutunes.api.api.dto.JoinRoomRequest;
import com.telugutunes.api.api.dto.UpdateRoomPlaybackRequest;
import com.telugutunes.api.service.RoomService;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.realtime.RoomWebSocketHandler;
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
  private final RoomWebSocketHandler realtime;

  public RoomsController(RoomService rooms, RoomWebSocketHandler realtime) {
    this.rooms = rooms;
    this.realtime = realtime;
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
    var room = rooms.create(memberId, request);
    realtime.broadcastRoomChanged(room.id());
    return room;
  }

  @PostMapping("/join")
  public RoomResponse join(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @Valid @RequestBody JoinRoomRequest request) {
    var room = rooms.join(memberId, request.inviteCode());
    realtime.broadcastRoomChanged(room.id());
    return room;
  }

  @PostMapping("/public/{roomId}/join")
  public RoomResponse joinPublic(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId) {
    var room = rooms.joinPublic(memberId, roomId);
    realtime.broadcastRoomChanged(room.id());
    return room;
  }

  @PostMapping("/{roomId}/leave")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void leave(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId) {
    rooms.leave(memberId, roomId);
    realtime.broadcastRoomChanged(roomId);
  }

  @PostMapping("/{roomId}/track/{trackId}")
  public RoomResponse setCurrentTrack(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    var room = rooms.setCurrentTrack(memberId, roomId, trackId);
    realtime.broadcastRoomChanged(room.id());
    return room;
  }

  /** Receives the room host's player clock. Only the host can publish it. */
  @PutMapping("/{roomId}/playback")
  public RoomResponse updatePlayback(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @Valid @RequestBody UpdateRoomPlaybackRequest request) {
    var room = rooms.updatePlayback(memberId, roomId, request);
    realtime.broadcastPlayback(room);
    return room;
  }

  @PostMapping("/{roomId}/queue/{trackId}")
  public RoomResponse addToQueue(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    var room = rooms.addToQueue(memberId, roomId, trackId);
    realtime.broadcastRoomChanged(room.id());
    return room;
  }

  /** Advances the shared first-in, first-out queue after the host finishes a track. */
  @PostMapping("/{roomId}/queue/advance/{trackId}")
  public RoomResponse advanceQueue(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String roomId,
      @PathVariable String trackId) {
    var room = rooms.advanceQueue(memberId, roomId, trackId);
    realtime.broadcastRoomChanged(room.id());
    return room;
  }
}
