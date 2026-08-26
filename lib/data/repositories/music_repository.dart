import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/music_models.dart';
import '../services/api_music_service.dart';

/// The client only depends on this contract. A Spring Boot-backed repository
/// can replace [MockMusicRepository] without changing any screen code.
abstract class MusicRepository {
  Future<HomeData> getHome();
  Future<List<Track>> search(String query);
  Future<List<Album>> getAlbums();
  Future<List<Playlist>> getPlaylists();
  Future<ListeningRoom?> getRoom();
  Future<List<ListeningRoom>> getPublicRooms();
  Future<Playlist> createPlaylist(String name);
  Future<Playlist> addTrackToPlaylist(String playlistId, Track track);
  Future<Album> updateAlbum(Album album);
  Future<void> deleteAlbum(String albumId);
  Future<Track> updateTrack(Track track);
  Future<AudioReplacementResult> replaceTrackAudio(
      String trackId, String fileName, Uint8List bytes);
  Future<List<AdminMember>> getAdminMembers();
  Future<AdminMember> updateAdminMember(
    String memberId, {
    bool? active,
    bool? isAdmin,
  });
  Future<Uint8List> exportBackup();
  Future<void> restoreBackup(Uint8List bytes);
  Future<ImportReceipt> importMusic(ImportRequest request);
  Future<ImportReceipt> uploadAudio(
    String fileName,
    Uint8List bytes, {
    required String title,
    required String artist,
    required String album,
    required String color,
    required String singers,
    required String musicDirector,
    required String genre,
    required String artworkUrl,
    required String sourceUrl,
  });
  Future<void> deleteTrack(String trackId);
  Future<TrackMetadataSuggestion> suggestMetadata(String query);
  Future<ListeningRoom> createRoom(String name,
      {String? trackId, bool isPublic = false});
  Future<ListeningRoom> joinRoom(String inviteCode);
  Future<ListeningRoom> joinPublicRoom(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<ListeningRoom> setRoomTrack(String roomId, String trackId);
  Future<ListeningRoom> updateRoomPlayback(
    String roomId,
    String trackId, {
    required int positionMs,
    required bool playing,
  });
  Future<ListeningRoom> addToRoomQueue(String roomId, String trackId);
  Future<ListeningRoom> advanceRoomQueue(String roomId, String finishedTrackId);
  Future<TrackLyrics> getLyrics(String trackId);
  Future<TrackLyrics> refreshLyrics(String trackId);
  Future<TrackLyrics> updateLyrics(
    String trackId, {
    required String language,
    required String plainLyrics,
    required String syncedLyrics,
  });
  Future<String> askAssistant(String prompt);
}

class SpringBootMusicRepository implements MusicRepository {
  SpringBootMusicRepository(this._api);
  final MusicApiService _api;

