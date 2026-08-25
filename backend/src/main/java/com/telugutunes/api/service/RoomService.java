package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.CreateRoomRequest;
import com.telugutunes.api.api.dto.RoomResponse;
import com.telugutunes.api.api.dto.UpdateRoomPlaybackRequest;
import com.telugutunes.api.domain.ListeningRoomDocument;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.ListeningRoomRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class RoomService {
  private final ListeningRoomRepository rooms;
  private final CatalogService catalog;

  public RoomService(ListeningRoomRepository rooms, CatalogService catalog) {
    this.rooms = rooms;
    this.catalog = catalog;
  }

  public List<RoomResponse> listForMember(String memberId) {
    return rooms.findByMemberIdsContainsAndActiveTrue(memberId).stream().map(this::response).toList();
  }

  /** Public rooms are visible to every signed-in Telugu Tunes member. */
  public List<RoomResponse> listPublic() {
    return rooms.findByPublicRoomTrueAndActiveTrue().stream().map(this::response).toList();
  }

  public RoomResponse byInvite(String inviteCode) {
    return response(
        rooms.findByInviteCode(inviteCode).orElseThrow(() -> new NotFoundException("Room not found.")));
  }

  public RoomResponse create(String memberId, CreateRoomRequest request) {
    requireNoActiveRoom(memberId);
    var trackId = cleanTrack(request.currentTrackId());
    if (trackId != null) catalog.trackDocument(trackId);
    var now = Instant.now();
    var room = rooms.save(new ListeningRoomDocument(
        null, request.name().trim(), memberId, request.publicRoom() ? "" : createInviteCode(),
        request.publicRoom(), List.of(memberId), trackId, trackId == null ? List.of() : List.of(trackId),
        0L, false, now, true, now, now));
    return response(room);
  }

  public RoomResponse join(String memberId, String inviteCode) {
    var room = rooms.findByInviteCode(inviteCode.trim().toUpperCase())
        .orElseThrow(() -> new NotFoundException("Room not found. Check the invite code."));
    if (!room.active()) throw new IllegalStateException("This room is no longer active.");
    if (isPublic(room)) {
      throw new IllegalArgumentException("This is a public room. Join it from the public rooms list.");
    }
    if (room.memberIds().contains(memberId)) return response(room);
    requireNoActiveRoom(memberId);
    var members = new ArrayList<>(room.memberIds());
    members.add(memberId);
    return response(rooms.save(withMembers(room, members, Instant.now())));
  }

  /** Joins a discoverable public room without an invite code. */
  public RoomResponse joinPublic(String memberId, String roomId) {
    var room = rooms.findById(roomId).orElseThrow(() -> new NotFoundException("Room not found."));
    if (!room.active() || !isPublic(room)) {
      throw new NotFoundException("That public room is no longer available.");
    }
    if (room.memberIds().contains(memberId)) return response(room);
    requireNoActiveRoom(memberId);
    var members = new ArrayList<>(room.memberIds());
    members.add(memberId);
    return response(rooms.save(withMembers(room, members, Instant.now())));
  }

  /** A host closes their room for all listeners; a guest simply leaves it. */
  public void leave(String memberId, String roomId) {
    var room = rooms.findById(roomId).orElseThrow(() -> new NotFoundException("Room not found."));
    if (!room.memberIds().contains(memberId)) {
      throw new IllegalArgumentException("You are not a member of this room.");
    }
    var now = Instant.now();
    if (room.hostMemberId().equals(memberId)) {
      rooms.save(copy(room, room.memberIds(), room.currentTrackId(), room.queueTrackIds(),
          storedPosition(room), isPlaying(room), playbackTimestamp(room, now), false, now));
      return;
    }
    var members = new ArrayList<>(room.memberIds());
    members.remove(memberId);
    rooms.save(withMembers(room, members, now));
  }

  public RoomResponse addToQueue(String memberId, String roomId, String trackId) {
    var room = rooms.findById(roomId).orElseThrow(() -> new NotFoundException("Room not found."));
    if (!room.memberIds().contains(memberId)) {
      throw new IllegalArgumentException("Join this room before adding songs.");
    }
    catalog.trackDocument(trackId);
    var queue = new ArrayList<>(room.queueTrackIds());
    if (!queue.contains(trackId)) queue.add(trackId);
    var becomesCurrent = room.currentTrackId() == null;
    var current = becomesCurrent ? trackId : room.currentTrackId();
    var now = Instant.now();
    return response(rooms.save(copy(room, room.memberIds(), current, queue,
        becomesCurrent ? 0L : storedPosition(room), becomesCurrent ? false : isPlaying(room),
        becomesCurrent ? now : playbackTimestamp(room, now), room.active(), now)));
  }

  /**
   * Removes the finished current track and starts the oldest remaining queued track. Only the
   * host may advance it, which keeps all listeners on the same first-in, first-out order.
   */
  public RoomResponse advanceQueue(String memberId, String roomId, String finishedTrackId) {
    var room = hostRoom(memberId, roomId);
    if (!finishedTrackId.equals(room.currentTrackId())) return response(room);
    var queue = new ArrayList<>(room.queueTrackIds());
    queue.remove(finishedTrackId);
    var nextTrackId = queue.isEmpty() ? null : queue.getFirst();
    var now = Instant.now();
    return response(rooms.save(copy(room, room.memberIds(), nextTrackId, queue, 0L, false, now,
        room.active(), now)));
  }

  /** The host publishes the track that joined listeners should follow. */
  public RoomResponse setCurrentTrack(String memberId, String roomId, String trackId) {
    var room = hostRoom(memberId, roomId);
    catalog.trackDocument(trackId);
    var queue = new ArrayList<>(room.queueTrackIds());
    if (!queue.contains(trackId)) queue.add(trackId);
    var now = Instant.now();
    return response(rooms.save(copy(room, room.memberIds(), trackId, queue, 0L, false, now,
        room.active(), now)));
  }

  /** Stores the host player clock. The response calculates the clock through server time. */
  public RoomResponse updatePlayback(
      String memberId, String roomId, UpdateRoomPlaybackRequest request) {
    var room = hostRoom(memberId, roomId);
    catalog.trackDocument(request.trackId());
    var queue = new ArrayList<>(room.queueTrackIds());
    if (!queue.contains(request.trackId())) queue.add(request.trackId());
    var now = Instant.now();
    return response(rooms.save(copy(room, room.memberIds(), request.trackId(), queue,
        request.positionMs(), request.playing(), now, room.active(), now)));
  }

  public String createInviteCode() {
    return "TUNE-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
  }

  private ListeningRoomDocument hostRoom(String memberId, String roomId) {
    var room = rooms.findById(roomId).orElseThrow(() -> new NotFoundException("Room not found."));
    if (!room.active()) throw new IllegalStateException("This room is no longer active.");
    if (!room.hostMemberId().equals(memberId)) {
      throw new IllegalArgumentException("Only the room host controls shared playback.");
    }
    return room;
  }

  private void requireNoActiveRoom(String memberId) {
    if (!rooms.findByMemberIdsContainsAndActiveTrue(memberId).isEmpty()) {
      throw new IllegalStateException("Leave your current room before creating or joining another room.");
    }
  }

  private String cleanTrack(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private boolean isPublic(ListeningRoomDocument room) {
    return Boolean.TRUE.equals(room.publicRoom());
  }

  private long storedPosition(ListeningRoomDocument room) {
    return room.playbackPositionMs() == null ? 0L : Math.max(0L, room.playbackPositionMs());
  }

  private boolean isPlaying(ListeningRoomDocument room) {
    return Boolean.TRUE.equals(room.playbackPlaying());
  }

  private Instant playbackTimestamp(ListeningRoomDocument room, Instant fallback) {
    return room.playbackUpdatedAt() == null ? fallback : room.playbackUpdatedAt();
  }

  private long effectivePosition(ListeningRoomDocument room) {
    var position = storedPosition(room);
    if (!isPlaying(room) || room.playbackUpdatedAt() == null) return position;
    return position + Math.max(0L, Duration.between(room.playbackUpdatedAt(), Instant.now()).toMillis());
  }

  private ListeningRoomDocument withMembers(
      ListeningRoomDocument room, List<String> members, Instant updatedAt) {
    return copy(room, members, room.currentTrackId(), room.queueTrackIds(), storedPosition(room),
        isPlaying(room), playbackTimestamp(room, updatedAt), room.active(), updatedAt);
  }

  private ListeningRoomDocument copy(
      ListeningRoomDocument room, List<String> members, String currentTrackId, List<String> queueTrackIds,
      long playbackPositionMs, boolean playbackPlaying, Instant playbackUpdatedAt,
      boolean active, Instant updatedAt) {
    return new ListeningRoomDocument(
        room.id(), room.name(), room.hostMemberId(), room.inviteCode(), isPublic(room), members,
        currentTrackId, queueTrackIds, playbackPositionMs, playbackPlaying, playbackUpdatedAt,
        active, room.createdAt(), updatedAt);
  }

  private RoomResponse response(ListeningRoomDocument room) {
    var current = room.currentTrackId() == null || room.currentTrackId().isBlank()
        ? null
        : catalog.tracksByIds(List.of(room.currentTrackId())).stream().findFirst().orElse(null);
    return new RoomResponse(
        room.id(), room.name(), room.hostMemberId(), room.inviteCode(), isPublic(room),
        room.memberIds().size(), current, catalog.tracksByIds(room.queueTrackIds()),
        effectivePosition(room), isPlaying(room), room.active());
  }
}
