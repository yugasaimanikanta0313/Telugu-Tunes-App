import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/repositories/music_repository.dart';
import '../data/services/audio_playback_service.dart';
import '../domain/models/music_models.dart';

class MusicController extends ChangeNotifier {
  MusicController(
    this._repository, {
    this.remoteMode = false,
    this.apiBaseUrl = '',
    this.authToken = '',
    this.memberName = 'Srinu',
    this.memberId = '',
    this.isAdmin = false,
  }) {
    _audio = AudioPlaybackService(apiBaseUrl, authToken);
    _subscriptions = [
      _audio.positionStream.listen((value) {
        _position = value;
        notifyListeners();
      }),
      _audio.durationStream.listen((value) {
        _duration = value;
        notifyListeners();
      }),
      _audio.playingStream.listen((value) {
        playing = value;
        notifyListeners();
      }),
      _audio.errorStream.listen((value) {
        playerError = value;
        playing = false;
        notifyListeners();
      }),
      _audio.completedStream.listen((_) => unawaited(_playNextRoomTrack())),
    ];
  }

  final MusicRepository _repository;
  final bool remoteMode;
  final String apiBaseUrl;
  final String authToken;
  final String memberName;
  final String memberId;
  final bool isAdmin;
  late final AudioPlaybackService _audio;
  late final List<StreamSubscription<dynamic>> _subscriptions;
  Timer? _roomPolling;
  Timer? _roomPlaybackPublisher;
  Timer? _publicRoomsPolling;
  bool _pollingRoom = false;
  bool _publishingRoomPlayback = false;
  HomeData? _home;
  List<Album> _albums = [];
  List<Playlist> _playlists = [];
  List<ListeningRoom> publicRooms = [];
  List<Track> searchResults = [];
  ListeningRoom? room;
  final Set<String> favorites = {'t1', 't3'};
  final Set<String> downloaded = {'t1', 't3', 't6'};
  final List<ImportReceipt> imports = [];
  Track? current;
  bool playing = false;
  bool loading = true;
  int activeTab = 0;
  Duration _position = Duration.zero;
  Duration? _duration;
  String assistantReply = '';
  String? loadError;
  String? playerError;
  bool shuffleEnabled = false;
  bool repeatEnabled = false;

