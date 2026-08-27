package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.ImportReferenceRequest;
import com.telugutunes.api.api.dto.ImportResponse;
import com.telugutunes.api.domain.AlbumDocument;
import com.telugutunes.api.domain.ImportJob;
import com.telugutunes.api.domain.ImportStatus;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.ImportJobRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.io.IOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ImportService {
  private final ImportJobRepository jobs;
  private final ResilientStorageService storage;
  private final TrackRepository tracks;
  private final AlbumRepository albums;

  public ImportService(
      ImportJobRepository jobs,
      ResilientStorageService storage,
      TrackRepository tracks,
      AlbumRepository albums) {
    this.jobs = jobs;
    this.storage = storage;
    this.tracks = tracks;
    this.albums = albums;
  }

  public ImportResponse importAudio(
      String memberId,
      MultipartFile file,
      String title,
      String artist,
      String album,
      String color,
      String singers,
      String musicDirector,
      String genre,
      String artworkUrl,
      String sourceUrl)
      throws IOException {
    if (file.isEmpty()) {
      throw new IllegalArgumentException("Choose a non-empty audio file.");
    }
    if (file.getSize() > 50L * 1024 * 1024) {
      throw new IllegalArgumentException("The current upload limit is 50 MB.");
    }
    if (!storage.isConfigured()) {
      return ImportResponse.from(
          save(
              memberId,
              "device-file",
              file.getOriginalFilename(),
              null,
              ImportStatus.PENDING_CONFIGURATION,
              "Private audio storage is not configured yet. The import request has been saved."));
    }
    var media = storage.upload(file);
    saveImportedTrack(
        memberId,
        media,
        title,
        artist,
        album,
        color,
        singers,
        musicDirector,
        genre,
        artworkUrl,
        sourceUrl);
    var job =
        save(
            memberId,
            "device-file",
            media.fileName(),
            media.objectId(),
            ImportStatus.READY,
            media.compressed()
                ? "Audio compressed to MP3 and uploaded to the private music library."
                : "Audio uploaded to the private music library.");
    return ImportResponse.from(job, media);
  }

  private void saveImportedTrack(
      String memberId,
      MediaStorageService.StoredMedia media,
      String title,
      String artist,
      String album,
      String color,
      String singers,
      String musicDirector,
      String genre,
      String artworkUrl,
      String sourceUrl) {
    var now = Instant.now();
    var cleanAlbum = cleanOrDefault(album, "Imported music");
    var albumId = albumId(cleanAlbum);
    var cleanColor = cleanColor(color);
    var track =
        tracks.save(
            new TrackDocument(
                null,
                cleanOrDefault(title, titleFromFileName(media.fileName())),
                cleanOrDefault(artist, "Unknown artist"),
                cleanAlbum,
                albumId,
                "0:00",
                0,
                cleanColor,
                cleanOrEmpty(singers),
                cleanOrEmpty(musicDirector),
                cleanOrEmpty(genre),
                cleanUrl(artworkUrl),
                cleanUrl(sourceUrl),
                media.objectId(),
                media.mimeType(),
                memberId,
                now));
    var albumRecord =
        albums
            .findById(albumId)
            .orElse(
                new AlbumDocument(
                    albumId,
                    cleanAlbum,
                    "Your private collection",
                    "Tracks uploaded by your members.",
                    now.atZone(java.time.ZoneOffset.UTC).getYear(),
                    cleanColor,
                    "",
                    false,
                    List.of(),
                    now));
    var trackIds = new ArrayList<>(albumRecord.trackIds());
    trackIds.add(track.id());
    albums.save(
        new AlbumDocument(
            albumRecord.id(),
            albumRecord.title(),
            albumRecord.artist(),
            albumRecord.description(),
            albumRecord.year(),
            albumRecord.artworkColor(),
            albumRecord.artworkUrl(),
            albumRecord.movie(),
            trackIds,
            albumRecord.createdAt()));
  }

  private String titleFromFileName(String fileName) {
    var dot = fileName.lastIndexOf('.');
    var base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.replace('_', ' ').trim();
  }

  private String cleanOrDefault(String value, String fallback) {
    return value == null || value.isBlank() ? fallback : value.trim();
  }

  private String cleanOrEmpty(String value) {
    return value == null ? "" : value.trim();
  }

  private String cleanUrl(String value) {
    var candidate = cleanOrEmpty(value);
    return candidate.startsWith("https://") || candidate.startsWith("http://") ? candidate : "";
  }

  private String albumId(String album) {
    var value = album.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-+)|(-+$)", "");
    return value.isBlank() ? "imported-music" : value;
  }

  private String cleanColor(String color) {
    return color != null && color.matches("(?i)[0-9a-f]{6}") ? color.toUpperCase() : "7C4DFF";
  }

  public ImportResponse addReference(String memberId, ImportReferenceRequest request) {
    return ImportResponse.from(
        save(
            memberId,
            request.source().trim().toLowerCase(),
            request.value().trim(),
            null,
            ImportStatus.PENDING_CONFIGURATION,
            "Reference saved. Metadata resolution will run when the importer is configured."));
  }

  private ImportJob save(
      String memberId,
      String source,
      String fileName,
      String driveFileId,
      ImportStatus status,
      String message) {
    var now = Instant.now();
    return jobs.save(
        new ImportJob(
            null, memberId, source, fileName, driveFileId, status, message, now, now));
  }
}
