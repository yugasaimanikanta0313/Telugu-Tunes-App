package com.telugutunes.api.service;

import com.telugutunes.api.api.dto.BackupSnapshot;
import com.telugutunes.api.repository.AlbumRepository;
import com.telugutunes.api.repository.LyricsRepository;
import com.telugutunes.api.repository.PlaylistRepository;
import com.telugutunes.api.repository.TrackRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class BackupService {
  private final TrackRepository tracks;
  private final AlbumRepository albums;
  private final PlaylistRepository playlists;
  private final LyricsRepository lyrics;
  private final AuthService auth;

  public BackupService(
      TrackRepository tracks,
      AlbumRepository albums,
      PlaylistRepository playlists,
      LyricsRepository lyrics,
      AuthService auth) {
    this.tracks = tracks;
    this.albums = albums;
    this.playlists = playlists;
    this.lyrics = lyrics;
    this.auth = auth;
  }

  public BackupSnapshot exportSnapshot(String administratorId) {
    auth.requireAdministrator(administratorId);
    return new BackupSnapshot(
        1, Instant.now(), tracks.findAll(), albums.findAll(), playlists.findAll(), lyrics.findAll());
  }

  /** Merge restore is intentionally non-destructive: records absent from a backup remain untouched. */
  public BackupSnapshot restore(String administratorId, BackupSnapshot snapshot) {
    auth.requireAdministrator(administratorId);
    if (snapshot == null || snapshot.schemaVersion() != 1) {
      throw new IllegalArgumentException("Unsupported or missing backup schema.");
    }
    tracks.saveAll(snapshot.tracks() == null ? List.of() : snapshot.tracks());
    albums.saveAll(snapshot.albums() == null ? List.of() : snapshot.albums());
    playlists.saveAll(snapshot.playlists() == null ? List.of() : snapshot.playlists());
    lyrics.saveAll(snapshot.lyrics() == null ? List.of() : snapshot.lyrics());
    return exportSnapshot(administratorId);
  }
}
