package com.telugutunes.api.service;

import com.telugutunes.api.domain.AlbumDocument;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.io.IOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

/** Removes historical exact metadata duplicates and keeps the oldest uploaded copy. */
@Service
public class DuplicateTrackCleanupService {
  private static final Logger log = LoggerFactory.getLogger(DuplicateTrackCleanupService.class);

  private final TrackRepository tracks;
  private final AlbumRepository albums;
  private final LyricsRepository lyrics;
  private final ResilientStorageService storage;

  public DuplicateTrackCleanupService(
      TrackRepository tracks,
      AlbumRepository albums,
      LyricsRepository lyrics,
      ResilientStorageService storage) {
    this.tracks = tracks;
    this.albums = albums;
    this.lyrics = lyrics;
    this.storage = storage;
  }

  @EventListener(ApplicationReadyEvent.class)
  public void removeHistoricalDuplicates() {
    var ordered = new ArrayList<>(tracks.findAll());
    ordered.sort(
        Comparator.comparing(
                TrackDocument::createdAt,
                Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(TrackDocument::id, Comparator.nullsLast(String::compareTo)));

    Map<String, TrackDocument> kept = new LinkedHashMap<>();
    var duplicateIds = new ArrayList<String>();
    for (var track : ordered) {
      var existing = kept.putIfAbsent(key(track), track);
      if (existing != null && track.id() != null) {
        duplicateIds.add(track.id());
        deleteAudioBestEffort(track);
        lyrics.deleteById(track.id());
        tracks.deleteById(track.id());
      }
    }
    if (duplicateIds.isEmpty()) return;

    for (var album : albums.findAll()) {
      var cleanIds = album.trackIds().stream().filter(id -> !duplicateIds.contains(id)).toList();
      if (cleanIds.size() == album.trackIds().size()) continue;
      albums.save(
          new AlbumDocument(
              album.id(),
              album.title(),
              album.artist(),
              album.description(),
              album.year(),
              album.artworkColor(),
              album.artworkUrl(),
              album.movie(),
              cleanIds,
              album.createdAt()));
    }
    log.info("Removed {} duplicate track records; oldest copies were preserved.", duplicateIds.size());
  }

  private void deleteAudioBestEffort(TrackDocument track) {
    if (!storage.isConfigured() || track.driveFileId() == null || track.driveFileId().isBlank()) return;
    try {
      storage.delete(track.driveFileId());
    } catch (IOException failure) {
      log.warn("Duplicate track {} was removed, but its storage object could not be deleted.", track.id());
    }
  }

  private String key(TrackDocument track) {
    return normalize(track.title()) + "|" + normalize(track.singers()) + "|" + normalize(track.album());
  }

  private String normalize(String value) {
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }
}
