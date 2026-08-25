import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search(String query) {
    context.read<MusicController>().search(query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final hasQuery = _input.text.trim().isNotEmpty;
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
            ]),
          ),
        ),
        if (!hasQuery) ...[
          const SliverToBoxAdapter(
              child: SectionTitle(title: 'Start with a feeling')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MoodChip(
                      label: 'Calm',
                      icon: Icons.nightlight_round,
                      color: '7C4DFF',
                      onTap: () {
                        _input.text = 'vennela';
                        _search(_input.text);
                      }),
                  _MoodChip(
                      label: 'Road trip',
                      icon: Icons.directions_car_filled_rounded,
                      color: 'FF7043',
                      onTap: () {
                        _input.text = 'prayanam';
                        _search(_input.text);
                      }),
                  _MoodChip(
                      label: 'Rainy day',
                      icon: Icons.cloud_rounded,
                      color: '00A896',
                      onTap: () {
                        _input.text = 'mabbullo';
                        _search(_input.text);
                      }),
                  _MoodChip(
                      label: 'Movie night',
                      icon: Icons.local_movies_rounded,
                      color: 'EC407A',
                      onTap: () {
                        _input.text = 'godari';
                        _search(_input.text);
                      }),
                ],
              ),
            ),
          ),
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
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                  album.isMovie
                                      ? Icons.local_movies_rounded
                                      : Icons.album_rounded,
                                  color: Colors.white.withOpacity(.88)),
                              const Spacer(),
                              Text(album.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              Text(album.isMovie ? 'Movie world' : 'Album',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ]),
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
        ] else if (controller.searchResults.isEmpty) ...[
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

class _MoodChip extends StatelessWidget {
  const _MoodChip(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  final String label;
  final IconData icon;
  final String color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: colorFromHex(color)),
        label: Text(label),
        onPressed: onTap,
        side: BorderSide.none,
        backgroundColor: colorFromHex(color).withOpacity(.15),
      );
}
