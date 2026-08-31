import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/music_models.dart';
import 'http_client_factory.dart';

/// The Flutter-side contract for the Spring Boot API.
/// Drive and Gemini credentials remain server-side.
abstract class MusicApiService {
  Future<HomeData> getHome();
  Future<List<Track>> search(String query);
  Future<List<Album>> getAlbums();
  Future<List<Playlist>> getPlaylists();
  Future<List<RecommendedPlaylist>> getRecommendedPlaylists(
      {bool admin = false});
  Future<List<RecommendedPlaylistPreference>>
      getRecommendedPlaylistPreferences();
  Future<RecommendedPlaylistPreference> saveRecommendedPlaylistPreference(
      RecommendedPlaylistPreference preference);
  Future<void> resetRecommendedPlaylistPreference(String playlistId);
  Future<FestivalRecommendation?> getFestivalRecommendation();
  Future<FestivalGreeting?> getTodayFestivalGreeting();
  Future<RecommendedPlaylist> saveRecommendedPlaylist(
      RecommendedPlaylist playlist);
  Future<void> deleteRecommendedPlaylist(String id);
  Future<void> voteForRecommendation(
      String trackId, String playlistId, String reason);
  Future<List<RecommendationVoteSuggestion>> getRecommendationVotes();
  Future<void> reviewRecommendationVote(
      String trackId, String playlistId, bool approve);
  Future<List<Track>> getFavorites();
  Future<List<Track>> setFavorite(String trackId, bool favorite);
  Future<ListeningRoom?> getRoom();
  Future<List<ListeningRoom>> getPublicRooms();
  Future<ApiSession> register({
    required String displayName,
    required String email,
    required String password,
  });
  Future<ApiSession> login({required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<String> verifyPasswordResetOtp(String email, String otp);
  Future<void> resetPassword(
      String email, String resetToken, String newPassword);
  Future<MemberProfile> getProfile();
  Future<Playlist> createPlaylist(String name);
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<Playlist> addTrackToPlaylist(String playlistId, String trackId);
  Future<List<PlaylistInvitation>> getPlaylistInvitations();
  Future<PlaylistInvitation> invitePlaylistCollaborator(
      String playlistId, String email);
  Future<PlaylistInvitation> respondToPlaylistInvitation(
      String invitationId, bool accept);
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
  Future<TrackLyrics> updateLyricsTranslation(
    String trackId, {
    required String englishPlainLyrics,
    required String englishSyncedLyrics,
  });
  Future<String> askAssistant(String prompt);
}

class ApiSession {
  const ApiSession({required this.config, required this.member});

  final BackendConfig config;
  final MemberProfile member;
}

class BackendConfig {
  const BackendConfig({
    required this.baseUrl,
    this.memberId = '',
    this.authToken = '',
  });

  final String baseUrl;
  final String memberId;
  final String authToken;

  BackendConfig copyWith({String? memberId, String? authToken}) =>
      BackendConfig(
        baseUrl: baseUrl,
        memberId: memberId ?? this.memberId,
        authToken: authToken ?? this.authToken,
      );

  static BackendConfig get development => BackendConfig(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: kIsWeb
              ? 'http://localhost:8080/api/v1'
              : 'http://10.0.2.2:8080/api/v1',
        ),
        memberId: const String.fromEnvironment('MEMBER_ID'),
      );
}

class SpringBootMusicApiService implements MusicApiService {
  SpringBootMusicApiService(this.config, {http.Client? client})
      : _client = client ?? createHttpClient();

  final BackendConfig config;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (config.authToken.isNotEmpty)
          'Authorization': 'Bearer ${config.authToken}',
      };

  @override
  Future<HomeData> getHome() async {
    final body = await _getMap('/home');
    return HomeData(
      collections: _list(body['collections']).map(_collection).toList(),
      featuredAlbums: _list(body['featuredAlbums']).map(_album).toList(),
      recentlyPlayed: _list(body['recentlyPlayed']).map(_track).toList(),
    );
  }

