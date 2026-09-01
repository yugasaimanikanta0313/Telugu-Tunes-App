package com.telugutunes.api.service;

import com.telugutunes.api.domain.AlbumDocument;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.io.IOException;
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
  public void repairCatalog() {
    removeHistoricalDuplicates();
    repairImportedAlbum();
  }

  void removeHistoricalDuplicates() {
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

  private void repairImportedAlbum() {
    var imported = albums.findById("imported-music").orElse(null);
    if (imported == null) return;
    var importedIds = new ArrayList<String>();
    for (var trackId : imported.trackIds()) {
      var track = tracks.findById(trackId).orElse(null);
      if (track == null) continue;
      if ("Imported music".equalsIgnoreCase(track.album())) {
        importedIds.add(trackId);
        continue;
      }
      var targetId = albumId(track.album());
      if ("imported-music".equals(targetId)) {
        importedIds.add(trackId);
        continue;
      }
      var moved =
          tracks.save(
              new TrackDocument(
                  track.id(),
                  track.title(),
                  track.artist(),
                  track.album(),
                  targetId,
                  track.duration(),
                  track.durationSeconds(),
                  track.artworkColor(),
                  track.singers(),
                  track.musicDirector(),
                  track.genre(),
                  track.artworkUrl(),
                  track.sourceUrl(),
                  track.driveFileId(),
                  track.mimeType(),
                  track.uploadedByMemberId(),
                  track.createdAt()));
      var target =
          albums
              .findById(targetId)
              .orElse(
                  new AlbumDocument(
                      targetId,
                      moved.album(),
                      moved.musicDirector() == null || moved.musicDirector().isBlank()
                          ? "Your private collection"
                          : moved.musicDirector(),
                      "Tracks uploaded by your members.",
                      moved.createdAt() == null
                          ? java.time.Year.now().getValue()
                          : moved.createdAt().atZone(java.time.ZoneOffset.UTC).getYear(),
                      moved.artworkColor(),
                      moved.artworkUrl(),
                      false,
                      java.util.List.of(),
                      moved.createdAt()));
      var targetIds = new ArrayList<>(target.trackIds());
      if (!targetIds.contains(trackId)) targetIds.add(trackId);
      albums.save(
          new AlbumDocument(
              target.id(),
              target.title(),
              target.artist(),
              target.description(),
              target.year(),
              target.artworkColor(),
              target.artworkUrl(),
              target.movie(),
              targetIds,
              target.createdAt()));
    }
    albums.save(
        new AlbumDocument(
            "imported-music",
            "Imported music",
            "Your private collection",
            "Songs uploaded from your device.",
            java.time.Year.now().getValue(),
            "7C4DFF",
            "",
            false,
            importedIds,
            imported.createdAt()));
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

  private String albumId(String album) {
    var value = normalize(album).replaceAll("[^a-z0-9]+", "-").replaceAll("(^-+)|(-+$)", "");
    return value.isBlank() ? "imported-music" : value;
  }
}
