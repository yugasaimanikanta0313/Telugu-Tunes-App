import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _input = TextEditingController();
  _SearchFilter _filter = _SearchFilter.all;
  List<String> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recentSearches =
          preferences.getStringList('recent_music_searches') ?? const []);
    }
  }

  Future<void> _rememberSearch(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return;
    final updated = [
      clean,
      ..._recentSearches
          .where((value) => value.toLowerCase() != clean.toLowerCase()),
    ].take(8).toList(growable: false);
    setState(() => _recentSearches = updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('recent_music_searches', updated);
  }

  void _useRecentSearch(String query) {
    _input.text = query;
    _input.selection = TextSelection.collapsed(offset: query.length);
    _search(query);
    _rememberSearch(query);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search(String query) {
    final prefix = switch (_filter) {
      _SearchFilter.songs => 'title:',
      _SearchFilter.albums => 'album:',
      _SearchFilter.artists => 'artist:',
      _SearchFilter.lyrics => 'lyrics:',
      _ => '',
    };
    context.read<MusicController>().search('$prefix$query');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final hasQuery = _input.text.trim().isNotEmpty;
    final playlistResults = <_PlaylistSearchResult>[
      ...controller.playlists.map((playlist) => _PlaylistSearchResult(
          playlist.name,
          playlist.description,
          playlist.artworkUrl,
          playlist.color,
          playlist.tracks)),
      ...controller.recommendedPlaylists.map((playlist) =>
          _PlaylistSearchResult(
              '${playlist.name} • ${playlist.subtype}',
              playlist.description,
              playlist.artworkUrl,
              playlist.color,
              playlist.tracks)),
    ].where((playlist) {
      final query = _input.text.trim().toLowerCase();
      return query.isNotEmpty &&
          '${playlist.title} ${playlist.subtitle}'
              .toLowerCase()
              .contains(query);
    }).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Search',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: _input,
                onChanged: _search,
                onSubmitted: _rememberSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Songs, artists, albums or movies',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: hasQuery
                      ? IconButton(
                          onPressed: () {
                            _input.clear();
                            _search('');
                          },
                          icon: const Icon(Icons.close_rounded))
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _SearchFilter.values.map((filter) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _filter == filter,
                        label: Text(filter.label),
                        avatar: Icon(filter.icon, size: 18),
                        onSelected: (_) {
                          setState(() => _filter = filter);
                          _search(_input.text);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (!hasQuery && _recentSearches.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Recent searches',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    TextButton(
                      onPressed: () async {
                        setState(() => _recentSearches = const []);
                        final preferences =
                            await SharedPreferences.getInstance();
                        await preferences.remove('recent_music_searches');
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _recentSearches
                      .map((value) => ActionChip(
                            avatar: const Icon(Icons.history_rounded, size: 17),
                            label: Text(value),
                            onPressed: () => _useRecentSearch(value),
                          ))
                      .toList(),
                ),
              ],
            ]),
          ),
        ),
        if (!hasQuery) ...[
          const SliverToBoxAdapter(
              child: SectionTitle(title: 'Browse your collection')),
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final album = controller.albums[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [
                        colorFromHex(album.color).withOpacity(.84),
                        const Color(0xff24242d)
                      ]),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        _input.text = album.title;
                        _search(album.title);
                        _rememberSearch(album.title);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (canLoadArtwork(album.artworkUrl))
                              CachedNetworkImage(
                                imageUrl: album.artworkUrl,
                                errorListener: (_) {},
                                fit: BoxFit.cover,
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: album.artworkUrl.isEmpty
                                      ? [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: .12),
                                        ]
                                      : [
                                          Colors.black.withValues(alpha: .08),
                                          Colors.black.withValues(alpha: .82),
                                        ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (album.artworkUrl.isEmpty)
                                    Icon(
                                      album.isMovie
                                          ? Icons.local_movies_rounded
                                          : Icons.album_rounded,
                                      color:
                                          Colors.white.withValues(alpha: .88),
                                    ),
                                  const Spacer(),
                                  Text(
                                    album.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    album.isMovie ? 'Movie world' : 'Album',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: controller.albums.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 1.55),
          ),
        ] else if (_filter == _SearchFilter.playlists &&
            playlistResults.isNotEmpty) ...[
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('${playlistResults.length} playlists',
                style: Theme.of(context).textTheme.labelLarge),
          )),
          SliverList.builder(
            itemCount: playlistResults.length,
            itemBuilder: (context, index) {
              final playlist = playlistResults[index];
              return ListTile(
                leading: Artwork(
                  color: playlist.color,
                  label: playlist.title,
                  imageUrl: playlist.artworkUrl,
                  size: 52,
                  icon: Icons.queue_music_rounded,
                ),
                title: Text(playlist.title),
                subtitle: Text(
                    '${playlist.subtitle} • ${playlist.tracks.length} songs'),
                trailing: const Icon(Icons.play_arrow_rounded),
                onTap: playlist.tracks.isEmpty
                    ? null
                    : () => controller.play(playlist.tracks.first,
                        sequence: playlist.tracks,
                        loopSequence: true,
                        sourceLabel:
                            '${playlist.subtitle} • ${playlist.title}'),
              );
            },
          ),
        ] else if ((_filter == _SearchFilter.playlists &&
                playlistResults.isEmpty) ||
            controller.searchResults.isEmpty) ...[
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches yet',
                body:
                    'Try a song title, artist, album, or a different spelling.'),
          ),
        ] else ...[
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(controller.searchResults.length.toString() + ' results',
                style: Theme.of(context).textTheme.labelLarge),
          )),
          SliverList.builder(
            itemCount: controller.searchResults.length,
            itemBuilder: (context, index) {
              final track = controller.searchResults[index];
              return TrackTile(
                  track: track,
                  onTap: () => controller.play(track),
                  onMore: () => showTrackActions(context, track));
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

enum _SearchFilter { all, songs, albums, artists, playlists, lyrics }

extension on _SearchFilter {
  String get label => switch (this) {
        _SearchFilter.all => 'All',
        _SearchFilter.songs => 'Songs',
        _SearchFilter.albums => 'Albums',
        _SearchFilter.artists => 'Artists',
        _SearchFilter.playlists => 'Playlists',
        _SearchFilter.lyrics => 'Lyrics',
      };

  IconData get icon => switch (this) {
        _SearchFilter.all => Icons.tune_rounded,
        _SearchFilter.songs => Icons.music_note_rounded,
        _SearchFilter.albums => Icons.album_rounded,
        _SearchFilter.artists => Icons.mic_rounded,
        _SearchFilter.playlists => Icons.queue_music_rounded,
        _SearchFilter.lyrics => Icons.lyrics_rounded,
      };
}

class _PlaylistSearchResult {
  const _PlaylistSearchResult(
      this.title, this.subtitle, this.artworkUrl, this.color, this.tracks);

  final String title;
  final String subtitle;
  final String artworkUrl;
  final String color;
  final List<Track> tracks;
}
