import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class RoomRealtimePlayback {
  const RoomRealtimePlayback({
    required this.roomId,
    required this.trackId,
    required this.positionMs,
    required this.playing,
    required this.elapsedSinceHostUpdateMs,
  });

  final String roomId;
  final String trackId;
  final int positionMs;
  final bool playing;
  final int elapsedSinceHostUpdateMs;
}

/// Maintains one authenticated WebSocket for immediate listening-room updates.
class RoomRealtimeService {
  RoomRealtimeService({
    required String apiBaseUrl,
    required String authToken,
    required this.onPlayback,
    required this.onRoomChanged,
  })  : _uri = _webSocketUri(apiBaseUrl),
        _authToken = authToken;

  final Uri _uri;
  final String _authToken;
  final void Function(RoomRealtimePlayback event) onPlayback;
  final void Function() onRoomChanged;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeat;
  String? _roomId;
  int _generation = 0;
  int _authSentAtMs = 0;
  int _serverClockOffsetMs = 0;
  bool _connected = false;

  bool get connected => _connected;

  void connect(String roomId) {
    if (_roomId == roomId && (_channel != null || _reconnectTimer != null)) {
      return;
    }
    disconnect();
    _roomId = roomId;
    final generation = ++_generation;
    unawaited(_open(generation));
  }

  Future<void> _open(int generation) async {
    final roomId = _roomId;
    if (roomId == null || _authToken.isEmpty || generation != _generation) {
      return;
    }
    try {
      final channel = WebSocketChannel.connect(_uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) => _handleMessage(message, generation),
        onDone: () => _connectionLost(generation),
        onError: (_) => _connectionLost(generation),
        cancelOnError: true,
      );
      await channel.ready;
      if (generation != _generation || _roomId != roomId) {
        await channel.sink.close();
        return;
      }
      _authSentAtMs = DateTime.now().millisecondsSinceEpoch;
      channel.sink.add(jsonEncode({
        'type': 'authenticate',
        'token': _authToken,
        'roomId': roomId,
      }));
    } catch (_) {
      _connectionLost(generation);
    }
  }

  void _handleMessage(dynamic message, int generation) {
    if (generation != _generation || message is! String) return;
    try {
      final payload = jsonDecode(message);
      if (payload is! Map) return;
      final type = payload['type'] as String? ?? '';
      if (type == 'authenticated') {
        final now = DateTime.now().millisecondsSinceEpoch;
        final serverTime = (payload['serverTimeMs'] as num?)?.toInt() ?? now;
        final midpoint = _authSentAtMs + ((now - _authSentAtMs) ~/ 2);
        _serverClockOffsetMs = serverTime - midpoint;
        _connected = true;
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        });
        return;
      }
      if (type == 'room_changed') {
        onRoomChanged();
        return;
      }
      if (type != 'playback') return;
      final roomId = payload['roomId'] as String? ?? '';
      final trackId = payload['trackId'] as String? ?? '';
      if (roomId.isEmpty || trackId.isEmpty || roomId != _roomId) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final serverTime = (payload['serverTimeMs'] as num?)?.toInt() ?? now;
      final serverTimeOnLocalClock = serverTime - _serverClockOffsetMs;
      final elapsedSinceHostUpdateMs =
          (now - serverTimeOnLocalClock).clamp(0, 1 << 31).toInt();
      onPlayback(RoomRealtimePlayback(
        roomId: roomId,
        trackId: trackId,
        positionMs: (payload['positionMs'] as num?)?.toInt() ?? 0,
        playing: payload['playing'] as bool? ?? false,
        elapsedSinceHostUpdateMs: elapsedSinceHostUpdateMs,
      ));
    } catch (_) {
      // A malformed event should not end an otherwise healthy room connection.
    }
  }

  void sendPlayback({
    required String roomId,
    required String trackId,
    required int positionMs,
    required bool playing,
  }) {
    if (!_connected || roomId != _roomId) return;
    _channel?.sink.add(jsonEncode({
      'type': 'playback',
      'roomId': roomId,
      'trackId': trackId,
      'positionMs': positionMs,
      'playing': playing,
    }));
  }

  void _connectionLost(int generation) {
    if (generation != _generation || _roomId == null) return;
    _connected = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    _channel = null;
    _subscription = null;
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _reconnectTimer = null;
      if (generation == _generation && _roomId != null) {
        unawaited(_open(generation));
      }
    });
  }

  void disconnect() {
    _generation++;
    _connected = false;
    _roomId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.sink.close());
  }

  static Uri _webSocketUri(String apiBaseUrl) {
    final apiUri = Uri.parse(apiBaseUrl);
    return apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/rooms',
      query: null,
      fragment: null,
    );
  }
}