  List<MusicCollection> get collections => _home?.collections ?? [];
  List<Album> get albums => _albums;
  List<Playlist> get playlists => _playlists;
  List<Track> get recentlyPlayed => _home?.recentlyPlayed ?? [];
  List<Track> get allTracks => [for (final album in _albums) ...album.tracks];
  List<Track> get favoriteTracks =>
      allTracks.where((track) => favorites.contains(track.id)).toList();
  bool isFavorite(Track track) => favorites.contains(track.id);
  bool isDownloaded(Track track) => downloaded.contains(track.id);
  bool get canStream => _audio.isAvailable;
  double get progress {
    final duration = _duration;
    if (duration == null || duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get elapsedLabel => _formatDuration(_position);
  String get remainingDurationLabel => _duration == null
      ? current?.duration ?? '0:00'
      : _formatDuration(_duration!);

  Future<void> load({bool announce = false}) async {
    loading = true;
    if (announce) notifyListeners();
    try {
      final values = await Future.wait<dynamic>([
        _repository.getHome(),
        _repository.getAlbums(),
        _repository.getPlaylists(),
        _repository.getRoom(),
        _repository.getPublicRooms(),
      ]);
      _home = values[0] as HomeData;
      _albums = values[1] as List<Album>;
      _playlists = values[2] as List<Playlist>;
      room = values[3] as ListeningRoom?;
      publicRooms = values[4] as List<ListeningRoom>;
      loadError = null;
    } catch (error) {
      _home ??= const HomeData(
        collections: [],
        featuredAlbums: [],
        recentlyPlayed: [],
      );
      loadError = error.toString().replaceFirst('Bad state: ', '');
    }
    current ??= recentlyPlayed.firstOrNull ?? allTracks.firstOrNull;
    _configureRoomPolling();
    _configurePublicRoomPolling();
    loading = false;
    notifyListeners();
  }

  void setTab(int tab) {
    activeTab = tab;
    notifyListeners();
  }

  Future<void> search(String text) async {
    searchResults = await _repository.search(text);
    notifyListeners();
  }

  Future<void> play(Track track) async {
    final activeRoom = room;
    if (activeRoom != null && activeRoom.host != memberId) {
      await _synchronizeToRoom(activeRoom);
      return;
    }
    current = track;
    playerError = null;
    _position = Duration.zero;
    unawaited(_publishRoomTrack(track));
    if (!_audio.isAvailable) {
      playing = true;
      notifyListeners();
      return;
    }
    playing = true;
    notifyListeners();
    try {
      await _audio.play(track.id);
      unawaited(_publishRoomPlayback());
    } catch (error) {
      playing = false;
      playerError = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (current == null) return;
    final activeRoom = room;
    if (activeRoom != null &&
        activeRoom.host != memberId &&
        activeRoom.track?.id == current?.id) {
      await _synchronizeToRoom(activeRoom);
      return;
    }
    if (!_audio.isAvailable) {
      playing = !playing;
      notifyListeners();
      return;
    }
    try {
      if (!playing && _position == Duration.zero) {
        await play(current!);
      } else {
        await _audio.toggle();
        unawaited(_publishRoomPlayback());
      }
    } catch (error) {
      playerError = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> skipNext() async {
    if (allTracks.isEmpty) return;
    final index = allTracks.indexWhere((track) => track.id == current?.id);
    await play(allTracks[(index + 1) % allTracks.length]);
  }

  Future<void> _playNextRoomTrack() async {
    final activeRoom = room;
    final finishedTrack = current;
    if (activeRoom == null ||
        finishedTrack == null ||
        activeRoom.host != memberId) return;
    try {
      final advanced =
          await _repository.advanceRoomQueue(activeRoom.id, finishedTrack.id);
      room = advanced;
      final nextTrack = advanced.track;
      if (nextTrack == null) {
        playing = false;
        notifyListeners();
        return;
      }
      await play(nextTrack);
    } catch (_) {
      // The host can retry playback manually if advancing the shared queue is interrupted.
    }
  }

  Future<void> skipPrevious() async {
    if (allTracks.isEmpty) return;
    final index = allTracks.indexWhere((track) => track.id == current?.id);
    await play(allTracks[(index - 1 + allTracks.length) % allTracks.length]);
  }

  Future<void> seek(double value) async {
    final activeRoom = room;
    if (activeRoom != null &&
        activeRoom.host != memberId &&
        activeRoom.track?.id == current?.id) {
      await _synchronizeToRoom(activeRoom);
      return;
    }
    if (_audio.isAvailable) {
      await _audio.seek(value);
      unawaited(_publishRoomPlayback());
    }
  }

  void toggleFavorite(Track track) {
    favorites.contains(track.id)
        ? favorites.remove(track.id)
        : favorites.add(track.id);
    notifyListeners();
  }

  void toggleDownload(Track track) {
    downloaded.contains(track.id)
        ? downloaded.remove(track.id)
        : downloaded.add(track.id);
    notifyListeners();
  }

  void toggleRoomConnection() {
    room = room?.copyWith(connected: !(room?.connected ?? false));
    notifyListeners();
  }

  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    notifyListeners();
  }

  void toggleRepeat() {
    repeatEnabled = !repeatEnabled;
    notifyListeners();
  }

  Future<void> addToRoomQueue(Track track) async {
    final activeRoom = room;
    if (activeRoom == null ||
        activeRoom.queue.any((item) => item.id == track.id)) return;
    room = await _repository.addToRoomQueue(activeRoom.id, track.id);
    notifyListeners();
  }

  Future<void> createRoom(String name,
      {Track? startingTrack, bool isPublic = false}) async {
    if (room != null) {
      throw StateError('Leave your current room before creating another room.');
    }
    room = await _repository.createRoom(name,
        trackId: startingTrack?.id ?? current?.id, isPublic: isPublic);
    await _refreshPublicRooms();
    _configureRoomPolling();
    notifyListeners();
  }

  Future<void> joinRoom(String inviteCode) async {
    if (room != null) {
      throw StateError('Leave your current room before joining another room.');
    }
    room = await _repository.joinRoom(inviteCode);
    await _refreshPublicRooms();
    _configureRoomPolling();
    notifyListeners();
    if (room != null) await _synchronizeToRoom(room!);
  }

  Future<void> joinPublicRoom(String roomId) async {
    if (room != null) {
      throw StateError('Leave your current room before joining another room.');
    }
    room = await _repository.joinPublicRoom(roomId);
    await _refreshPublicRooms();
    _configureRoomPolling();
    notifyListeners();
    if (room != null) await _synchronizeToRoom(room!);
  }

  Future<void> leaveRoom() async {
    final activeRoom = room;
    if (activeRoom == null) return;
    await _repository.leaveRoom(activeRoom.id);
    room = null;
    _configureRoomPolling();
    await _refreshPublicRooms();
    notifyListeners();
  }

  Future<void> _refreshPublicRooms() async {
    publicRooms = await _repository.getPublicRooms();
  }

  void _configurePublicRoomPolling() {
    if (!remoteMode || _publicRoomsPolling != null) return;
    _publicRoomsPolling = Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_pollPublicRooms());
    });
  }

  Future<void> _pollPublicRooms() async {
    try {
      publicRooms = await _repository.getPublicRooms();
      notifyListeners();
    } catch (_) {
      // Public-room discovery should recover silently from short network interruptions.
    }
  }

  void _configureRoomPolling() {
    _roomPolling?.cancel();
    _roomPlaybackPublisher?.cancel();
    if (!remoteMode || room == null) return;
    _roomPolling = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_pollRoom());
    });
    final activeRoom = room;
    if (activeRoom != null && activeRoom.host == memberId) {
      _roomPlaybackPublisher =
          Timer.periodic(const Duration(milliseconds: 450), (_) {
        unawaited(_publishRoomPlayback());
      });
    }
  }

  Future<void> _pollRoom() async {
    if (_pollingRoom) return;
    final previous = room;
    if (previous == null) return;
    _pollingRoom = true;
    try {
      final refreshed = await _repository.getRoom();
      if (refreshed == null || refreshed.id != previous.id) {
        room = null;
        _configureRoomPolling();
        notifyListeners();
        return;
      }
      room = refreshed;
      notifyListeners();
      if (refreshed.host != memberId) {
        await _synchronizeToRoom(refreshed);
      }
    } catch (_) {
      // A short network interruption should not force someone out of their room.
    } finally {
      _pollingRoom = false;
    }
  }

  Future<void> _publishRoomTrack(Track track) async {
    final activeRoom = room;
    if (activeRoom == null ||
        activeRoom.host != memberId ||
        activeRoom.track?.id == track.id) {
      return;
    }
    try {
      room = await _repository.setRoomTrack(activeRoom.id, track.id);
      notifyListeners();
    } catch (_) {
      // The local player remains usable if the network update cannot be sent.
    }
  }

  Future<void> _publishRoomPlayback() async {
    if (_publishingRoomPlayback) return;
    final activeRoom = room;
    final track = current;
    if (activeRoom == null ||
        track == null ||
        activeRoom.host != memberId ||
        activeRoom.track?.id != track.id) {
      return;
    }
    _publishingRoomPlayback = true;
    try {
      room = await _repository.updateRoomPlayback(
        activeRoom.id,
        track.id,
        positionMs: _audio.position.inMilliseconds,
        playing: _audio.isAvailable ? _audio.isPlaying : playing,
      );
      notifyListeners();
    } catch (_) {
      // Playback continues locally if one sync request is interrupted.
    } finally {
      _publishingRoomPlayback = false;
    }
  }

  Future<void> _synchronizeToRoom(ListeningRoom activeRoom) async {
    final track = activeRoom.track;
    if (track == null) return;
    current = track;
    final target = Duration(
      milliseconds: activeRoom.positionMs.clamp(0, 1 << 31).toInt(),
    );
    _position = target;
    playerError = null;
    if (!_audio.isAvailable) {
      playing = activeRoom.roomPlaying;
      notifyListeners();
      return;
    }
    try {
      await _audio.synchronize(track.id, target, activeRoom.roomPlaying);
      playing = activeRoom.roomPlaying;
    } catch (error) {
      playerError = error.toString().replaceFirst('Bad state: ', '');
      playing = false;
    }
    notifyListeners();
  }

  Future<ImportReceipt> addImport(ImportRequest request) async {
    final receipt = await _repository.importMusic(request);
    imports.insert(0, receipt);
    notifyListeners();
    return receipt;
  }

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
    final receipt = await _repository.uploadAudio(
      fileName,
      bytes,
      title: title,
      artist: artist,
      album: album,
      color: color,
      singers: singers,
      musicDirector: musicDirector,
      genre: genre,
      artworkUrl: artworkUrl,
      sourceUrl: sourceUrl,
    );
    imports.insert(0, receipt);
    await load();
    return receipt;
  }

  Future<void> deleteTrack(Track track) async {
    await _repository.deleteTrack(track.id);
    favorites.remove(track.id);
    downloaded.remove(track.id);
    if (current?.id == track.id) {
      current = null;
      playing = false;
    }
    await load();
  }

  Future<void> updateTrack(Track track) async {
    await _repository.updateTrack(track);
    await load();
  }

  Future<void> replaceTrackAudio(
      Track track, String fileName, Uint8List bytes) async {
    final updated =
        await _repository.replaceTrackAudio(track.id, fileName, bytes);
    final wasPlaying = current?.id == track.id && playing;
    if (current?.id == track.id) {
      await _audio.invalidate(track.id);
      current = updated;
      _position = Duration.zero;
      playing = false;
    }
    await load();
    if (wasPlaying) await play(updated);
  }

  Future<void> updateAlbum(Album album) async {
    await _repository.updateAlbum(album);
    await load();
  }

  Future<void> deleteAlbum(Album album) async {
    await _repository.deleteAlbum(album.id);
    if (current?.albumId == album.id) {
      current = null;
      playing = false;
    }
    await load();
  }

  Future<List<AdminMember>> getAdminMembers() => _repository.getAdminMembers();

  Future<AdminMember> updateAdminMember(
    String memberId, {
    bool? active,
    bool? isAdmin,
  }) =>
      _repository.updateAdminMember(memberId, active: active, isAdmin: isAdmin);

  Future<TrackMetadataSuggestion> suggestMetadata(String query) =>
      _repository.suggestMetadata(query);

  Future<void> askAssistant(String prompt) async {
    assistantReply = await _repository.askAssistant(prompt);
    notifyListeners();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = await _repository.createPlaylist(name);
    _playlists = [playlist, ..._playlists];
    notifyListeners();
    return playlist;
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    final updated = await _repository.addTrackToPlaylist(playlistId, track);
    _playlists = _playlists
        .map((playlist) => playlist.id == playlistId ? updated : playlist)
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _roomPolling?.cancel();
    _roomPlaybackPublisher?.cancel();
    _publicRoomsPolling?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_audio.dispose());
    super.dispose();
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

extension FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
