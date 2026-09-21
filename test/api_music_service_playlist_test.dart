import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:telugu_tunes/data/services/api_music_service.dart';

void main() {
  test('playlist parser accepts collaborator ID strings', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/playlists');
      return http.Response(
          '''[
        {
          "id":"playlist-1",
          "name":"Devotional",
          "description":"Common playlist",
          "color":"F59E0B",
          "artworkUrl":"",
          "tracks":[],
          "sharedWithMemberIds":["6a8cd7fdc740c0b2f7dfe373"],
          "ownerMemberId":"6a8cbaf26f6d902f831ef2fd",
          "ownedByCurrentMember":false,
          "trackAddedByNames":{}
        }
      ]''',
          200,
          headers: {'content-type': 'application/json'});
    });
    final service = SpringBootMusicApiService(
      const BackendConfig(
        baseUrl: 'http://localhost/api/v1',
        memberId: '6a8cd7fdc740c0b2f7dfe373',
        authToken: 'test-token',
      ),
      client: client,
    );

    final playlists = await service.getPlaylists();

    expect(playlists, hasLength(1));
    expect(playlists.single.ownedByCurrentMember, isFalse);
    expect(playlists.single.sharedWithMemberIds, ['6a8cd7fdc740c0b2f7dfe373']);
  });

  test('YouTube metadata falls back when the dedicated route is unavailable',
      () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/metadata/youtube')) {
        return http.Response('{"status":404}', 404,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
        '''{
          "title":"Devuda",
          "artist":"Mani Sharma",
          "album":"Pokiri",
          "singers":"Naveen",
          "musicDirector":"Mani Sharma",
          "genre":"Film Soundtrack",
          "thumbnailUrl":"https://example.com/cover.jpg",
          "sourceUrl":"https://youtube.com/watch?v=test",
          "source":"YouTube",
          "generated":false,
          "notice":"YouTube fallback",
          "artworkCandidates":[]
        }''',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = SpringBootMusicApiService(
      const BackendConfig(baseUrl: 'http://localhost/api/v1'),
      client: client,
    );

    final suggestion = await service.suggestYouTubeMetadata('Devuda');

    expect(requestedPaths, [
      '/api/v1/assistant/metadata/youtube',
      '/api/v1/assistant/metadata',
    ]);
    expect(suggestion.title, 'Devuda');
    expect(suggestion.thumbnailUrl, 'https://example.com/cover.jpg');
  });
}
