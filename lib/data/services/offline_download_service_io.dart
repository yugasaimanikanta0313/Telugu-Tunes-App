import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_download_service.dart';

class OfflineDownloadServiceImpl implements OfflineDownloadService {
  OfflineDownloadServiceImpl(this._apiBaseUrl, this._authToken);

  static const _preferencesKey = 'offline_audio_files_v1';
  final String _apiBaseUrl;
  final String _authToken;
  final Map<String, String> _paths = <String, String>{};
  SharedPreferences? _preferences;
  Directory? _directory;

  @override
  Set<String> get downloadedTrackIds => Set.unmodifiable(_paths.keys.toSet());

  @override
  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    final root = await getApplicationSupportDirectory();
    _directory ??=
        Directory('${root.path}${Platform.pathSeparator}offline_audio');
    await _directory!.create(recursive: true);
    final saved = _preferences!.getString(_preferencesKey);
    if (saved == null || saved.isEmpty) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      for (final entry in decoded.entries) {
        final path = entry.value as String?;
        if (path != null && await File(path).exists()) _paths[entry.key] = path;
      }
      await _persist();
    } catch (_) {
      await _preferences!.remove(_preferencesKey);
    }
  }

  @override
  Future<String?> localPathForTrack(String trackId) async {
    await initialize();
    final path = _paths[trackId];
    if (path == null) return null;
    if (await File(path).exists()) return path;
    _paths.remove(trackId);
    await _persist();
    return null;
  }

  @override
  Future<void> download(
    String trackId, {
    void Function(double progress)? onProgress,
  }) async {
    await initialize();
    if (_apiBaseUrl.isEmpty) {
      throw StateError('Connect the private API before downloading audio.');
    }
    final client = http.Client();
    final request = http.Request(
      'GET',
      Uri.parse('$_apiBaseUrl/audio/$trackId'),
    );
    if (_authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    final temporary = File(
      '${_directory!.path}${Platform.pathSeparator}$trackId.download',
    );
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Download failed with status ${response.statusCode}.');
      }
      final extension = _extensionFor(response.headers['content-type']);
      final destination = File(
        '${_directory!.path}${Platform.pathSeparator}$trackId$extension',
      );
      final sink = temporary.openWrite();
      var received = 0;
      final total = response.contentLength ?? 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
      final previous = _paths[trackId];
      _paths[trackId] = destination.path;
      if (previous != null && previous != destination.path) {
        final previousFile = File(previous);
        if (await previousFile.exists()) await previousFile.delete();
      }
      await _persist();
      onProgress?.call(1);
    } finally {
      client.close();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> remove(String trackId) async {
    await initialize();
    final path = _paths.remove(trackId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _preferences!.setString(_preferencesKey, jsonEncode(_paths));
  }

  String _extensionFor(String? contentType) {
    final normalized = contentType?.toLowerCase() ?? '';
    if (normalized.contains('mp4') || normalized.contains('m4a')) return '.m4a';
    if (normalized.contains('ogg')) return '.ogg';
    if (normalized.contains('aac')) return '.aac';
    if (normalized.contains('wav')) return '.wav';
    return '.mp3';
  }
}
