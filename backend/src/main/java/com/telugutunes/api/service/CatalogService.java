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
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
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
    ensureImportedAlbum();
    var allTracks = new ArrayList<>(tracks.findAll());
    allTracks.sort(Comparator.comparing(
        TrackDocument::createdAt,
        Comparator.nullsLast(Comparator.reverseOrder())));
    var latest = allTracks.stream().limit(12).map(TrackResponse::from).toList();
    var charts = allTracks.stream().limit(20).map(TrackResponse::from).toList();
    var collections = new ArrayList<CollectionResponse>();
    collections.add(new CollectionResponse(
        "charts", "Telugu Tunes charts", "Popular picks from your private catalog", "E15184", "playlist", charts));
    collections.add(new CollectionResponse(
        "latest", "Recently added", "New music from your circle", "7C4DFF", "mix", latest));
    addMood(collections, "mood-chill", "Chill Telugu", "Soft songs for a quiet mood", "4F86C6",
        allTracks, List.of("chill", "melody", "slow", "acoustic", "calm", "lofi"));
    addMood(collections, "mood-love", "Romantic mood", "Telugu love songs selected automatically", "E15184",
        allTracks, List.of("love", "romantic", "prema", "melody"));
    addMood(collections, "mood-energy", "High energy", "Fast songs for drives and workouts", "F59E0B",
        allTracks, List.of("dance", "mass", "rock", "party", "energetic", "folk"));
    if (!allTracks.isEmpty()) {
      var automatic = new ArrayList<>(allTracks);
      Collections.rotate(automatic, LocalDate.now().getDayOfYear() % automatic.size());
      collections.add(new CollectionResponse(
          "automatic-daily", "Your automatic daily mix", "A fresh rotation from your library", "00A896", "mix",
          automatic.stream().limit(15).map(TrackResponse::from).toList()));
    }
    return new HomeResponse(collections, albums.findAll().stream().map(this::albumResponse).toList(), latest);
  }

  private void ensureImportedAlbum() {
    if (albums.existsById("imported-music")) return;
    var now = Instant.now();
    albums.save(
        new AlbumDocument(
            "imported-music",
            "Imported music",
            "Your private collection",
            "Songs uploaded from your device.",
            now.atZone(java.time.ZoneOffset.UTC).getYear(),
            "7C4DFF",
            "",
            false,
            List.of(),
            now));
  }

  private void addMood(
      List<CollectionResponse> collections,
      String id,
      String title,
      String subtitle,
      String color,
      List<TrackDocument> allTracks,
      List<String> keywords) {
    var selected = allTracks.stream()
        .filter(track -> {
          var searchable = String.join(" ",
              cleanOrDefault(track.genre(), ""), cleanOrDefault(track.title(), ""),
              cleanOrDefault(track.album(), "")).toLowerCase(java.util.Locale.ROOT);
          return keywords.stream().anyMatch(searchable::contains);
        })
        .limit(15)
        .map(TrackResponse::from)
        .toList();
    if (!selected.isEmpty()) {
      collections.add(new CollectionResponse(id, title, subtitle, color, "mix", selected));
    }
  }

  public List<TrackResponse> search(String query) {
    var clean = query == null ? "" : query.trim();
    var mode = "all";
    var separator = clean.indexOf(':');
    if (separator > 0) {
      var requestedMode = clean.substring(0, separator).toLowerCase(java.util.Locale.ROOT);
      if (List.of("title", "album", "artist", "lyrics").contains(requestedMode)) {
        mode = requestedMode;
        clean = clean.substring(separator + 1).trim();
      }
    }
    if (clean.isBlank()) {
      return tracks.findAll().stream().limit(40).map(TrackResponse::from).toList();
    }
    var terms = java.util.Arrays.stream(normalizeSearchText(clean).split("\\s+"))
        .filter(term -> term.length() >= 2)
        .toList();
    if (terms.isEmpty()) {
      return List.of();
    }
    final var searchMode = mode;
    final var searchQuery = clean;
    final var lyricsByTrack = lyrics.findAll().stream()
        .collect(Collectors.toMap(value -> value.trackId(), Function.identity(), (left, right) -> left));
    return tracks.findAll().stream()
        .filter(track -> {
          var haystack = switch (searchMode) {
            case "title" -> normalizeSearchText(track.title());
            case "album" -> normalizeSearchText(track.album());
            case "artist" -> normalizeSearchText(String.join(" ",
                cleanOrDefault(track.artist(), ""), cleanOrDefault(track.singers(), ""),
                cleanOrDefault(track.musicDirector(), "")));
            case "lyrics" -> searchableLyrics(lyricsByTrack.get(track.id()));
            default -> searchableMetadata(track) + " " + searchableLyrics(lyricsByTrack.get(track.id()));
          };
          return terms.stream().anyMatch(haystack::contains);
        })
        .sorted(Comparator
            .comparingInt((TrackDocument track) -> searchRank(track, searchQuery, terms))
            .thenComparing(TrackDocument::title, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)))
        .limit(40)
        .map(TrackResponse::from)
        .toList();
  }

  private String searchableLyrics(com.telugutunes.api.domain.LyricsDocument value) {
    if (value == null) return "";
    var original = String.join(" ", cleanOrDefault(value.plainLyrics(), ""),
        cleanOrDefault(value.syncedLyrics(), ""));
    var english = String.join(" ", cleanOrDefault(value.englishPlainLyrics(), ""),
        cleanOrDefault(value.englishSyncedLyrics(), ""));
    return normalizeSearchText(original + " " + english + " " + romanizeTelugu(original));
  }

  private static String romanizeTelugu(String value) {
    if (value == null || value.isBlank()) return "";
    var consonants = Map.ofEntries(
        Map.entry('క', "k"), Map.entry('ఖ', "kh"), Map.entry('గ', "g"), Map.entry('ఘ', "gh"),
        Map.entry('చ', "ch"), Map.entry('ఛ', "chh"), Map.entry('జ', "j"), Map.entry('ఝ', "jh"),
        Map.entry('ట', "t"), Map.entry('ఠ', "th"), Map.entry('డ', "d"), Map.entry('ఢ', "dh"),
        Map.entry('త', "t"), Map.entry('థ', "th"), Map.entry('ద', "d"), Map.entry('ధ', "dh"),
        Map.entry('న', "n"), Map.entry('ప', "p"), Map.entry('ఫ', "ph"), Map.entry('బ', "b"),
        Map.entry('భ', "bh"), Map.entry('మ', "m"), Map.entry('య', "y"), Map.entry('ర', "r"),
        Map.entry('ల', "l"), Map.entry('వ', "v"), Map.entry('శ', "sh"), Map.entry('ష', "sh"),
        Map.entry('స', "s"), Map.entry('హ', "h"), Map.entry('ళ', "l"), Map.entry('ఱ', "r"));
    var signs = Map.ofEntries(
        Map.entry('ా', "aa"), Map.entry('ి', "i"), Map.entry('ీ', "ee"), Map.entry('ు', "u"),
        Map.entry('ూ', "oo"), Map.entry('ృ', "ru"), Map.entry('ె', "e"), Map.entry('ే', "e"),
        Map.entry('ై', "ai"), Map.entry('ొ', "o"), Map.entry('ో', "o"), Map.entry('ౌ', "au"));
    var independent = Map.ofEntries(
        Map.entry('అ', "a"), Map.entry('ఆ', "aa"), Map.entry('ఇ', "i"), Map.entry('ఈ', "ee"),
        Map.entry('ఉ', "u"), Map.entry('ఊ', "oo"), Map.entry('ఎ', "e"), Map.entry('ఏ', "e"),
        Map.entry('ఐ', "ai"), Map.entry('ఒ', "o"), Map.entry('ఓ', "o"), Map.entry('ఔ', "au"));
    var result = new StringBuilder();
    for (var index = 0; index < value.length(); index++) {
      var current = value.charAt(index);
      var consonant = consonants.get(current);
      if (consonant != null) {
        result.append(consonant);
        if (index + 1 < value.length() && signs.containsKey(value.charAt(index + 1))) {
          result.append(signs.get(value.charAt(++index)));
        } else if (index + 1 < value.length() && value.charAt(index + 1) == '్') {
          index++;
        } else {
          result.append('a');
        }
      } else if (independent.containsKey(current)) {
        result.append(independent.get(current));
      } else if (current == 'ం') {
        result.append('m');
      } else {
        result.append(current);
      }
    }
    return result.toString();
  }

  private String searchableMetadata(TrackDocument track) {
    return String.join(" ",
        cleanOrDefault(track.title(), ""),
        cleanOrDefault(track.artist(), ""),
        cleanOrDefault(track.album(), ""),
        cleanOrDefault(track.singers(), ""),
        cleanOrDefault(track.musicDirector(), ""),
        cleanOrDefault(track.genre(), ""),
        cleanOrDefault(track.duration(), ""),
        cleanOrDefault(track.mimeType(), ""))
        .transform(CatalogService::normalizeSearchText);
  }

  private int searchRank(TrackDocument track, String query, List<String> terms) {
    var needle = normalizeSearchText(query);
    var title = normalizeSearchText(cleanOrDefault(track.title(), ""));
    if (title.equals(needle)) return 0;
    if (title.startsWith(needle)) return 1;
    if (title.contains(needle)) return 2;
    if (terms.stream().anyMatch(title::startsWith)) return 3;
    if (terms.stream().anyMatch(title::contains)) return 4;

    var metadata = searchableMetadata(track);
    var matches = (int) terms.stream().filter(metadata::contains).count();
    return 100 - matches;
  }

  private static String normalizeSearchText(String value) {
    if (value == null) return "";
    return value.toLowerCase(java.util.Locale.ROOT)
        .replaceAll("[^\\p{L}\\p{N}]+", " ")
        .trim();
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
              album.artworkColor(), album.artworkUrl(), album.movie(), ids, album.createdAt()));
    }
    for (var playlist : playlists.findAll()) {
      if (!playlist.trackIds().contains(trackId)) continue;
      var ids = new ArrayList<>(playlist.trackIds());
      ids.remove(trackId);
      playlists.save(
          new com.telugutunes.api.domain.PlaylistDocument(
              playlist.id(), playlist.ownerMemberId(), playlist.name(), playlist.description(),
              playlist.artworkColor(), playlist.artworkUrl(), ids, playlist.sharedWithMemberIds(),
              playlist.createdAt(), Instant.now()));
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
                request.artworkUrl() == null
                    ? existing.artworkUrl()
                    : cleanUrl(request.artworkUrl()),
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
      var album = albums.findById(albumId)
          .orElseThrow(() -> new NotFoundException("Album not found."));
      var now = Instant.now();
      for (var track : tracks.findAllById(album.trackIds())) {
        tracks.save(new TrackDocument(track.id(), track.title(), track.artist(), "Unsorted music",
            "unsorted-music", track.duration(), track.durationSeconds(), track.artworkColor(),
            track.singers(), track.musicDirector(), track.genre(), track.artworkUrl(), track.sourceUrl(),
            track.driveFileId(), track.mimeType(), track.uploadedByMemberId(), track.createdAt()));
      }
      albums.save(new AlbumDocument("unsorted-music", "Unsorted music", "Your private collection",
          "Songs retained after an album grouping was removed.",
          now.atZone(java.time.ZoneOffset.UTC).getYear(), "7C4DFF", "", false,
          album.trackIds(), album.createdAt()));
      return;
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
                    "",
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
            unsorted.artworkUrl(),
            unsorted.movie(),
            List.copyOf(unsortedTrackIds),
            unsorted.createdAt()));
    albums.deleteById(albumId);
  }

  private AlbumResponse albumResponse(AlbumDocument album) {
    var albumTracks = tracksByIds(album.trackIds());
    var artworkUrl = cleanOrEmpty(album.artworkUrl());
    if (artworkUrl.isBlank()) {
      artworkUrl = albumTracks.stream()
          .map(TrackResponse::artworkUrl)
          .filter(value -> value != null && !value.isBlank())
          .findFirst()
          .orElse("");
    }
    return new AlbumResponse(
        album.id(),
        album.title(),
        album.artist(),
        album.description(),
        album.year(),
        album.artworkColor(),
        artworkUrl,
        album.movie(),
        albumTracks);
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
                  album.artworkUrl(),
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
                    "",
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
            album.artworkUrl(),
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
