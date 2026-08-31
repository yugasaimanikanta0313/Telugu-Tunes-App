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
}
