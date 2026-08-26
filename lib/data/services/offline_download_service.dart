import 'offline_download_service_stub.dart'
    if (dart.library.io) 'offline_download_service_io.dart';

abstract class OfflineDownloadService {
  factory OfflineDownloadService(String apiBaseUrl, String authToken) =
      OfflineDownloadServiceImpl;

  Future<void> initialize();
  Set<String> get downloadedTrackIds;
  Future<String?> localPathForTrack(String trackId);
  Future<void> download(
    String trackId, {
    void Function(double progress)? onProgress,
  });
  Future<void> remove(String trackId);
}
