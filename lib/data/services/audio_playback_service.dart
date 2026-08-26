import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/models/music_models.dart';

enum SyncCorrectionKind { none, gentleSpeed, hardSeek, trackChange, paused }

class SyncCorrection {
  const SyncCorrection({required this.kind, required this.driftMs});

  final SyncCorrectionKind kind;
  final int driftMs;
}

/// Owns the single player used by the mini-player and full player screen.
class AudioPlaybackService {
  AudioPlaybackService(
    this._apiBaseUrl,
    this._authToken, {
    required Future<String?> Function(String trackId) localPathForTrack,
  }) : _localPathForTrack = localPathForTrack {
    if (kIsWeb) {
      unawaited(_player.setWebCrossOrigin(WebCrossOrigin.useCredentials));
    }
    _subscriptions = [
      _player.positionStream.listen((value) => _position.add(value)),
      _player.durationStream.listen((value) => _duration.add(value)),
      _player.playerStateStream.listen((value) => _playing.add(value.playing)),
      _player.playerStateStream
          .where((value) => value.processingState == ProcessingState.completed)
          .listen((_) => _completed.add(null)),
      _player.errorStream
          .listen((error) => _errors.add('Playback failed: $error')),
    ];
  }

  final String _apiBaseUrl;
  final String _authToken;
  final Future<String?> Function(String trackId) _localPathForTrack;
  final AudioPlayer _player = AudioPlayer();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _completed = StreamController<void>.broadcast();
  late final List<StreamSubscription<dynamic>> _subscriptions;
  String? _loadedTrackId;
  Timer? _speedResetTimer;
  DateTime? _lastHardSeekAt;
  double _speed = 1;

  bool get isAvailable => _apiBaseUrl.isNotEmpty;
  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _duration.stream;
  Stream<bool> get playingStream => _playing.stream;
  Stream<String> get errorStream => _errors.stream;
  Stream<void> get completedStream => _completed.stream;
  Duration get position => _player.position;
  bool get isPlaying => _player.playing;

  Future<void> play(Track track) async {
    if (!isAvailable) {
      throw StateError(
          'Connect the private API before playing uploaded audio.');
    }
    if (_loadedTrackId != track.id) await _load(track);
    await _setSpeed(1);
    unawaited(_player.play());
  }

  /// Ignores tiny drift, gently corrects medium drift, and seeks only when the
  /// devices are far apart. This avoids the repeated buffering breaks caused
  /// by seeking every room update.
  Future<SyncCorrection> synchronize(
    Track track,
    Duration target,
    bool shouldPlay,
  ) async {
    if (!isAvailable) {
      return const SyncCorrection(kind: SyncCorrectionKind.none, driftMs: 0);
    }
    final safeTarget = target.isNegative ? Duration.zero : target;
    if (_loadedTrackId != track.id) {
      final loading = Stopwatch()..start();
      await _load(track);
      loading.stop();
      final caughtUpTarget =
          shouldPlay ? safeTarget + loading.elapsed : safeTarget;
      await _player.seek(caughtUpTarget);
      await _setSpeed(1);
      if (shouldPlay) unawaited(_player.play());
      return SyncCorrection(
        kind: SyncCorrectionKind.trackChange,
        driftMs: caughtUpTarget.inMilliseconds,
      );
    }

    final driftMs = safeTarget.inMilliseconds - _player.position.inMilliseconds;
    final absoluteDrift = driftMs.abs();
    if (!shouldPlay) {
      await _setSpeed(1);
      if (_player.playing) await _player.pause();
      if (absoluteDrift > 250) await _player.seek(safeTarget);
      return SyncCorrection(kind: SyncCorrectionKind.paused, driftMs: driftMs);
    }

    if (!_player.playing) unawaited(_player.play());
    if (absoluteDrift < 500) {
      if (absoluteDrift < 250) await _setSpeed(1);
      return SyncCorrection(kind: SyncCorrectionKind.none, driftMs: driftMs);
    }

    final hardSeekAllowed = _lastHardSeekAt == null ||
        DateTime.now().difference(_lastHardSeekAt!) >
            const Duration(seconds: 4);
    if (absoluteDrift > 2500 && hardSeekAllowed) {
      _lastHardSeekAt = DateTime.now();
      await _setSpeed(1);
      await _player.seek(safeTarget);
      return SyncCorrection(
          kind: SyncCorrectionKind.hardSeek, driftMs: driftMs);
    }

    await _setSpeed(driftMs > 0 ? 1.03 : 0.97, temporary: true);
    return SyncCorrection(
        kind: SyncCorrectionKind.gentleSpeed, driftMs: driftMs);
  }

  Future<void> _load(Track track) async {
    await _player.stop();
    _loadedTrackId = null;
    await _setSpeed(1);
    final localPath = await _localPathForTrack(track.id);
    final uri = localPath == null
        ? Uri.parse('$_apiBaseUrl/audio/${track.id}').replace(
            queryParameters: {
              'playback': DateTime.now().microsecondsSinceEpoch.toString(),
            },
          )
        : Uri.file(localPath);
    await _player.setAudioSource(AudioSource.uri(
      uri,
      headers: localPath == null && _authToken.isNotEmpty
          ? {'Authorization': 'Bearer $_authToken'}
          : null,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri:
            track.artworkUrl.isEmpty ? null : Uri.tryParse(track.artworkUrl),
      ),
    ));
    _loadedTrackId = track.id;
  }

  Future<void> _setSpeed(double speed, {bool temporary = false}) async {
    if ((_speed - speed).abs() > .001) {
      _speed = speed;
      await _player.setSpeed(speed);
    }
    _speedResetTimer?.cancel();
    _speedResetTimer = null;
    if (temporary) {
      _speedResetTimer = Timer(const Duration(seconds: 4), () {
        unawaited(_setSpeed(1));
      });
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _setSpeed(1);
      await _player.pause();
    } else if (_loadedTrackId != null) {
      unawaited(_player.play());
    }
  }

  Future<void> seek(double fraction) async {
    final duration = _player.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;
    await _setSpeed(1);
    await _player.seek(Duration(
      milliseconds:
          (duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    ));
  }

  Future<void> seekTo(Duration position) async {
    await _setSpeed(1);
    await _player.seek(position.isNegative ? Duration.zero : position);
  }

  Future<void> invalidate(String trackId) async {
    if (_loadedTrackId != trackId) return;
    await _setSpeed(1);
    await _player.stop();
    _loadedTrackId = null;
  }

  Future<void> stop() async {
    await _setSpeed(1);
    await _player.stop();
    _loadedTrackId = null;
  }

  Future<void> dispose() async {
    _speedResetTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _errors.close();
    await _completed.close();
    await _player.dispose();
  }
}
