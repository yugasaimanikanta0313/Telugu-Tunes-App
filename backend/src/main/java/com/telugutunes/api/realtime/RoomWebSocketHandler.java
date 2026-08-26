package com.telugutunes.api.realtime;

import com.telugutunes.api.api.dto.RoomResponse;
import com.telugutunes.api.service.AuthService;
import com.telugutunes.api.service.RoomService;
import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/** Authenticated, low-latency playback events for active listening rooms. */
@Component
public class RoomWebSocketHandler extends TextWebSocketHandler {
  private final AuthService auth;
  private final RoomService rooms;
  private final ObjectMapper json;
  private final Map<String, Client> clients = new ConcurrentHashMap<>();
  private final Map<String, Set<String>> roomSessions = new ConcurrentHashMap<>();

  public RoomWebSocketHandler(AuthService auth, RoomService rooms, ObjectMapper json) {
    this.auth = auth;
    this.rooms = rooms;
    this.json = json;
  }

  @Override
  protected void handleTextMessage(WebSocketSession session, TextMessage message) {
    try {
      var payload = json.readTree(message.getPayload());
      switch (text(payload, "type")) {
        case "authenticate" -> authenticate(session, payload);
        case "playback" -> playback(session, payload);
        case "ping" -> send(session, Map.of("type", "pong", "serverTimeMs", System.currentTimeMillis()));
        default -> error(session, "Unsupported realtime message.");
      }
    } catch (Exception exception) {
      error(session, exception.getMessage() == null ? "Invalid realtime message." : exception.getMessage());
    }
  }

  private void authenticate(WebSocketSession session, JsonNode payload) {
    var token = text(payload, "token");
    var roomId = text(payload, "roomId");
    var member = auth.memberForToken(token);
    var access = rooms.realtimeAccess(member.id(), roomId);
    remove(session.getId());
    clients.put(session.getId(), new Client(roomId, member.id(), access.host(), session));
    roomSessions.computeIfAbsent(roomId, ignored -> ConcurrentHashMap.newKeySet()).add(session.getId());
    send(session, Map.of(
        "type", "authenticated",
        "roomId", roomId,
        "serverTimeMs", System.currentTimeMillis()));
  }

  private void playback(WebSocketSession session, JsonNode payload) {
    var client = clients.get(session.getId());
    if (client == null) throw new IllegalArgumentException("Authenticate the realtime connection first.");
    if (!client.host()) throw new IllegalArgumentException("Only the room host controls playback.");
    var roomId = text(payload, "roomId");
    if (!client.roomId().equals(roomId)) throw new IllegalArgumentException("Realtime room mismatch.");
    var trackId = text(payload, "trackId");
    var positionMs = Math.max(0L, payload.path("positionMs").asLong());
    var playing = payload.path("playing").asBoolean(false);
    broadcast(roomId, Map.of(
        "type", "playback",
        "roomId", roomId,
        "trackId", trackId,
        "positionMs", positionMs,
        "playing", playing,
        "serverTimeMs", System.currentTimeMillis()));
  }

  public void broadcastRoomChanged(String roomId) {
    broadcast(roomId, Map.of(
        "type", "room_changed",
        "roomId", roomId,
        "serverTimeMs", System.currentTimeMillis()));
  }

  public void broadcastPlayback(RoomResponse room) {
    if (room.track() == null) return;
    broadcast(room.id(), Map.of(
        "type", "playback",
        "roomId", room.id(),
        "trackId", room.track().id(),
        "positionMs", room.positionMs(),
        "playing", room.playing(),
        "serverTimeMs", System.currentTimeMillis()));
  }

  private void broadcast(String roomId, Map<String, Object> payload) {
    var sessionIds = roomSessions.get(roomId);
    if (sessionIds == null) return;
    for (var sessionId : Set.copyOf(sessionIds)) {
      var client = clients.get(sessionId);
      if (client == null) continue;
      var session = client.session();
      if (session == null || !session.isOpen()) {
        remove(sessionId);
        continue;
      }
      send(session, payload);
    }
  }

  private void send(WebSocketSession session, Map<String, Object> payload) {
    if (!session.isOpen()) return;
    try {
      synchronized (session) {
        session.sendMessage(new TextMessage(json.writeValueAsString(payload)));
      }
    } catch (IOException exception) {
      remove(session.getId());
    }
  }

  private void error(WebSocketSession session, String message) {
    send(session, Map.of("type", "error", "message", message));
  }

  private String text(JsonNode payload, String field) {
    var value = payload.path(field).asText("").trim();
    if (value.isBlank()) throw new IllegalArgumentException(field + " is required.");
    return value;
  }

  @Override
  public void afterConnectionEstablished(WebSocketSession session) {
    clients.put(session.getId(), new Client(null, null, false, session));
  }

  @Override
  public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
    remove(session.getId());
  }

  @Override
  public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception {
    remove(session.getId());
    if (session.isOpen()) session.close(CloseStatus.SERVER_ERROR);
  }

  private void remove(String sessionId) {
    var client = clients.remove(sessionId);
    if (client == null || client.roomId() == null) return;
    var sessions = roomSessions.get(client.roomId());
    if (sessions == null) return;
    sessions.remove(sessionId);
    if (sessions.isEmpty()) roomSessions.remove(client.roomId(), sessions);
  }

  private record Client(String roomId, String memberId, boolean host, WebSocketSession session) {}
}