  @override
  Future<HomeData> getHome() => _api.getHome();
  @override
  Future<List<Track>> search(String query) => _api.search(query);
  @override
  Future<List<Album>> getAlbums() => _api.getAlbums();
  @override
  Future<List<Playlist>> getPlaylists() => _api.getPlaylists();
  @override
  Future<ListeningRoom?> getRoom() => _api.getRoom();
  @override
  Future<List<ListeningRoom>> getPublicRooms() => _api.getPublicRooms();
  @override
  Future<Playlist> createPlaylist(String name) => _api.createPlaylist(name);
  @override
  Future<Playlist> addTrackToPlaylist(String playlistId, Track track) =>
      _api.addTrackToPlaylist(playlistId, track.id);
  @override
  Future<Album> updateAlbum(Album album) => _api.updateAlbum(album);
  @override
  Future<void> deleteAlbum(String albumId) => _api.deleteAlbum(albumId);
  @override
  Future<Track> updateTrack(Track track) => _api.updateTrack(track);
  @override
  Future<AudioReplacementResult> replaceTrackAudio(
          String trackId, String fileName, Uint8List bytes) =>
      _api.replaceTrackAudio(trackId, fileName, bytes);
  @override
  Future<List<AdminMember>> getAdminMembers() => _api.getAdminMembers();
  @override
  Future<AdminMember> updateAdminMember(
    String memberId, {
    bool? active,
    bool? isAdmin,
  }) =>
      _api.updateAdminMember(memberId, active: active, isAdmin: isAdmin);
  @override
  Future<Uint8List> exportBackup() => _api.exportBackup();
  @override
  Future<void> restoreBackup(Uint8List bytes) => _api.restoreBackup(bytes);
  @override
  Future<ImportReceipt> importMusic(ImportRequest request) =>
      _api.importMusic(request);
  @override
  Future<ImportReceipt> uploadAudio(String fileName, Uint8List bytes,
          {required String title,
          required String artist,
          required String album,
          required String color,
          required String singers,
          required String musicDirector,
          required String genre,
          required String artworkUrl,
          required String sourceUrl}) =>
      _api.uploadAudio(fileName, bytes,
          title: title,
          artist: artist,
          album: album,
          color: color,
          singers: singers,
          musicDirector: musicDirector,
          genre: genre,
          artworkUrl: artworkUrl,
          sourceUrl: sourceUrl);
  @override
  Future<void> deleteTrack(String trackId) => _api.deleteTrack(trackId);
  @override
  Future<TrackMetadataSuggestion> suggestMetadata(String query) =>
      _api.suggestMetadata(query);
  @override
  Future<ListeningRoom> createRoom(String name,
          {String? trackId, bool isPublic = false}) =>
      _api.createRoom(name, trackId: trackId, isPublic: isPublic);
  @override
  Future<ListeningRoom> joinRoom(String inviteCode) =>
      _api.joinRoom(inviteCode);
  @override
  Future<ListeningRoom> joinPublicRoom(String roomId) =>
      _api.joinPublicRoom(roomId);
  @override
  Future<void> leaveRoom(String roomId) => _api.leaveRoom(roomId);
  @override
  Future<ListeningRoom> setRoomTrack(String roomId, String trackId) =>
      _api.setRoomTrack(roomId, trackId);
  @override
  Future<ListeningRoom> updateRoomPlayback(
    String roomId,
    String trackId, {
    required int positionMs,
    required bool playing,
  }) =>
      _api.updateRoomPlayback(
        roomId,
        trackId,
        positionMs: positionMs,
        playing: playing,
      );
  @override
  Future<ListeningRoom> addToRoomQueue(String roomId, String trackId) =>
      _api.addToRoomQueue(roomId, trackId);

  @override
  Future<ListeningRoom> advanceRoomQueue(
          String roomId, String finishedTrackId) =>
      _api.advanceRoomQueue(roomId, finishedTrackId);
  @override
  Future<TrackLyrics> getLyrics(String trackId) => _api.getLyrics(trackId);
  @override
  Future<TrackLyrics> refreshLyrics(String trackId) =>
      _api.refreshLyrics(trackId);
  @override
  Future<TrackLyrics> updateLyrics(
    String trackId, {
    required String language,
    required String plainLyrics,
    required String syncedLyrics,
  }) =>
      _api.updateLyrics(
        trackId,
        language: language,
        plainLyrics: plainLyrics,
        syncedLyrics: syncedLyrics,
      );
  @override
  Future<String> askAssistant(String prompt) => _api.askAssistant(prompt);
}

class MockMusicRepository implements MusicRepository {
  static const _tracks = <Track>[
    Track(
        id: 't1',
        title: 'Vennela Velugulo',
        artist: 'Ananya Rao',
        album: 'Manasu',
        albumId: 'a1',
        duration: '4:12',
        color: '7C4DFF',
        downloaded: true),
    Track(
        id: 't2',
        title: 'Oka Chinna Aasha',
        artist: 'Sandeep Kumar',
        album: 'Prayanam',
        albumId: 'a2',
        duration: '3:46',
        color: 'FF7043'),
    Track(
        id: 't3',
        title: 'Nuvvu Nenu',
        artist: 'Maya Iyer',
        album: 'Nadiche Kalalu',
        albumId: 'a3',
        duration: '4:08',
        color: '00A896',
        downloaded: true),
    Track(
        id: 't4',
        title: 'Godari Gattu',
        artist: 'Karthik V',
        album: 'Godari',
        albumId: 'a4',
        duration: '3:35',
        color: 'EC407A'),
    Track(
        id: 't5',
        title: 'Tholi Prema',
        artist: 'Riya Das',
        album: 'Manasu',
        albumId: 'a1',
        duration: '4:28',
        color: '42A5F5'),
    Track(
        id: 't6',
        title: 'Chukkala Daari',
        artist: 'Vivek Hari',
        album: 'Prayanam',
        albumId: 'a2',
        duration: '3:58',
        color: 'FF7043',
        downloaded: true),
    Track(
        id: 't7',
        title: 'Mabbullo',
        artist: 'Ananya Rao',
        album: 'Nadiche Kalalu',
        albumId: 'a3',
        duration: '4:31',
        color: '00A896'),
    Track(
        id: 't8',
        title: 'Swaramaina',
        artist: 'Maya Iyer',
        album: 'Godari',
        albumId: 'a4',
        duration: '3:22',
        color: 'EC407A'),
  ];

