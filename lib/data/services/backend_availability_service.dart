import 'dart:async';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

class BackendAvailabilityService {
  BackendAvailabilityService(
    String apiBaseUrl, {
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 12),
      Duration(seconds: 15),
      Duration(seconds: 15),
    ],
  })  : _healthUri = _healthUriFor(apiBaseUrl),
        _client = client ?? createHttpClient();

  final Uri _healthUri;
  final http.Client _client;
  final Duration requestTimeout;
  final List<Duration> retryDelays;

  Future<bool> waitUntilReady(
      {required void Function(int attempt) onAttempt}) async {
    final attempts = retryDelays.length + 1;
    try {
      for (var index = 0; index < attempts; index++) {
        onAttempt(index + 1);
        try {
          final response = await _client.get(_healthUri, headers: const {
            'Accept': 'application/json'
          }).timeout(requestTimeout);
          // Any non-server error proves that the service is awake. Authentication
          // and endpoint errors are handled by the actual API request afterwards.
          if (response.statusCode < 500) return true;
        } catch (_) {
          // A sleeping Render instance usually refuses or times out initially.
        }
        if (index < retryDelays.length) {
          await Future<void>.delayed(retryDelays[index]);
        }
      }
      return false;
    } finally {
      _client.close();
    }
  }

  static Uri _healthUriFor(String apiBaseUrl) {
    final apiUri = Uri.parse(apiBaseUrl);
    return apiUri.replace(
        path: '/actuator/health', query: null, fragment: null);
  }
}
