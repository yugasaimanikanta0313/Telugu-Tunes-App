import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Keeps platform audio code out of widgets and provides one player for both
/// the mini-player and the full now-playing screen.
class AudioPlaybackService {
  AudioPlaybackService(this._apiBaseUrl, this._authToken) {
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
  final AudioPlayer _player = AudioPlayer();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _completed = StreamController<void>.broadcast();
  late final List<StreamSubscription<dynamic>> _subscriptions;
  String? _loadedTrackId;

  bool get isAvailable => _apiBaseUrl.isNotEmpty;
  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _duration.stream;
  Stream<bool> get playingStream => _playing.stream;
  Stream<String> get errorStream => _errors.stream;
  Stream<void> get completedStream => _completed.stream;
  Duration get position => _player.position;
  bool get isPlaying => _player.playing;

  Future<void> play(String trackId) async {
    if (!isAvailable) {
      throw StateError(
          'Connect the private API before playing uploaded audio.');
    }
    if (_loadedTrackId != trackId) await _load(trackId);
    await _player.play();
  }

  /// Brings a guest close to the host clock without restarting audio unless needed.
  Future<void> synchronize(
    String trackId,
    Duration target,
    bool shouldPlay,
  ) async {
    if (!isAvailable) return;
    final safeTarget = target.isNegative ? Duration.zero : target;
    if (_loadedTrackId != trackId) {
      final loading = Stopwatch()..start();
      await _load(trackId);
      loading.stop();
      // The host continues playing while a guest buffers a newly selected track.
      // Include that elapsed time so the guest does not begin several seconds behind.
      final caughtUpTarget =
          shouldPlay ? safeTarget + loading.elapsed : safeTarget;
      await _player.seek(caughtUpTarget);
    } else if ((_player.position - safeTarget).inMilliseconds.abs() > 200) {
      await _player.seek(safeTarget);
    }
    if (shouldPlay && !_player.playing) {
      await _player.play();
    } else if (!shouldPlay && _player.playing) {
      await _player.pause();
    }
  }

  Future<void> _load(String trackId) async {
    await _player.stop();
    _loadedTrackId = null;
    final streamUrl = Uri.parse('$_apiBaseUrl/audio/$trackId').replace(
      queryParameters: {
        // Ensures Chrome obtains a fresh audio response when a private file was just replaced.
        'playback': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    await _player.setUrl(
      streamUrl.toString(),
      headers:
          _authToken.isEmpty ? null : {'Authorization': 'Bearer $_authToken'},
    );
    _loadedTrackId = trackId;
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else if (_loadedTrackId != null) {
      await _player.play();
    }
  }

  Future<void> seek(double fraction) async {
    final duration = _player.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;
    await _player.seek(Duration(
      milliseconds:
          (duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    ));
  }

  Future<void> invalidate(String trackId) async {
    if (_loadedTrackId != trackId) return;
    await _player.stop();
    _loadedTrackId = null;
  }

  Future<void> dispose() async {
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
