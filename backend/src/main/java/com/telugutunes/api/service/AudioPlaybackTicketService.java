package com.telugutunes.api.service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/** Issues short-lived, track-specific credentials for browser media elements. */
@Service
public class AudioPlaybackTicketService {
  private static final Duration LIFETIME = Duration.ofMinutes(10);
  private final SecureRandom random = new SecureRandom();
  private final ConcurrentHashMap<String, Ticket> tickets = new ConcurrentHashMap<>();

  public IssuedTicket issue(String trackId) {
    removeExpired();
    var bytes = new byte[24];
    random.nextBytes(bytes);
    var value = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    var expiresAt = Instant.now().plus(LIFETIME);
    tickets.put(value, new Ticket(trackId, expiresAt));
    return new IssuedTicket(value, expiresAt);
  }

  public boolean isValid(String value, String trackId) {
    if (value == null || value.isBlank()) return false;
    var ticket = tickets.get(value);
    if (ticket == null || ticket.expiresAt().isBefore(Instant.now())) {
      tickets.remove(value);
      return false;
    }
    return ticket.trackId().equals(trackId);
  }

  private void removeExpired() {
    var now = Instant.now();
    tickets.entrySet().removeIf(entry -> entry.getValue().expiresAt().isBefore(now));
  }

  private record Ticket(String trackId, Instant expiresAt) {}

  public record IssuedTicket(String ticket, Instant expiresAt) {}
}
