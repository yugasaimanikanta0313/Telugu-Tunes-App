import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/repositories/music_repository.dart';
import '../data/services/audio_playback_service.dart';
import '../data/services/artwork_palette_service.dart';
import '../data/services/offline_download_service.dart';
import '../data/services/room_realtime_service.dart';
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
    _palette = ArtworkPaletteService();
    _offline = OfflineDownloadService(apiBaseUrl, authToken);
    _audio = AudioPlaybackService(
      apiBaseUrl,
      authToken,
      localPathForTrack: _offline.localPathForTrack,
    );
    _roomRealtime = RoomRealtimeService(
      apiBaseUrl: apiBaseUrl,
      authToken: authToken,
      onPlayback: (event) => unawaited(_handleRealtimePlayback(event)),
      onRoomChanged: () => unawaited(_pollRoom()),
      onStatusChanged: _roomStatusChanged,
    );
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
      _audio.trackChangedStream.listen(_audioTrackChanged),
      _audio.completedStream.listen((_) {
        _offerTrackVote(current);
        unawaited(_playNextRoomTrack());
      }),
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
  late final ArtworkPaletteService _palette;
  late final OfflineDownloadService _offline;
  late final RoomRealtimeService _roomRealtime;
  late final List<StreamSubscription<dynamic>> _subscriptions;
  Timer? _roomPolling;
  Timer? _roomPlaybackPublisher;
  Timer? _roomRealtimePublisher;
  Timer? _publicRoomsPolling;
  bool _pollingRoom = false;
  bool _publishingRoomPlayback = false;
  bool _suppressRoomStatusNotification = false;
  ListeningRoom? _pendingRoomSync;
  Future<void>? _roomSyncWorker;
  Timer? _sleepTimer;
  Timer? _votePromptTimer;
  HomeData? _home;
  List<Album> _albums = [];
  List<Playlist> _playlists = [];
  List<RecommendedPlaylist> _recommendedPlaylists = [];
  List<ListeningRoom> publicRooms = [];
  List<Track> searchResults = [];
  ListeningRoom? room;
  final Set<String> favorites = {'t1', 't3'};
  final Set<String> downloaded = <String>{};
  final Map<String, double> downloadProgress = <String, double>{};
  final List<RoomSyncLog> syncLogs = <RoomSyncLog>[];
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
  int themeColorValue = 0xffe15184;
  RoomConnectionStatus roomConnectionStatus = RoomConnectionStatus.disconnected;
  int roomDriftMs = 0;
  TrackLyrics? currentLyrics;
  Track? votePromptTrack;
  bool lyricsLoading = false;
  String? lyricsError;
  DateTime? sleepEndsAt;
  bool _sleepStoppedPlayback = false;
  SyncCorrectionKind? _lastLoggedCorrection;
  DateTime? _lastCorrectionLogAt;

  List<MusicCollection> get collections => _home?.collections ?? [];
  List<Album> get albums => _albums;
  List<Playlist> get playlists => _playlists;
  List<RecommendedPlaylist> get recommendedPlaylists => _recommendedPlaylists;
  List<Track> get recentlyPlayed => _home?.recentlyPlayed ?? [];
  List<Track> get allTracks => [for (final album in _albums) ...album.tracks];
  List<Track> get favoriteTracks =>
      allTracks.where((track) => favorites.contains(track.id)).toList();
  List<Track> get downloadedTracks =>
      allTracks.where((track) => downloaded.contains(track.id)).toList();
  bool isFavorite(Track track) => favorites.contains(track.id);
  bool isDownloaded(Track track) => downloaded.contains(track.id);
  bool isDownloading(Track track) => downloadProgress.containsKey(track.id);
  Duration get position => _position;
  Duration? get sleepRemaining => sleepEndsAt == null
      ? null
      : sleepEndsAt!.difference(DateTime.now()).isNegative
          ? Duration.zero
          : sleepEndsAt!.difference(DateTime.now());
  bool get canStream => _audio.isAvailable;
  bool get isAuthenticated => authToken.isNotEmpty && memberId.isNotEmpty;
  List<RecommendedPlaylist> eligibleVotePlaylists(Track track) =>
      _recommendedPlaylists
          .where((playlist) => playlist.active &&
              !playlist.tracks.any((item) => item.id == track.id))
          .toList();
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
      if (remoteMode) {
        await _offline.initialize();
        downloaded
          ..clear()
          ..addAll(_offline.downloadedTrackIds);
      }
      // The public catalog is the core experience. Load it independently so a
      // temporarily unavailable account feature cannot blank the whole app.
      final catalog = await Future.wait<dynamic>([
        _repository.getHome(),
        _repository.getAlbums(),
        _orDefault(
            _repository.getRecommendedPlaylists(), <RecommendedPlaylist>[]),
      ]);
      _home = catalog[0] as HomeData;
      _albums = catalog[1] as List<Album>;
      _recommendedPlaylists = catalog[2] as List<RecommendedPlaylist>;
      loadError = null;

      final account = isAuthenticated
          ? await Future.wait<dynamic>([
              _orDefault(_repository.getPlaylists(), <Playlist>[]),
              _orDefault<ListeningRoom?>(_repository.getRoom(), null),
              _orDefault(_repository.getPublicRooms(), <ListeningRoom>[]),
              _orDefault(_repository.getFavorites(), <Track>[]),
            ])
          : <dynamic>[<Playlist>[], null, <ListeningRoom>[], <Track>[]];
      _playlists = account[0] as List<Playlist>;
      room = account[1] as ListeningRoom?;
      publicRooms = account[2] as List<ListeningRoom>;
      favorites
        ..clear()
        ..addAll((account[3] as List<Track>).map((track) => track.id));
    } catch (error) {
      _home ??= const HomeData(
        collections: [],
        featuredAlbums: [],
        recentlyPlayed: [],
      );
      loadError = error.toString().replaceFirst('Bad state: ', '');
    }
    current ??= recentlyPlayed.firstOrNull ?? allTracks.firstOrNull;
    if (current != null) {
      unawaited(loadLyrics(current!));
      unawaited(_updateArtworkTheme(current!));
    }
    _configureRoomPolling();
    _configurePublicRoomPolling();
    loading = false;
    notifyListeners();
  }

  Future<T> _orDefault<T>(Future<T> request, T fallback) async {
    try {
      return await request;
    } catch (_) {
      return fallback;
    }
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
    _sleepStoppedPlayback = false;
    final activeRoom = room;
    if (activeRoom != null && activeRoom.host != memberId) {
      await _synchronizeToRoom(activeRoom);
      return;
    }
    current = track;
    unawaited(_updateArtworkTheme(track));
    unawaited(loadLyrics(track));
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
      await _audio.play(
        track,
        queue: room == null ? allTracks : [track],
      );
      _publishRealtimeRoomPlayback();
      unawaited(_publishRoomPlayback());
    } catch (error) {
      playing = false;
      playerError = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (current == null) return;
    if (!playing) _sleepStoppedPlayback = false;
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
        _publishRealtimeRoomPlayback();
        unawaited(_publishRoomPlayback());
      }
    } catch (error) {
      playerError = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> skipNext() async {
    if (allTracks.isEmpty) return;
    if (room == null && _audio.isAvailable && await _audio.skipNext()) return;
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
    if (room == null && _audio.isAvailable && await _audio.skipPrevious()) {
      return;
    }
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
      _publishRealtimeRoomPlayback();
      unawaited(_publishRoomPlayback());
    }
  }

  Future<void> seekTo(Duration position) async {
    final activeRoom = room;
    if (activeRoom != null && activeRoom.host != memberId) return;
    await _audio.seekTo(position);
    _publishRealtimeRoomPlayback();
    unawaited(_publishRoomPlayback());
  }

  Future<void> toggleFavorite(Track track) async {
    if (!isAuthenticated) return;
    final updated =
        await _repository.setFavorite(track.id, !favorites.contains(track.id));
    favorites
      ..clear()
      ..addAll(updated.map((value) => value.id));
    notifyListeners();
  }

  Future<void> toggleDownload(Track track) async {
    if (isDownloading(track)) return;
    if (downloaded.contains(track.id)) {
      await _offline.remove(track.id);
      downloaded.remove(track.id);
      await _audio.invalidate(track.id);
      notifyListeners();
      return;
    }
    downloadProgress[track.id] = 0;
    notifyListeners();
    try {
      await _offline.download(
        track.id,
        onProgress: (progress) {
          downloadProgress[track.id] = progress;
          notifyListeners();
        },
      );
      downloaded.add(track.id);
    } finally {
      downloadProgress.remove(track.id);
      notifyListeners();
    }
  }

  void toggleRoomConnection() {
    room = room?.copyWith(connected: !(room?.connected ?? false));
    notifyListeners();
  }

  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    unawaited(_audio.setShuffle(shuffleEnabled));
    notifyListeners();
  }

  void toggleRepeat() {
    repeatEnabled = !repeatEnabled;
    unawaited(_audio.setRepeat(repeatEnabled));
    notifyListeners();
  }

  void _audioTrackChanged(String trackId) {
    if (room != null) return;
    final finishedTrack = current;
    final finishedDuration = _duration;
    final naturallyCompleted = finishedTrack != null &&
        finishedDuration != null &&
        finishedDuration.inMilliseconds > 0 &&
        _position >= finishedDuration - const Duration(seconds: 2);
    Track? track;
    for (final item in allTracks) {
      if (item.id == trackId) {
        track = item;
        break;
      }
    }
    if (track == null || current?.id == track.id) return;
    if (naturallyCompleted) _offerTrackVote(finishedTrack);
    current = track;
    _position = Duration.zero;
    playerError = null;
    unawaited(loadLyrics(track));
    unawaited(_updateArtworkTheme(track));
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
    _pendingRoomSync = null;
    room = null;
    _suppressRoomStatusNotification = true;
    try {
      _configureRoomPolling();
    } finally {
      _suppressRoomStatusNotification = false;
    }
    await _stopSharedRoomPlayback();
    await _refreshPublicRooms();
    _addSyncLog(
      activeRoom.host == memberId
          ? 'Room closed and local playback stopped'
          : 'Left room and local playback stopped',
      roomDriftMs,
    );
    roomDriftMs = 0;
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
    _roomRealtimePublisher?.cancel();
    _roomRealtime.disconnect();
    if (!remoteMode || room == null) return;
    final activeRoom = room!;
    _roomRealtime.connect(activeRoom.id);
    // REST remains a low-frequency recovery path if a WebSocket is interrupted.
    _roomPolling = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollRoom());
    });
    if (activeRoom.host == memberId) {
      _roomRealtimePublisher =
          Timer.periodic(const Duration(milliseconds: 250), (_) {
        _publishRealtimeRoomPlayback();
      });
      _roomPlaybackPublisher = Timer.periodic(const Duration(seconds: 2), (_) {
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
        _pendingRoomSync = null;
        room = null;
        _suppressRoomStatusNotification = true;
        try {
          _configureRoomPolling();
        } finally {
          _suppressRoomStatusNotification = false;
        }
        await _stopSharedRoomPlayback();
        _addSyncLog('The host closed the room; playback stopped', roomDriftMs);
        roomDriftMs = 0;
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

  void _publishRealtimeRoomPlayback() {
    final activeRoom = room;
    final track = current;
    if (activeRoom == null ||
        track == null ||
        activeRoom.host != memberId ||
        activeRoom.track?.id != track.id) {
      return;
    }
    _roomRealtime.sendPlayback(
      roomId: activeRoom.id,
      trackId: track.id,
      positionMs: _audio.position.inMilliseconds,
      playing: _audio.isAvailable ? _audio.isPlaying : playing,
    );
  }

  Future<void> _handleRealtimePlayback(RoomRealtimePlayback event) async {
    var activeRoom = room;
    if (activeRoom == null ||
        activeRoom.id != event.roomId ||
        activeRoom.host == memberId) {
      return;
    }
    if (activeRoom.track?.id != event.trackId) {
      await _pollRoom();
      activeRoom = room;
      if (activeRoom == null || activeRoom.track?.id != event.trackId) return;
    }
    // expectedPosition = hostPosition + elapsedTimeSinceHostUpdate
    final expectedPosition =
        event.positionMs + (event.playing ? event.elapsedSinceHostUpdateMs : 0);
    final realtimeRoom = activeRoom.copyWith(
      positionMs: expectedPosition,
      roomPlaying: event.playing,
    );
    room = realtimeRoom;
    await _synchronizeToRoom(realtimeRoom);
  }

  Future<void> _synchronizeToRoom(ListeningRoom activeRoom) async {
    _pendingRoomSync = activeRoom;
    final activeWorker = _roomSyncWorker;
    if (activeWorker != null) return activeWorker;
    final worker = _drainRoomSynchronization();
    _roomSyncWorker = worker;
    try {
      await worker;
    } finally {
      _roomSyncWorker = null;
    }
    if (_pendingRoomSync != null) {
      await _synchronizeToRoom(_pendingRoomSync!);
    }
  }

  Future<void> _drainRoomSynchronization() async {
    while (_pendingRoomSync != null) {
      final activeRoom = _pendingRoomSync!;
      _pendingRoomSync = null;
      await _applyRoomSynchronization(activeRoom);
    }
  }

  Future<void> _applyRoomSynchronization(ListeningRoom activeRoom) async {
    if (room?.id != activeRoom.id) return;
    final track = activeRoom.track;
    if (track == null) return;
    if (current?.id != track.id) {
      unawaited(loadLyrics(track));
      unawaited(_updateArtworkTheme(track));
    }
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
    if (_sleepStoppedPlayback && activeRoom.roomPlaying) return;
    try {
      final correction =
          await _audio.synchronize(track, target, activeRoom.roomPlaying);
      if (room?.id != activeRoom.id) return;
      roomDriftMs = correction.driftMs;
      _recordCorrection(correction);
      playing = activeRoom.roomPlaying;
    } catch (error) {
      if (room?.id != activeRoom.id) return;
      playerError = error.toString().replaceFirst('Bad state: ', '');
      playing = false;
      _addSyncLog('Synchronization error: $playerError', roomDriftMs);
    }
    notifyListeners();
  }

  Future<void> _stopSharedRoomPlayback() async {
    if (_audio.isAvailable) await _audio.stop();
    current = null;
    playing = false;
    _position = Duration.zero;
    _duration = null;
    playerError = null;
  }

  void _roomStatusChanged(RoomConnectionStatus status) {
    roomConnectionStatus = status;
    final label = switch (status) {
      RoomConnectionStatus.connected => 'Live connection established',
      RoomConnectionStatus.connecting => 'Connecting to room',
      RoomConnectionStatus.reconnecting => 'Connection interrupted; retrying',
      RoomConnectionStatus.disconnected => 'Room connection closed',
    };
    _addSyncLog(label, roomDriftMs);
    if (!_suppressRoomStatusNotification) notifyListeners();
  }

  void _recordCorrection(SyncCorrection correction) {
    if (correction.kind == SyncCorrectionKind.none) return;
    final now = DateTime.now();
    final shouldLog = _lastLoggedCorrection != correction.kind ||
        _lastCorrectionLogAt == null ||
        now.difference(_lastCorrectionLogAt!) > const Duration(seconds: 3);
    if (!shouldLog) return;
    _lastLoggedCorrection = correction.kind;
    _lastCorrectionLogAt = now;
    final message = switch (correction.kind) {
      SyncCorrectionKind.gentleSpeed => 'Correcting drift smoothly',
      SyncCorrectionKind.hardSeek => 'Large drift corrected with one seek',
      SyncCorrectionKind.trackChange => 'Joined the host at the live position',
      SyncCorrectionKind.paused => 'Matched the host pause position',
      SyncCorrectionKind.none => 'In sync',
    };
    _addSyncLog(message, correction.driftMs);
  }

  void _addSyncLog(String message, int driftMs) {
    syncLogs.insert(
      0,
      RoomSyncLog(at: DateTime.now(), message: message, driftMs: driftMs),
    );
    if (syncLogs.length > 30) syncLogs.removeRange(30, syncLogs.length);
  }

  Future<void> loadLyrics(Track track, {bool force = false}) async {
    if (!force && currentLyrics?.trackId == track.id) return;
    lyricsLoading = true;
    lyricsError = null;
    if (current?.id == track.id) currentLyrics = null;
    notifyListeners();
    try {
      final result = force
          ? await _repository.refreshLyrics(track.id)
          : await _repository.getLyrics(track.id);
      if (current?.id == track.id) currentLyrics = result;
    } catch (error) {
      if (current?.id == track.id) {
        lyricsError = error.toString().replaceFirst('Bad state: ', '');
      }
    } finally {
      if (current?.id == track.id) lyricsLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLyrics(
    Track track, {
    required String language,
    required String plainLyrics,
    required String syncedLyrics,
  }) async {
    currentLyrics = await _repository.updateLyrics(
      track.id,
      language: language,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
    );
    lyricsError = null;
    notifyListeners();
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepStoppedPlayback = false;
    sleepEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().isBefore(sleepEndsAt!)) {
        notifyListeners();
        return;
      }
      timer.cancel();
      _sleepTimer = null;
      sleepEndsAt = null;
      _sleepStoppedPlayback = true;
      unawaited(_audio.stop().then((_) {
        playing = false;
        _publishRealtimeRoomPlayback();
        unawaited(_publishRoomPlayback());
        notifyListeners();
      }));
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepEndsAt = null;
    _sleepStoppedPlayback = false;
    notifyListeners();
  }

  Future<void> _updateArtworkTheme(Track track) async {
    final clean = track.color.replaceFirst('#', '');
    final fallback = int.tryParse('ff$clean', radix: 16) ?? 0xffe15184;
    if (themeColorValue != fallback) {
      themeColorValue = fallback;
      notifyListeners();
    }
    final extracted = await _palette.dominantColor(track.artworkUrl);
    if (extracted != null &&
        current?.id == track.id &&
        themeColorValue != extracted) {
      themeColorValue = extracted;
      notifyListeners();
    }
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
    await _offline.remove(track.id);
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

  Future<AudioReplacementResult> replaceTrackAudio(
      Track track, String fileName, Uint8List bytes) async {
    final result =
        await _repository.replaceTrackAudio(track.id, fileName, bytes);
    final updated = result.track;
    if (downloaded.remove(track.id)) await _offline.remove(track.id);
    final wasPlaying = current?.id == track.id && playing;
    if (current?.id == track.id) {
      await _audio.invalidate(track.id);
      current = updated;
      _position = Duration.zero;
      playing = false;
    }
    await load();
    if (wasPlaying) await play(updated);
    return result;
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

  Future<Uint8List> exportBackup() => _repository.exportBackup();

  Future<void> restoreBackup(Uint8List bytes) async {
    await _repository.restoreBackup(bytes);
    await load(announce: true);
  }

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

  Future<void> updatePlaylist(Playlist playlist) async {
    final updated = await _repository.updatePlaylist(playlist);
    _playlists = _playlists
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    final updated = await _repository.addTrackToPlaylist(playlistId, track);
    _playlists = _playlists
        .map((playlist) => playlist.id == playlistId ? updated : playlist)
        .toList();
    notifyListeners();
  }

  Future<List<RecommendedPlaylist>> getAdminRecommendedPlaylists() =>
      _repository.getRecommendedPlaylists(admin: true);

  Future<RecommendedPlaylist> saveRecommendedPlaylist(
      RecommendedPlaylist playlist) async {
    final saved = await _repository.saveRecommendedPlaylist(playlist);
    await load();
    return saved;
  }

  Future<void> deleteRecommendedPlaylist(String id) async {
    await _repository.deleteRecommendedPlaylist(id);
    await load();
  }

  Future<void> voteForRecommendation(
      Track track, RecommendedPlaylist playlist, String reason) async {
    if (!isAuthenticated) throw StateError('Sign in to vote for playlists.');
    await _repository.voteForRecommendation(track.id, playlist.id, reason);
    dismissVotePrompt();
  }

  Future<List<RecommendationVoteSuggestion>> getRecommendationVotes() =>
      _repository.getRecommendationVotes();

  Future<void> reviewRecommendationVote(
      RecommendationVoteSuggestion suggestion, bool approve) async {
    await _repository.reviewRecommendationVote(
        suggestion.track.id, suggestion.playlist.id, approve);
    if (approve) await load();
  }

  void _offerTrackVote(Track? track) {
    if (!isAuthenticated || room != null || track == null ||
        eligibleVotePlaylists(track).isEmpty) return;
    votePromptTrack = track;
    _votePromptTimer?.cancel();
    _votePromptTimer = Timer(const Duration(seconds: 5), dismissVotePrompt);
    notifyListeners();
  }

  void dismissVotePrompt() {
    _votePromptTimer?.cancel();
    if (votePromptTrack == null) return;
    votePromptTrack = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _votePromptTimer?.cancel();
    _roomPolling?.cancel();
    _roomPlaybackPublisher?.cancel();
    _roomRealtimePublisher?.cancel();
    _publicRoomsPolling?.cancel();
    _roomRealtime.disconnect();
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

class RoomSyncLog {
  const RoomSyncLog({
    required this.at,
    required this.message,
    required this.driftMs,
  });

  final DateTime at;
  final String message;
  final int driftMs;
}

extension FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