  @override
  Future<List<Track>> search(String query) async {
    final uri = Uri.parse(config.baseUrl + '/tracks/search')
        .replace(queryParameters: {'q': query});
    return (await _getListUri(uri)).map(_track).toList();
  }

  @override
  Future<List<Album>> getAlbums() async =>
      (await _getList('/albums')).map(_album).toList();

  @override
  Future<List<Playlist>> getPlaylists() async =>
      (await _getList('/playlists')).map(_playlist).toList();

  @override
  Future<List<RecommendedPlaylist>> getRecommendedPlaylists(
          {bool admin = false}) async =>
      (await _getList(admin
              ? '/recommended-playlists/admin'
              : '/recommended-playlists'))
          .map(_recommendedPlaylist)
          .toList();

  @override
  Future<List<RecommendedPlaylistPreference>>
      getRecommendedPlaylistPreferences() async =>
          (await _getList('/recommended-playlists/preferences'))
              .map(_recommendedPlaylistPreference)
              .toList();

  @override
  Future<RecommendedPlaylistPreference> saveRecommendedPlaylistPreference(
          RecommendedPlaylistPreference preference) async =>
      _recommendedPlaylistPreference(await _putMap(
          '/recommended-playlists/preferences/${preference.playlistId}', {
        'enabled': preference.enabled,
        'scheduleDays': preference.scheduleDays,
        'scheduleStart': preference.scheduleStart,
        'scheduleEnd': preference.scheduleEnd,
      }));

