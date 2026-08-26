enum CollectionKind { mix, album, movie, playlist }

enum ImportSource {
  deviceFile,
  deviceFolder,
  googleDrive,
  directUrl,
  metadataLink
}

class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.isAdmin = false,
  });

  final String id;
  final String displayName;
  final String email;
  final bool isAdmin;
}

class AdminMember {
  const AdminMember({
    required this.id,
    required this.displayName,
    required this.email,
    required this.active,
    required this.isAdmin,
    required this.isOwner,
  });

  final String id;
  final String displayName;
  final String email;
  final bool active;
  final bool isAdmin;
  final bool isOwner;
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.color,
    this.singers = '',
    this.musicDirector = '',
    this.genre = '',
    this.artworkUrl = '',
    this.sourceUrl = '',
    this.downloaded = false,
    this.isExplicit = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String duration;
  final String color;
  final String singers;
  final String musicDirector;
  final String genre;
  final String artworkUrl;
  final String sourceUrl;
  final bool downloaded;
  final bool isExplicit;

  Track copyWith({bool? downloaded}) => Track(
        id: id,
        title: title,
        artist: artist,
        album: album,
        albumId: albumId,
        duration: duration,
        color: color,
        singers: singers,
        musicDirector: musicDirector,
        genre: genre,
        artworkUrl: artworkUrl,
        sourceUrl: sourceUrl,
        downloaded: downloaded ?? this.downloaded,
        isExplicit: isExplicit,
      );
}

class MusicCollection {
  const MusicCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.kind,
    required this.tracks,
  });

  final String id;
  final String title;
  final String subtitle;
  final String color;
  final CollectionKind kind;
  final List<Track> tracks;
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.description,
    required this.year,
    required this.color,
    required this.tracks,
    this.isMovie = false,
  });

  final String id;
  final String title;
  final String artist;
  final String description;
  final int year;
  final String color;
  final List<Track> tracks;
  final bool isMovie;
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.tracks,
    this.isPinned = false,
  });

  final String id;
  final String name;
  final String description;
  final String color;
  final List<Track> tracks;
  final bool isPinned;

  Playlist copyWith({List<Track>? tracks}) => Playlist(
        id: id,
        name: name,
        description: description,
        color: color,
        tracks: tracks ?? this.tracks,
        isPinned: isPinned,
      );
}

class ListeningRoom {
  const ListeningRoom({
    required this.id,
    required this.name,
    required this.host,
    required this.inviteCode,
    required this.isPublic,
    required this.listeners,
    this.track,
    required this.queue,
    this.positionMs = 0,
    this.roomPlaying = false,
    this.connected = true,
  });

  final String id;
  final String name;
  final String host;
  final String inviteCode;
  final bool isPublic;
  final int listeners;
  final Track? track;
  final List<Track> queue;

  /// Host position returned by the API, already adjusted using the server clock.
  final int positionMs;
  final bool roomPlaying;
  final bool connected;

  ListeningRoom copyWith({
    bool? connected,
    List<Track>? queue,
    int? listeners,
    Track? track,
    bool? isPublic,
    int? positionMs,
    bool? roomPlaying,
  }) =>
      ListeningRoom(
        id: id,
        name: name,
        host: host,
        inviteCode: inviteCode,
        isPublic: isPublic ?? this.isPublic,
        track: track ?? this.track,
        queue: queue ?? this.queue,
        positionMs: positionMs ?? this.positionMs,
        roomPlaying: roomPlaying ?? this.roomPlaying,
        connected: connected ?? this.connected,
        listeners: listeners ?? this.listeners,
      );
}

class TrackMetadataSuggestion {
  const TrackMetadataSuggestion({
    required this.title,
    required this.artist,
    required this.album,
    required this.singers,
    required this.musicDirector,
    required this.genre,
    required this.year,
    required this.color,
    required this.thumbnailUrl,
    required this.sourceUrl,
    required this.source,
    required this.generated,
    required this.notice,
  });

  final String title;
  final String artist;
  final String album;
  final String singers;
  final String musicDirector;
  final String genre;
  final int year;
  final String color;
  final String thumbnailUrl;
  final String sourceUrl;
  final String source;
  final bool generated;
  final String notice;
}

class HomeData {
  const HomeData({
    required this.collections,
    required this.featuredAlbums,
    required this.recentlyPlayed,
  });

  final List<MusicCollection> collections;
  final List<Album> featuredAlbums;
  final List<Track> recentlyPlayed;
}

class ImportRequest {
  const ImportRequest({required this.source, this.value = ''});

  final ImportSource source;
  final String value;
}

class ImportReceipt {
  const ImportReceipt({
    required this.source,
    required this.message,
    required this.createdAt,
    this.fileName = '',
    this.originalBytes = 0,
    this.storedBytes = 0,
    this.compressed = false,
  });

  final ImportSource source;
  final String message;
  final DateTime createdAt;
  final String fileName;
  final int originalBytes;
  final int storedBytes;
  final bool compressed;
}

class AudioReplacementResult {
  const AudioReplacementResult({
    required this.track,
    required this.originalBytes,
    required this.storedBytes,
    required this.compressed,
  });

  final Track track;
  final int originalBytes;
  final int storedBytes;
  final bool compressed;
}
