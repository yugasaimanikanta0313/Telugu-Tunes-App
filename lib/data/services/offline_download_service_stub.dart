import 'offline_download_service.dart';

class OfflineDownloadServiceImpl implements OfflineDownloadService {
  OfflineDownloadServiceImpl(String apiBaseUrl, String authToken);
  final Set<String> _downloaded = <String>{};

  @override
  Set<String> get downloadedTrackIds => Set.unmodifiable(_downloaded);

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> localPathForTrack(String trackId) async => null;

  @override
  Future<void> download(
    String trackId, {
    void Function(double progress)? onProgress,
  }) async {
    throw UnsupportedError(
      'Offline audio downloads are available in the Android app.',
    );
  }

  @override
  Future<void> remove(String trackId) async {
    _downloaded.remove(trackId);
  }
}
