package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.AlbumResponse;
import com.telugutunes.api.api.dto.CollectionResponse;
import com.telugutunes.api.api.dto.HomeResponse;
import com.telugutunes.api.api.dto.TrackResponse;
import com.telugutunes.api.api.dto.TrackAudioReplacementResponse;
import com.telugutunes.api.api.dto.UpdateAlbumRequest;
import com.telugutunes.api.api.dto.UpdateTrackRequest;
import com.telugutunes.api.domain.AlbumDocument;
import com.telugutunes.api.domain.TrackDocument;
import com.telugutunes.api.domain.MemberRole;
import com.telugutunes.api.exception.NotFoundException;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.ListeningRoomRepository;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.repository.PlaylistRepository;
import com.telugutunes.api.repository.MemberRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.io.IOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CatalogService {
  private final TrackRepository tracks;
  private final AlbumRepository albums;
  private final PlaylistRepository playlists;
  private final ListeningRoomRepository rooms;
  private final LyricsRepository lyrics;
  private final MemberRepository members;
  private final AuthService auth;
  private final ResilientStorageService storage;

  public CatalogService(
      TrackRepository tracks,
      AlbumRepository albums,
      PlaylistRepository playlists,
      ListeningRoomRepository rooms,
      LyricsRepository lyrics,
      MemberRepository members,
      AuthService auth,
      ResilientStorageService storage) {
    this.tracks = tracks;
    this.albums = albums;
    this.playlists = playlists;
    this.rooms = rooms;
    this.lyrics = lyrics;
    this.members = members;
    this.auth = auth;
    this.storage = storage;
  }

  public HomeResponse home() {
    var allTracks = tracks.findAll();
    var latest = allTracks.stream().limit(12).map(TrackResponse::from).toList();
    var collections =
        List.of(
            new CollectionResponse(
                "latest", "Recently added", "New music from your circle", "7C4DFF", "mix", latest),
            new CollectionResponse(
                "offline", "Ready for offline", "Download what you want to keep", "00A896", "mix", latest));
    return new HomeResponse(collections, albums.findAll().stream().map(this::albumResponse).toList(), latest);
  }

  public List<TrackResponse> search(String query) {
    var clean = query == null ? "" : query.trim();
    if (clean.isBlank()) {
      return tracks.findAll().stream().limit(40).map(TrackResponse::from).toList();
    }
    return tracks
        .findTop40ByTitleContainingIgnoreCaseOrArtistContainingIgnoreCaseOrAlbumContainingIgnoreCase(
            clean, clean, clean)
        .stream()
        .map(TrackResponse::from)
        .toList();
  }

  public AlbumResponse album(String id) {
    var album = albums.findById(id).orElseThrow(() -> new NotFoundException("Album not found."));
    return albumResponse(album);
  }

  public TrackDocument trackDocument(String id) {
    return tracks.findById(id).orElseThrow(() -> new NotFoundException("Track not found."));
  }

  public List<TrackResponse> tracksByIds(Collection<String> ids) {
    if (ids == null || ids.isEmpty()) {
      return List.of();
    }
    Map<String, TrackDocument> ordered =
        tracks.findAllById(ids).stream()
            .collect(Collectors.toMap(TrackDocument::id, Function.identity()));
    return ids.stream()
        .map(ordered::get)
        .filter(java.util.Objects::nonNull)
        .map(TrackResponse::from)
        .toList();
  }

  /** Removes the audio object plus every library reference owned by this private service. */
  public void deleteTrack(String memberId, String trackId) throws IOException {
    var track = trackDocument(trackId);
    auth.requireAdministrator(memberId);
    if (storage.isConfigured() && track.driveFileId() != null && !track.driveFileId().isBlank()) {
      storage.delete(track.driveFileId());
    }
    tracks.deleteById(trackId);
    lyrics.deleteById(trackId);
    for (var album : albums.findAll()) {
      if (!album.trackIds().contains(trackId)) continue;
      var ids = new ArrayList<>(album.trackIds());
      ids.remove(trackId);
      albums.save(
          new AlbumDocument(
              album.id(), album.title(), album.artist(), album.description(), album.year(),
              album.artworkColor(), album.movie(), ids, album.createdAt()));
    }
    for (var playlist : playlists.findAll()) {
      if (!playlist.trackIds().contains(trackId)) continue;
      var ids = new ArrayList<>(playlist.trackIds());
      ids.remove(trackId);
      playlists.save(
          new com.telugutunes.api.domain.PlaylistDocument(
              playlist.id(), playlist.ownerMemberId(), playlist.name(), playlist.description(),
              playlist.artworkColor(), ids, playlist.sharedWithMemberIds(), playlist.createdAt(), Instant.now()));
    }
    for (var room : rooms.findAll()) {
      var queue = new ArrayList<>(room.queueTrackIds());
      var changed = queue.remove(trackId);
      var currentTrack = room.currentTrackId();
      if (trackId.equals(currentTrack)) {
        currentTrack = queue.isEmpty() ? null : queue.getFirst();
        changed = true;
      }
      if (changed) {
        var resetPlayback = !java.util.Objects.equals(currentTrack, room.currentTrackId());
        var now = Instant.now();
        rooms.save(
            new com.telugutunes.api.domain.ListeningRoomDocument(
                room.id(), room.name(), room.hostMemberId(), room.inviteCode(), Boolean.TRUE.equals(room.publicRoom()), room.memberIds(),
                currentTrack, queue,
                resetPlayback ? 0L : (room.playbackPositionMs() == null ? 0L : room.playbackPositionMs()),
                resetPlayback ? false : Boolean.TRUE.equals(room.playbackPlaying()),
                resetPlayback || room.playbackUpdatedAt() == null ? now : room.playbackUpdatedAt(),
                room.active(), room.createdAt(), now));
      }
    }
  }

  public TrackResponse updateTrack(String memberId, String trackId, UpdateTrackRequest request) {
    auth.requireAdministrator(memberId);
    var existing = trackDocument(trackId);
    var albumTitle = cleanOrDefault(request.album(), existing.album());
    var albumId = albumId(albumTitle);
    var updated =
        tracks.save(
            new TrackDocument(
                existing.id(),
                cleanOrDefault(request.title(), existing.title()),
                cleanOrDefault(request.artist(), existing.artist()),
                albumTitle,
                albumId,
                existing.duration(),
                existing.durationSeconds(),
                cleanColor(request.color(), existing.artworkColor()),
                cleanOrEmpty(request.singers()),
                cleanOrEmpty(request.musicDirector()),
                cleanOrEmpty(request.genre()),
                cleanUrl(request.artworkUrl()),
                cleanUrl(request.sourceUrl()),
                existing.driveFileId(),
                existing.mimeType(),
                existing.uploadedByMemberId(),
                existing.createdAt()));
    if (!existing.albumId().equals(albumId)) {
      removeTrackFromAlbum(existing.albumId(), existing.id());
      addTrackToAlbum(updated);
    }
    return TrackResponse.from(updated);
  }

  /** Replaces the stored audio without changing the track's title, album, or other metadata. */
  public TrackAudioReplacementResponse replaceTrackAudio(
      String memberId, String trackId, MultipartFile file)
      throws IOException {
    auth.requireAdministrator(memberId);
    if (file == null || file.isEmpty()) {
      throw new IllegalArgumentException("Choose a non-empty audio file.");
    }
    if (file.getSize() > 50L * 1024 * 1024) {
      throw new IllegalArgumentException("The current upload limit is 50 MB.");
    }
    if (!storage.isConfigured()) {
      throw new IllegalStateException("Private audio storage is not configured.");
    }

    var existing = trackDocument(trackId);
    var replacement = storage.upload(file);
    var updated =
        tracks.save(
            new TrackDocument(
                existing.id(),
                existing.title(),
                existing.artist(),
                existing.album(),
                existing.albumId(),
                existing.duration(),
                existing.durationSeconds(),
                existing.artworkColor(),
                existing.singers(),
                existing.musicDirector(),
                existing.genre(),
                existing.artworkUrl(),
                existing.sourceUrl(),
                replacement.objectId(),
                replacement.mimeType(),
                existing.uploadedByMemberId(),
                existing.createdAt()));
    if (existing.driveFileId() != null
        && !existing.driveFileId().isBlank()
        && !existing.driveFileId().equals(replacement.objectId())) {
      try {
        storage.delete(existing.driveFileId());
      } catch (IOException ignored) {
        // The new file is safely linked. A later Drive cleanup can remove an orphan if needed.
      }
    }
    return new TrackAudioReplacementResponse(
        TrackResponse.from(updated),
        replacement.originalBytes(),
        replacement.storedBytes(),
        replacement.compressed());
  }

  public AlbumResponse updateAlbum(String memberId, String albumId, UpdateAlbumRequest request) {
    auth.requireAdministrator(memberId);
    var existing = albums.findById(albumId).orElseThrow(() -> new NotFoundException("Album not found."));
    var updated =
        albums.save(
            new AlbumDocument(
                existing.id(),
                cleanOrDefault(request.title(), existing.title()),
                cleanOrDefault(request.artist(), existing.artist()),
                cleanOrDefault(request.description(), existing.description()),
                request.year() == 0 ? existing.year() : request.year(),
                cleanColor(request.color(), existing.artworkColor()),
                request.movie(),
                existing.trackIds(),
                existing.createdAt()));
    for (var track : tracks.findAllById(existing.trackIds())) {
      tracks.save(
          new TrackDocument(
              track.id(),
              track.title(),
              track.artist(),
              updated.title(),
              track.albumId(),
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
    }
    return albumResponse(updated);
  }

  /** Removes only the album grouping; uploaded audio stays in an Unsorted music album. */
  public void removeAlbum(String memberId, String albumId) {
    auth.requireAdministrator(memberId);
    if ("unsorted-music".equals(albumId)) {
      throw new IllegalArgumentException("The Unsorted music album cannot be removed.");
    }
    var album = albums.findById(albumId).orElseThrow(() -> new NotFoundException("Album not found."));
    var now = Instant.now();
    var unsorted =
        albums
            .findById("unsorted-music")
            .orElse(
                new AlbumDocument(
                    "unsorted-music",
                    "Unsorted music",
                    "Your private collection",
                    "Songs retained after an album grouping was removed.",
                    now.atZone(java.time.ZoneOffset.UTC).getYear(),
                    "7C4DFF",
                    false,
                    List.of(),
                    now));
    var unsortedTrackIds = new LinkedHashSet<>(unsorted.trackIds());
    for (var track : tracks.findAllById(album.trackIds())) {
      tracks.save(
          new TrackDocument(
              track.id(),
              track.title(),
              track.artist(),
              "Unsorted music",
              "unsorted-music",
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
      unsortedTrackIds.add(track.id());
    }
    albums.save(
        new AlbumDocument(
            unsorted.id(),
            unsorted.title(),
            unsorted.artist(),
            unsorted.description(),
            unsorted.year(),
            unsorted.artworkColor(),
            unsorted.movie(),
            List.copyOf(unsortedTrackIds),
            unsorted.createdAt()));
    albums.deleteById(albumId);
  }

  private AlbumResponse albumResponse(AlbumDocument album) {
    return new AlbumResponse(
        album.id(),
        album.title(),
        album.artist(),
        album.description(),
        album.year(),
        album.artworkColor(),
        album.movie(),
        tracksByIds(album.trackIds()));
  }

  private void removeTrackFromAlbum(String albumId, String trackId) {
    albums.findById(albumId).ifPresent(
        album -> {
          var ids = new ArrayList<>(album.trackIds());
          ids.remove(trackId);
          albums.save(
              new AlbumDocument(
                  album.id(),
                  album.title(),
                  album.artist(),
                  album.description(),
                  album.year(),
                  album.artworkColor(),
                  album.movie(),
                  ids,
                  album.createdAt()));
        });
  }

  private void addTrackToAlbum(TrackDocument track) {
    var now = Instant.now();
    var album =
        albums
            .findById(track.albumId())
            .orElse(
                new AlbumDocument(
                    track.albumId(),
                    track.album(),
                    track.artist(),
                    "Tracks uploaded by your members.",
                    now.atZone(java.time.ZoneOffset.UTC).getYear(),
                    track.artworkColor(),
                    false,
                    List.of(),
                    now));
    var ids = new LinkedHashSet<>(album.trackIds());
    ids.add(track.id());
    albums.save(
        new AlbumDocument(
            album.id(),
            album.title(),
            album.artist(),
            album.description(),
            album.year(),
            album.artworkColor(),
            album.movie(),
            List.copyOf(ids),
            album.createdAt()));
  }

  private String albumId(String album) {
    var value = album.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-+)|(-+$)", "");
    return value.isBlank() ? "imported-music" : value;
  }

  private String cleanOrDefault(String value, String fallback) {
    return value == null || value.isBlank() ? fallback : value.trim();
  }

  private String cleanOrEmpty(String value) {
    return value == null ? "" : value.trim();
  }

  private String cleanColor(String value, String fallback) {
    return value != null && value.matches("(?i)[0-9a-f]{6}") ? value.toUpperCase() : fallback;
  }

  private String cleanUrl(String value) {
    var candidate = cleanOrEmpty(value);
    return candidate.startsWith("https://") || candidate.startsWith("http://") ? candidate : "";
  }
}
