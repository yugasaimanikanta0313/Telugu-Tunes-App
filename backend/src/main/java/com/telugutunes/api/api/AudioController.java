package com.telugutunes.api.api;

import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.service.CatalogService;
import com.telugutunes.api.service.AudioPlaybackTicketService;
import com.telugutunes.api.service.ResilientStorageService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/audio")
public class AudioController {
  private final CatalogService catalog;
  private final ResilientStorageService storage;
  private final AudioPlaybackTicketService tickets;

  public AudioController(
      CatalogService catalog,
      ResilientStorageService storage,
      AudioPlaybackTicketService tickets) {
    this.catalog = catalog;
    this.storage = storage;
    this.tickets = tickets;
  }

  @GetMapping("/{trackId}/ticket")
  public AudioPlaybackTicketService.IssuedTicket ticket(@PathVariable String trackId) {
    var track = catalog.trackDocument(trackId);
    if (track.driveFileId() == null || track.driveFileId().isBlank()) {
      throw new NotFoundException("This track has no uploaded audio.");
    }
    return tickets.issue(trackId);
  }

  @GetMapping("/{trackId}")
  public void stream(
      @PathVariable String trackId,
      @RequestParam(required = false) String ticket,
      HttpServletRequest request,
      HttpServletResponse response)
      throws IOException {
    var authenticated =
        request.getAttribute(com.telugutunes.api.config.AuthenticationFilter.MEMBER_ID_ATTRIBUTE)
            != null;
    if (!authenticated && !tickets.isValid(ticket, trackId)) {
      response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "A valid playback ticket is required.");
      return;
    }
    var track = catalog.trackDocument(trackId);
    if (track.driveFileId() == null || track.driveFileId().isBlank()) {
      throw new NotFoundException("This track has no uploaded audio.");
    }
    if (!storage.isConfigured()) {
      throw new IllegalStateException("Private audio streaming is not configured.");
    }
    var media = storage.mediaInfo(track.driveFileId());
    if (media.size() <= 0) {
      throw new NotFoundException("This track has no readable audio data.");
    }
    var range = range(request.getHeader(HttpHeaders.RANGE), media.size());
    if (range == null) {
      response.setStatus(HttpServletResponse.SC_REQUESTED_RANGE_NOT_SATISFIABLE);
      response.setHeader(HttpHeaders.CONTENT_RANGE, "bytes */" + media.size());
      return;
    }
    response.setStatus(range.partial() ? HttpServletResponse.SC_PARTIAL_CONTENT : HttpServletResponse.SC_OK);
    response.setContentType(playbackMimeType(track.mimeType(), media.mimeType()));
    response.setHeader(HttpHeaders.CONTENT_DISPOSITION, "inline");
    response.setHeader(HttpHeaders.ACCEPT_RANGES, "bytes");
    // Audio may be replaced while keeping the same library entry. Do not let a browser reuse an
    // older response for that entry after the replacement is complete.
    // The Flutter client includes a media-version query derived from the stored object ID.
    // Replaced audio receives a new version while unchanged audio can use a bounded private cache.
    response.setHeader(HttpHeaders.CACHE_CONTROL, "private, max-age=3600, must-revalidate");
    response.setHeader(HttpHeaders.CONTENT_LENGTH, Long.toString(range.length()));
    if (range.partial()) {
      response.setHeader(
          HttpHeaders.CONTENT_RANGE,
          "bytes " + range.start() + "-" + range.end() + "/" + media.size());
    }
    storage.stream(track.driveFileId(), range.start(), range.end(), response.getOutputStream());
  }

  private String playbackMimeType(String trackMimeType, String storageMimeType) {
    var candidate = trackMimeType == null || trackMimeType.isBlank() ? storageMimeType : trackMimeType;
    if (candidate == null
        || candidate.isBlank()
        || "application/octet-stream".equalsIgnoreCase(candidate)
        || !candidate.toLowerCase(java.util.Locale.ROOT).startsWith("audio/")) {
      return "audio/mpeg";
    }
    return candidate;
  }

  private ByteRange range(String header, long size) {
    if (header == null || header.isBlank()) return new ByteRange(0, size - 1, false);
    if (!header.startsWith("bytes=")) return null;
    try {
      var specification = header.substring("bytes=".length()).split(",", 2)[0].trim();
      var parts = specification.split("-", 2);
      if (parts.length != 2) return null;
      long start;
      long end;
      if (parts[0].isBlank()) {
        var suffixLength = Long.parseLong(parts[1]);
        if (suffixLength <= 0) return null;
        start = Math.max(0, size - suffixLength);
        end = size - 1;
      } else {
        start = Long.parseLong(parts[0]);
        end = parts[1].isBlank() ? size - 1 : Math.min(size - 1, Long.parseLong(parts[1]));
      }
      return start < 0 || start >= size || end < start ? null : new ByteRange(start, end, true);
    } catch (NumberFormatException exception) {
      return null;
    }
  }

  private record ByteRange(long start, long end, boolean partial) {
    long length() {
      return end - start + 1;
    }
  }
}
