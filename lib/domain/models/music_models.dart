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
    this.audioVersion = '',
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
  final String audioVersion;
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
        audioVersion: audioVersion,
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
    this.artworkUrl = '',
    this.isMovie = false,
  });

  final String id;
  final String title;
  final String artist;
  final String description;
  final int year;
  final String color;
  final String artworkUrl;
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
    this.artworkUrl = '',
    this.isPinned = false,
  });

  final String id;
  final String name;
  final String description;
  final String color;
  final String artworkUrl;
  final List<Track> tracks;
  final bool isPinned;

  Playlist copyWith({List<Track>? tracks}) => Playlist(
        id: id,
        name: name,
        description: description,
        color: color,
        artworkUrl: artworkUrl,
        tracks: tracks ?? this.tracks,
        isPinned: isPinned,
      );
}

class RecommendedPlaylist {
  const RecommendedPlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.subtype,
    required this.color,
    required this.tracks,
    this.artworkUrl = '',
    this.active = true,
    this.scheduleEnabled = false,
    this.scheduleDays = const [],
    this.scheduleStart = '',
    this.scheduleEnd = '',
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final String subtype;
  final String color;
  final String artworkUrl;
  final List<Track> tracks;
  final bool active;
  final bool scheduleEnabled;
  final List<int> scheduleDays;
  final String scheduleStart;
  final String scheduleEnd;

  String get scheduleLabel {
    if (!scheduleEnabled) return 'Available anytime';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = scheduleDays
        .where((day) => day >= 1 && day <= 7)
        .map((day) => names[day - 1])
        .join(', ');
    final time = scheduleStart.isEmpty || scheduleEnd.isEmpty
        ? 'All day'
        : '$scheduleStart–$scheduleEnd';
    return '${days.isEmpty ? 'Every day' : days} • $time';
  }
}

class RecommendationVoteSuggestion {
  const RecommendationVoteSuggestion({
    required this.track,
    required this.playlist,
    required this.voteCount,
    required this.reasons,
  });

  final Track track;
  final RecommendedPlaylist playlist;
  final int voteCount;
  final List<String> reasons;
}

const recommendedPlaylistSubtypes = <String, List<String>>{
  'Devotional': ['Shiva', 'Venkateswara', 'Hanuman', 'Gospel', 'Sufi'],
  'Workout & Fitness': ['Leg Day', 'HIIT', 'Cardio/Running', 'Yoga/Stretching'],
  'Focus & Work': [
    'Deep Coding',
    'Reading',
    'Lo-Fi Study',
    'Ambient White Noise'
  ],
  'Mood & Emotion': [
    'Uplifting/Happy',
    'Melancholy/Heartbreak',
    'Calming',
    'Hype'
  ],
  'Party & Celebration': [
    'Weekend Pre-game',
    'House Party',
    'Club Dance',
    'Sundowner'
  ],
  'Sleep & Wellness': [
    'Guided Meditation',
    'Deep Sleep',
    'Binaural Delta Waves',
    'Rain Sounds'
  ],
  'Travel & Commute': [
    'Daily Car Commute',
    'Highway Long Drive',
    'Scenic Chill'
  ],
  'Nostalgia & Era': [
    '80s Classics',
    '90s Hits',
    '2000s Bollywood',
    'Retro Indipop'
  ],
};

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
    this.artworkCandidates = const [],
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
  final List<ArtworkCandidate> artworkCandidates;
}

class ArtworkCandidate {
  const ArtworkCandidate({
    required this.imageUrl,
    required this.title,
    required this.artist,
    required this.album,
    required this.source,
    required this.sourceUrl,
  });

  final String imageUrl;
  final String title;
  final String artist;
  final String album;
  final String source;
  final String sourceUrl;
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

class FestivalGreeting {
  const FestivalGreeting({
    required this.id,
    required this.date,
    required this.festival,
    required this.greeting,
    required this.color,
    this.artworkUrl = '',
    this.enabled = true,
    this.builtIn = false,
  });

  final String id;
  final DateTime date;
  final String festival;
  final String greeting;
  final String artworkUrl;
  final String color;
  final bool enabled;
  final bool builtIn;
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

class SyncedLyricLine {
  const SyncedLyricLine({required this.start, required this.text});

  final Duration start;
  final String text;
}

class TrackLyrics {
  const TrackLyrics({
    required this.trackId,
    required this.language,
    required this.source,
    required this.plainLyrics,
    required this.syncedLyrics,
    required this.lines,
  });

  final String trackId;
  final String language;
  final String source;
  final String plainLyrics;
  final String syncedLyrics;
  final List<SyncedLyricLine> lines;

  bool get hasLyrics => plainLyrics.trim().isNotEmpty || lines.isNotEmpty;
  bool get isSynced => lines.isNotEmpty;
}