  @override
  Future<void> resetRecommendedPlaylistPreference(String playlistId) async {
    final response = await _client.delete(
        Uri.parse(
            '${config.baseUrl}/recommended-playlists/preferences/$playlistId'),
        headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  @override
  Future<FestivalRecommendation?> getFestivalRecommendation() async {
    final body = await _getMap('/recommended-playlists/festival');
    if (body['festival'] is! Map) return null;
    return FestivalRecommendation(
      festival:
          _festivalGreeting(Map<String, dynamic>.from(body['festival'] as Map)),
      playlists: _list(body['playlists']).map(_recommendedPlaylist).toList(),
    );
  }

  @override
  Future<FestivalGreeting?> getTodayFestivalGreeting() async {
    final response = await _client.get(
        Uri.parse('${config.baseUrl}/festival-greetings/today'),
        headers: _headers);
    if (response.statusCode == 204) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
    return _festivalGreeting(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  @override
  Future<RecommendedPlaylist> saveRecommendedPlaylist(
      RecommendedPlaylist playlist) async {
    final body = {
      'name': playlist.name,
      'description': playlist.description,
      'type': playlist.type,
      'subtype': playlist.subtype,
      'color': playlist.color,
      'artworkUrl': playlist.artworkUrl,
      'trackIds': playlist.tracks.map((track) => track.id).toList(),
      'active': playlist.active,
      'scheduleEnabled': playlist.scheduleEnabled,
      'scheduleDays': playlist.scheduleDays,
      'scheduleStart': playlist.scheduleStart,
      'scheduleEnd': playlist.scheduleEnd,
    };
    return _recommendedPlaylist(playlist.id.isEmpty
        ? await _postMap('/recommended-playlists', body)
        : await _putMap('/recommended-playlists/${playlist.id}', body));
  }

  @override
  Future<void> deleteRecommendedPlaylist(String id) async {
    final response = await _client.delete(
        Uri.parse('${config.baseUrl}/recommended-playlists/$id'),
        headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw StateError(_errorMessage(response));
  }

  @override
  Future<void> voteForRecommendation(
      String trackId, String playlistId, String reason) async {
    await _postEmpty('/recommendation-votes/tracks/$trackId', {
      'recommendedPlaylistId': playlistId,
      'reason': reason,
    });
  }

  @override
  Future<List<RecommendationVoteSuggestion>> getRecommendationVotes() async =>
      (await _getList('/recommendation-votes/admin'))
          .map((json) => RecommendationVoteSuggestion(
                track: _track(Map<String, dynamic>.from(json['track'] as Map)),
                playlist: _recommendedPlaylist(
                    Map<String, dynamic>.from(json['playlist'] as Map)),
                voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
                reasons:
                    _list(json['reasons']).map((v) => v.toString()).toList(),
              ))
          .toList();

  @override
  Future<void> reviewRecommendationVote(
      String trackId, String playlistId, bool approve) async {
    await _postEmpty(
        '/recommendation-votes/admin/$playlistId/tracks/$trackId/${approve ? 'approve' : 'reject'}',
        const {});
  }

  @override
  Future<List<Track>> getFavorites() async =>
      (await _getList('/favorites')).map(_track).toList();

  @override
  Future<List<Track>> setFavorite(String trackId, bool favorite) async {
    final uri = Uri.parse('${config.baseUrl}/favorites/$trackId');
    final response = favorite
        ? await _client.put(uri, headers: _headers)
        : await _client.delete(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
    return _list(jsonDecode(response.body)).map(_track).toList();
  }

  @override
  Future<ListeningRoom?> getRoom() async {
    final rooms = await _getList('/rooms');
    if (rooms.isEmpty) return null;
    final room = rooms.first;
    return ListeningRoom(
      id: room['id'] as String,
      name: room['name'] as String,
      host: room['hostMemberId'] as String,
      inviteCode: room['inviteCode'] as String,
      isPublic: room['publicRoom'] as bool? ?? false,
      listeners: (room['listeners'] as num?)?.toInt() ?? 0,
      track: room['track'] is Map
          ? _track(Map<String, dynamic>.from(room['track'] as Map))
          : null,
      queue: _list(room['queue']).map(_track).toList(),
      positionMs: (room['positionMs'] as num?)?.toInt() ?? 0,
      roomPlaying: room['playing'] as bool? ?? false,
      connected: room['active'] as bool? ?? true,
    );
  }

  @override
  Future<List<ListeningRoom>> getPublicRooms() async =>
      (await _getList('/rooms/public')).map(_room).toList();

  @override
  Future<ApiSession> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      _authenticate('/auth/register', {
        'displayName': displayName,
        'email': email,
        'password': password,
      });

  @override
  Future<ApiSession> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  @override
  Future<void> requestPasswordReset(String email) async {
    await _postMap('/auth/forgot-password', {'email': email});
  }

  @override
  Future<String> verifyPasswordResetOtp(String email, String otp) async {
    final result =
        await _postMap('/auth/verify-reset-otp', {'email': email, 'otp': otp});
    return result['resetToken'] as String;
  }

  @override
  Future<void> resetPassword(
      String email, String resetToken, String newPassword) async {
    await _postMap('/auth/reset-password', {
      'email': email,
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  @override
  Future<MemberProfile> getProfile() async {
    final json = await _getMap('/profile');
    return MemberProfile(
      id: json['memberId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      isAdmin: json['admin'] as bool? ?? false,
    );
  }

  @override
  Future<Playlist> createPlaylist(String name) async =>
      _playlist(await _postMap('/playlists', {
        'name': name,
        'description': 'Created in Telugu Tunes',
        'color': 'F59E0B',
        'artworkUrl': '',
      }));

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) async => _playlist(
        await _putMap('/playlists/${playlist.id}', {
          'name': playlist.name,
          'description': playlist.description,
          'color': playlist.color,
          'artworkUrl': playlist.artworkUrl,
        }),
      );

  @override
  Future<Playlist> addTrackToPlaylist(
          String playlistId, String trackId) async =>
      _playlist(await _postMap(
          '/playlists/$playlistId/tracks/$trackId', const <String, dynamic>{}));

  @override
  Future<List<PlaylistInvitation>> getPlaylistInvitations() async =>
      (await _getList('/playlists/invitations'))
          .map(_playlistInvitation)
          .toList();

  @override
  Future<PlaylistInvitation> invitePlaylistCollaborator(
          String playlistId, String email) async =>
      _playlistInvitation(await _postMap(
          '/playlists/$playlistId/invitations', {'email': email}));

  @override
  Future<PlaylistInvitation> respondToPlaylistInvitation(
          String invitationId, bool accept) async =>
      _playlistInvitation(await _postMap(
          '/playlists/invitations/$invitationId/${accept ? 'accept' : 'reject'}',
          const {}));

  @override
  Future<Album> updateAlbum(Album album) async => _album(
        await _putMap('/albums/${album.id}', {
          'title': album.title,
          'artist': album.artist,
          'description': album.description,
          'year': album.year,
          'color': album.color,
          'artworkUrl': album.artworkUrl,
          'movie': album.isMovie,
        }),
      );

  @override
  Future<void> deleteAlbum(String albumId) async {
    final response = await _client.delete(
      Uri.parse(config.baseUrl + '/albums/$albumId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  @override
  Future<Track> updateTrack(Track track) async => _track(
        await _putMap('/tracks/${track.id}', {
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'singers': track.singers,
          'musicDirector': track.musicDirector,
          'genre': track.genre,
          'color': track.color,
          'artworkUrl': track.artworkUrl,
          'sourceUrl': track.sourceUrl,
        }),
      );

  @override
  Future<AudioReplacementResult> replaceTrackAudio(
      String trackId, String fileName, Uint8List bytes) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(config.baseUrl + '/tracks/$trackId/audio'),
    )
      ..headers.addAll(_headers)
      ..files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final response = await http.Response.fromStream(await request.send());
    final body = _decodeMap(response);
    return AudioReplacementResult(
      track: _track(Map<String, dynamic>.from(body['track'] as Map)),
      originalBytes: (body['originalBytes'] as num?)?.toInt() ?? bytes.length,
      storedBytes: (body['storedBytes'] as num?)?.toInt() ?? bytes.length,
      compressed: body['compressed'] as bool? ?? false,
    );
  }

  @override
  Future<List<AdminMember>> getAdminMembers() async =>
      (await _getList('/admin/members')).map(_adminMember).toList();

  @override
  Future<AdminMember> updateAdminMember(
    String memberId, {
    bool? active,
    bool? isAdmin,
  }) async =>
      _adminMember(await _patchMap('/admin/members/$memberId', {
        if (active != null) 'active': active,
        if (isAdmin != null) 'admin': isAdmin,
      }));

  @override
  Future<Uint8List> exportBackup() async {
    final response = await _client.get(
      Uri.parse(config.baseUrl + '/admin/backup'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
    return response.bodyBytes;
  }

  @override
  Future<void> restoreBackup(Uint8List bytes) async {
    final response = await _client.post(
      Uri.parse(config.baseUrl + '/admin/backup'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  @override
  Future<ImportReceipt> importMusic(ImportRequest request) async {
    final body = await _postMap('/imports/reference', {
      'source': request.source.name,
      'value': request.value,
    });
    return ImportReceipt(
      source: request.source,
      message: body['message'] as String,
      createdAt: DateTime.now(),
    );
  }

  @override
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
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(config.baseUrl + '/imports/audio'),
    )
      ..headers.addAll(_headers)
      ..files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName))
      ..fields.addAll({
        'title': title,
        'artist': artist,
        'album': album,
        'color': color,
        'singers': singers,
        'musicDirector': musicDirector,
        'genre': genre,
        'artworkUrl': artworkUrl,
        'sourceUrl': sourceUrl,
      });
    final response = await http.Response.fromStream(await request.send());
    final body = _decodeMap(response);
    return ImportReceipt(
      source: ImportSource.deviceFile,
      message: body['message'] as String,
      createdAt: DateTime.now(),
      fileName: body['originalFileName'] as String? ?? fileName,
      originalBytes: (body['originalBytes'] as num?)?.toInt() ?? bytes.length,
      storedBytes: (body['storedBytes'] as num?)?.toInt() ?? bytes.length,
      compressed: body['compressed'] as bool? ?? false,
    );
  }

  @override
  Future<void> deleteTrack(String trackId) async {
    final response = await _client.delete(
      Uri.parse(config.baseUrl + '/tracks/$trackId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  @override
  Future<TrackMetadataSuggestion> suggestMetadata(String query) async {
    final body = await _postMap('/assistant/metadata', {'query': query});
    return TrackMetadataSuggestion(
      title: body['title'] as String? ?? query,
      artist: body['artist'] as String? ?? '',
      album: body['album'] as String? ?? '',
      singers: body['singers'] as String? ?? '',
      musicDirector: body['musicDirector'] as String? ?? '',
      genre: body['genre'] as String? ?? '',
      year: (body['year'] as num?)?.toInt() ?? 0,
      color: body['color'] as String? ?? '7C4DFF',
      thumbnailUrl: body['thumbnailUrl'] as String? ?? '',
      sourceUrl: body['sourceUrl'] as String? ?? '',
      source: body['source'] as String? ?? 'Manual',
      generated: body['generated'] as bool? ?? false,
      notice: body['notice'] as String? ?? '',
      artworkCandidates: (body['artworkCandidates'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ArtworkCandidate(
                imageUrl: item['imageUrl'] as String? ?? '',
                title: item['title'] as String? ?? '',
                artist: item['artist'] as String? ?? '',
                album: item['album'] as String? ?? '',
                source: item['source'] as String? ?? '',
                sourceUrl: item['sourceUrl'] as String? ?? '',
              ))
          .where((item) => item.imageUrl.isNotEmpty)
          .toList(),
    );
  }

  @override
  Future<ListeningRoom> createRoom(String name,
          {String? trackId, bool isPublic = false}) async =>
      _room(await _postMap('/rooms', {
        'name': name,
        'currentTrackId': trackId,
        'publicRoom': isPublic,
      }));

  @override
  Future<ListeningRoom> joinRoom(String inviteCode) async =>
      _room(await _postMap('/rooms/join', {'inviteCode': inviteCode}));

  @override
  Future<ListeningRoom> joinPublicRoom(String roomId) async =>
      _room(await _postMap('/rooms/public/$roomId/join', const {}));

  @override
  Future<void> leaveRoom(String roomId) async {
    final response = await _client.post(
      Uri.parse(config.baseUrl + '/rooms/$roomId/leave'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  @override
  Future<ListeningRoom> setRoomTrack(String roomId, String trackId) async =>
      _room(await _postMap('/rooms/$roomId/track/$trackId', const {}));

  @override
  Future<ListeningRoom> updateRoomPlayback(
    String roomId,
    String trackId, {
    required int positionMs,
    required bool playing,
  }) async =>
      _room(await _putMap('/rooms/$roomId/playback', {
        'trackId': trackId,
        'positionMs': positionMs,
        'playing': playing,
      }));

  @override
  Future<ListeningRoom> addToRoomQueue(String roomId, String trackId) async =>
      _room(await _postMap('/rooms/$roomId/queue/$trackId', const {}));

  @override
  Future<ListeningRoom> advanceRoomQueue(
          String roomId, String finishedTrackId) async =>
      _room(await _postMap(
          '/rooms/$roomId/queue/advance/$finishedTrackId', const {}));

  @override
  Future<TrackLyrics> getLyrics(String trackId) async =>
      _lyrics(await _getMap('/tracks/$trackId/lyrics'));

  @override
  Future<TrackLyrics> refreshLyrics(String trackId) async =>
      _lyrics(await _postMap('/tracks/$trackId/lyrics/import', const {}));

  @override
  Future<TrackLyrics> updateLyrics(
    String trackId, {
    required String language,
    required String plainLyrics,
    required String syncedLyrics,
  }) async =>
      _lyrics(await _putMap('/tracks/$trackId/lyrics', {
        'language': language,
        'plainLyrics': plainLyrics,
        'syncedLyrics': syncedLyrics,
      }));

  @override
  Future<TrackLyrics> updateLyricsTranslation(
    String trackId, {
    required String englishPlainLyrics,
    required String englishSyncedLyrics,
  }) async =>
      _lyrics(await _putMap('/tracks/$trackId/lyrics/translation', {
        'englishPlainLyrics': englishPlainLyrics,
        'englishSyncedLyrics': englishSyncedLyrics,
      }));

  @override
  Future<String> askAssistant(String prompt) async {
    final response = await _client.post(
      Uri.parse(config.baseUrl + '/assistant'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );
    return _decodeMap(response)['text'] as String;
  }

  Future<Map<String, dynamic>> _getMap(String path) async => _decodeMap(
      await _client.get(Uri.parse(config.baseUrl + path), headers: _headers));

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> body, {
    bool includeMember = true,
  }) async =>
      _decodeMap(
        await _client.post(
          Uri.parse(config.baseUrl + path),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (includeMember && config.authToken.isNotEmpty)
              'Authorization': 'Bearer ${config.authToken}',
          },
          body: jsonEncode(body),
        ),
      );

  Future<void> _postEmpty(String path, Map<String, dynamic> body) async {
    final response = await _client.post(Uri.parse(config.baseUrl + path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
  }

  Future<Map<String, dynamic>> _putMap(
    String path,
    Map<String, dynamic> body,
  ) async =>
      _decodeMap(
        await _client.put(
          Uri.parse(config.baseUrl + path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Map<String, dynamic> body,
  ) async =>
      _decodeMap(
        await _client.patch(
          Uri.parse(config.baseUrl + path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  Future<List<Map<String, dynamic>>> _getList(String path) async =>
      _getListUri(Uri.parse(config.baseUrl + path));

  Future<List<Map<String, dynamic>>> _getListUri(Uri uri) async {
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
    return _list(jsonDecode(response.body));
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(response));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  String _errorMessage(http.Response response) {
    try {
      final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      return body['message'] as String? ??
          'API request failed with status ${response.statusCode}';
    } catch (_) {
      return 'API request failed with status ${response.statusCode}';
    }
  }

  Future<ApiSession> _authenticate(
      String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse(config.baseUrl + path),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );
    final json = _decodeMap(response);
    final member = MemberProfile(
      id: json['memberId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      isAdmin: json['admin'] as bool? ?? false,
    );
    return ApiSession(
      config: config.copyWith(
          memberId: member.id, authToken: json['token'] as String),
      member: member,
    );
  }

  Track _track(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        albumId: json['albumId'] as String,
        duration: json['duration'] as String,
        color: json['color'] as String,
        singers: json['singers'] as String? ?? '',
        musicDirector: json['musicDirector'] as String? ?? '',
        genre: json['genre'] as String? ?? '',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        audioVersion: json['audioVersion'] as String? ?? '',
        downloaded: json['downloaded'] as bool? ?? false,
      );

  MusicCollection _collection(Map<String, dynamic> json) => MusicCollection(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        color: json['color'] as String,
        kind: CollectionKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => CollectionKind.mix,
        ),
        tracks: _list(json['tracks']).map(_track).toList(),
      );

  Album _album(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        description: json['description'] as String,
        year: json['year'] as int,
        color: json['color'] as String,
        artworkUrl: json['artworkUrl'] as String? ?? '',
        isMovie: json['movie'] as bool? ?? false,
        tracks: _list(json['tracks']).map(_track).toList(),
      );

  Playlist _playlist(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        color: json['color'] as String,
        artworkUrl: json['artworkUrl'] as String? ?? '',
        tracks: _list(json['tracks']).map(_track).toList(),
        ownerMemberId: json['ownerMemberId'] as String? ?? '',
        ownedByCurrentMember: json['ownedByCurrentMember'] as bool?,
        sharedWithMemberIds: _list(json['sharedWithMemberIds'])
            .map((v) => v.toString())
            .toList(),
        trackAddedByNames: (json['trackAddedByNames'] as Map? ?? const {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );

  PlaylistInvitation _playlistInvitation(Map<String, dynamic> json) =>
      PlaylistInvitation(
        id: json['id'] as String,
        playlistId: json['playlistId'] as String,
        playlistName: json['playlistName'] as String,
        inviterName: json['inviterName'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  RecommendedPlaylist _recommendedPlaylist(Map<String, dynamic> json) =>
      RecommendedPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        type: json['type'] as String? ?? 'Mood & Emotion',
        subtype: json['subtype'] as String? ?? 'Calming',
        color: json['color'] as String? ?? '7C4DFF',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        tracks: _list(json['tracks']).map(_track).toList(),
        active: json['active'] as bool? ?? true,
        scheduleEnabled: json['scheduleEnabled'] as bool? ?? false,
        scheduleDays: (json['scheduleDays'] is List
                ? json['scheduleDays'] as List
                : const <dynamic>[])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(),
        scheduleStart: json['scheduleStart'] as String? ?? '',
        scheduleEnd: json['scheduleEnd'] as String? ?? '',
      );

  RecommendedPlaylistPreference _recommendedPlaylistPreference(
          Map<String, dynamic> json) =>
      RecommendedPlaylistPreference(
        playlistId: json['playlistId'] as String,
        enabled: json['enabled'] as bool? ?? true,
        scheduleDays: (json['scheduleDays'] is List
                ? json['scheduleDays'] as List
                : const <dynamic>[])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(),
        scheduleStart: json['scheduleStart'] as String? ?? '',
        scheduleEnd: json['scheduleEnd'] as String? ?? '',
      );

  FestivalGreeting _festivalGreeting(Map<String, dynamic> json) =>
      FestivalGreeting(
        id: json['id'] as String? ?? '',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        festival: json['festival'] as String? ?? '',
        greeting: json['greeting'] as String? ?? '',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        color: json['color'] as String? ?? 'E15184',
        enabled: json['enabled'] as bool? ?? true,
        builtIn: json['builtIn'] as bool? ?? false,
      );

  AdminMember _adminMember(Map<String, dynamic> json) => AdminMember(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        active: json['active'] as bool? ?? false,
        isAdmin: json['admin'] as bool? ?? false,
        isOwner: json['owner'] as bool? ?? false,
      );

  ListeningRoom _room(Map<String, dynamic> room) => ListeningRoom(
        id: room['id'] as String,
        name: room['name'] as String,
        host: room['hostMemberId'] as String,
        inviteCode: room['inviteCode'] as String,
        isPublic: room['publicRoom'] as bool? ?? false,
        listeners: (room['listeners'] as num?)?.toInt() ?? 0,
        track: room['track'] is Map
            ? _track(Map<String, dynamic>.from(room['track'] as Map))
            : null,
        queue: _list(room['queue']).map(_track).toList(),
        positionMs: (room['positionMs'] as num?)?.toInt() ?? 0,
        roomPlaying: room['playing'] as bool? ?? false,
        connected: room['active'] as bool? ?? true,
      );

  TrackLyrics _lyrics(Map<String, dynamic> json) {
    final synced = json['syncedLyrics'] as String? ?? '';
    final englishSynced = json['englishSyncedLyrics'] as String? ?? '';
    final lines = _parseSyncedLyrics(synced);
    final englishLines = _parseSyncedLyrics(englishSynced);
    return TrackLyrics(
      trackId: json['trackId'] as String? ?? '',
      language: json['language'] as String? ?? 'te',
      source: json['source'] as String? ?? 'unavailable',
      plainLyrics: json['plainLyrics'] as String? ?? '',
      syncedLyrics: synced,
      lines: lines,
      englishPlainLyrics: json['englishPlainLyrics'] as String? ?? '',
      englishSyncedLyrics: englishSynced,
      englishLines: englishLines,
    );
  }

  List<SyncedLyricLine> _parseSyncedLyrics(String synced) {
    final expression = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$');
    final lines = <SyncedLyricLine>[];
    for (final rawLine in synced.split(RegExp(r'\r?\n'))) {
      final match = expression.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.tryParse(match.group(1)!) ?? 0;
      final seconds = double.tryParse(match.group(2)!) ?? 0;
      lines.add(SyncedLyricLine(
        start:
            Duration(milliseconds: ((minutes * 60 + seconds) * 1000).round()),
        text: match.group(3)?.trim() ?? '',
      ));
    }
    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  }
}