  @override
  Future<HomeData> getHome() async => HomeData(
        recentlyPlayed: [_tracks[0], _tracks[5], _tracks[2], _tracks[3]],
        collections: [
          MusicCollection(
              id: 'c1',
              title: 'Made for your evening',
              subtitle: 'Gentle Telugu melodies',
              color: '7C4DFF',
              kind: CollectionKind.mix,
              tracks: [_tracks[0], _tracks[2], _tracks[4]]),
          MusicCollection(
              id: 'c2',
              title: 'Movie magic',
              subtitle: 'Soundtracks to revisit',
              color: 'FF7043',
              kind: CollectionKind.movie,
              tracks: [_tracks[1], _tracks[3], _tracks[7]]),
          MusicCollection(
              id: 'c3',
              title: 'Road trip Telugu',
              subtitle: 'Open roads, loud songs',
              color: '00A896',
              kind: CollectionKind.mix,
              tracks: [_tracks[3], _tracks[0], _tracks[5]]),
        ],
        featuredAlbums: await getAlbums(),
      );

  @override
  Future<List<Album>> getAlbums() async => [
        Album(
            id: 'a1',
            title: 'Manasu',
            artist: 'Various mock artists',
            description: 'A warm, imagined collection for slow evenings.',
            year: 2026,
            color: '7C4DFF',
            tracks: [_tracks[0], _tracks[4]]),
        Album(
            id: 'a2',
            title: 'Prayanam',
            artist: 'Sandeep Kumar',
            description:
                'Fictional travel-pop from a world that exists only in this demo.',
            year: 2026,
            color: 'FF7043',
            tracks: [_tracks[1], _tracks[5]]),
        Album(
            id: 'a3',
            title: 'Nadiche Kalalu',
            artist: 'Maya Iyer',
            description:
                'Dreamy mock metadata — add your own licensed tracks later.',
            year: 2025,
            color: '00A896',
            tracks: [_tracks[2], _tracks[6]]),
        Album(
            id: 'a4',
            title: 'Godari',
            artist: 'Original Motion Mock',
            description:
                'A sample movie universe for browsing and soundtrack pages.',
            year: 2026,
            color: 'EC407A',
            tracks: [_tracks[3], _tracks[7]],
            isMovie: true),
      ];

  @override
  Future<List<Playlist>> getPlaylists() async => [
        Playlist(
            id: 'p1',
            name: 'Late night adda',
            description: '4 songs • Private',
            color: '7C4DFF',
            tracks: [_tracks[0], _tracks[2], _tracks[6], _tracks[4]],
            isPinned: true),
        Playlist(
            id: 'p2',
            name: 'Drive to Vizag',
            description: '3 songs • Downloaded',
            color: 'FF7043',
            tracks: [_tracks[5], _tracks[3], _tracks[1]]),
      ];

  @override
  Future<ListeningRoom> getRoom() async => ListeningRoom(
        id: 'r1',
        name: 'Sunday melodies',
        host: 'Srinu',
        inviteCode: 'MANA-03',
        isPublic: false,
        listeners: 3,
        track: _tracks[0],
        queue: [_tracks[0], _tracks[2], _tracks[5]],
        positionMs: 0,
        roomPlaying: false,
      );

  @override
  Future<Playlist> createPlaylist(String name) async => Playlist(
        id: 'local-' + DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: 'New private playlist',
        color: 'F59E0B',
        tracks: const [],
      );

  @override
  Future<Playlist> addTrackToPlaylist(String playlistId, Track track) async {
    final playlist = (await getPlaylists()).firstWhere(
      (item) => item.id == playlistId,
      orElse: () => Playlist(
        id: playlistId,
        name: 'New playlist',
        description: 'New private playlist',
        color: 'F59E0B',
        tracks: const [],
      ),
    );
    return playlist.copyWith(tracks: [...playlist.tracks, track]);
  }

  @override
  Future<Album> updateAlbum(Album album) async => album;

  @override
  Future<void> deleteAlbum(String albumId) async {}

  @override
  Future<Track> updateTrack(Track track) async => track;

  @override
  Future<AudioReplacementResult> replaceTrackAudio(
          String trackId, String fileName, Uint8List bytes) async =>
      Future.error(StateError('Replacing audio needs the private backend.'));

  @override
  Future<List<AdminMember>> getAdminMembers() async => const [];

  @override
  Future<AdminMember> updateAdminMember(
    String memberId, {
    bool? active,
    bool? isAdmin,
  }) =>
      Future.error(StateError('Member management needs the private backend.'));

  @override
  Future<Uint8List> exportBackup() async => Uint8List.fromList(utf8.encode(
        '{"schemaVersion":1,"tracks":[],"albums":[],"playlists":[],"lyrics":[]}',
      ));

  @override
  Future<void> restoreBackup(Uint8List bytes) async {}

  @override
  Future<List<Track>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    return _tracks
        .where((track) => (track.title + track.artist + track.album)
            .toLowerCase()
            .contains(normalized))
        .toList();
  }

  @override
  Future<ImportReceipt> importMusic(ImportRequest request) async {
    final label = switch (request.source) {
      ImportSource.deviceFile => 'Device file',
      ImportSource.deviceFolder => 'Folder or album',
      ImportSource.googleDrive => 'Google Drive',
      ImportSource.directUrl => 'Direct audio URL',
      ImportSource.metadataLink => 'YouTube / Spotify link',
    };
    return ImportReceipt(
      source: request.source,
      message: label +
          ' saved as an import request. Connect the backend to process it.',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<ImportReceipt> uploadAudio(String fileName, Uint8List bytes,
          {required String title,
          required String artist,
          required String album,
          required String color,
          required String singers,
          required String musicDirector,
          required String genre,
          required String artworkUrl,
          required String sourceUrl}) async =>
      ImportReceipt(
        source: ImportSource.deviceFile,
        message: '$fileName selected for a local demo import.',
        createdAt: DateTime.now(),
      );

  @override
  Future<void> deleteTrack(String trackId) async {}

  @override
  Future<TrackMetadataSuggestion> suggestMetadata(String query) async =>
      TrackMetadataSuggestion(
        title: query.replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), ''),
        artist: '',
        album: '',
        singers: '',
        musicDirector: '',
        genre: '',
        year: 0,
        color: '7C4DFF',
        thumbnailUrl: '',
        sourceUrl: '',
        source: 'Manual',
        generated: false,
        notice: 'Connect the private API to request AI suggestions.',
      );

  @override
  Future<ListeningRoom> createRoom(String name,
          {String? trackId, bool isPublic = false}) async =>
      ListeningRoom(
        id: 'local-room',
        name: name,
        host: 'You',
        inviteCode: isPublic ? '' : 'TUNE-LOCAL',
        isPublic: isPublic,
        listeners: 1,
        track: trackId == null
            ? null
            : _tracks.firstWhere((item) => item.id == trackId),
        queue: trackId == null
            ? const []
            : [_tracks.firstWhere((item) => item.id == trackId)],
        positionMs: 0,
        roomPlaying: false,
      );

  @override
  Future<ListeningRoom> joinRoom(String inviteCode) async => getRoom();

  @override
  Future<ListeningRoom> joinPublicRoom(String roomId) async => getRoom();

  @override
  Future<void> leaveRoom(String roomId) async {}

  @override
  Future<ListeningRoom> setRoomTrack(String roomId, String trackId) async =>
      getRoom();

  @override
  Future<ListeningRoom> updateRoomPlayback(
    String roomId,
    String trackId, {
    required int positionMs,
    required bool playing,
  }) async =>
      getRoom();

  @override
  Future<List<ListeningRoom>> getPublicRooms() async => const [];

  @override
  Future<ListeningRoom> addToRoomQueue(String roomId, String trackId) async =>
      getRoom();

  @override
  Future<ListeningRoom> advanceRoomQueue(
          String roomId, String finishedTrackId) async =>
      getRoom();

  @override
  Future<TrackLyrics> getLyrics(String trackId) async => const TrackLyrics(
        trackId: 't1',
        language: 'te',
        source: 'demo',
        plainLyrics: 'వెన్నెల వెలుగులో\nమనసు పాడే పాట',
        syncedLyrics: '[00:00.00] వెన్నెల వెలుగులో\n[00:08.00] మనసు పాడే పాట',
        lines: [
          SyncedLyricLine(start: Duration.zero, text: 'వెన్నెల వెలుగులో'),
          SyncedLyricLine(start: Duration(seconds: 8), text: 'మనసు పాడే పాట'),
        ],
      );

  @override
  Future<TrackLyrics> refreshLyrics(String trackId) => getLyrics(trackId);

  @override
  Future<TrackLyrics> updateLyrics(
    String trackId, {
    required String language,
    required String plainLyrics,
    required String syncedLyrics,
  }) =>
      getLyrics(trackId);

  @override
  Future<String> askAssistant(String prompt) async {
    if (prompt.toLowerCase().contains('download')) {
      return 'Try downloading “Late night adda” before you head out. Three mock tracks are already marked offline.';
    }
    return 'For a mellow Telugu session, start with Vennela Velugulo, then let Sunday melodies continue the queue.';
  }
}
