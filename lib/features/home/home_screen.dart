import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../../domain/models/music_models.dart';
import '../album/album_detail_screen.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';
import 'recommended_playlist_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DashboardRecommendedGroup {
  _DashboardRecommendedGroup(this.variants) : assert(variants.isNotEmpty);

  final List<RecommendedPlaylist> variants;
  RecommendedPlaylist get first => variants.first;
  String get name => first.name;
  String get type => first.type;
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final recommended = _allGroups(controller.recommendedPlaylists);
    if (controller.loading)
      return const Center(child: CircularProgressIndicator());
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 42, 20, 14),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        'Namasthe!, ${controller.memberName}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text('Your private Telugu music space',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                if (controller.isAdmin)
                  IconButton.filledTonal(
                      onPressed: () => showImportMusicSheet(context),
                      tooltip: 'Add music',
                      icon: const Icon(Icons.add_rounded)),
              ],
            ),
          ),
        ),
        if (recommended.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommended playlists',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      const Text(
                          'Open one playlist to explore its weekly subtypes.'),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Customize my calendar',
                  icon: const Icon(Icons.edit_calendar_rounded),
                  onPressed: () => showRecommendationCalendar(
                      context, controller.recommendedPlaylists),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 204,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _playlistFamilyCard(context, recommended[index]),
              ),
            ),
          ),
        ],
        if (controller.festivalGreeting case final festival?)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(colors: [
                    colorFromHex(festival.color),
                    colorFromHex(festival.color).withValues(alpha: .55),
                  ]),
                ),
                child: Row(children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.celebration_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(festival.festival,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(festival.greeting,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        if (controller.festivalRecommendation case final festivalRec?
            when festivalRec.playlists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Festival picks • ${festivalRec.festival.festival}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                const Pill(label: 'System calendar', icon: Icons.lock_rounded),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 124,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: festivalRec.playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final playlist = festivalRec.playlists[index];
                  return SizedBox(
                    width: 300,
                    child: Card(
                      child: ListTile(
                        leading: Artwork(
                          color: playlist.color,
                          label: playlist.subtype,
                          imageUrl: playlist.artworkUrl,
                          size: 54,
                        ),
                        title: Text(playlist.subtype,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                            '${playlist.name} • ${playlist.tracks.length} songs'),
                        trailing: const Icon(Icons.play_circle_outline_rounded),
                        onTap: () => _showRecommended(context, playlist),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: controller.isAuthenticated
                  ? () => _showAssistant(context)
                  : null,
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    const Color(0xff293b65)
                  ]),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Tune AI',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 3),
                          Text('Ask for a mood, a mix, or an offline plan.'),
                        ])),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (controller.loadError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_rounded),
                  title: const Text('Backend is unavailable'),
                  subtitle: Text(controller.loadError!),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    onPressed: controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(
            child: SectionTitle(title: 'Recently played', action: 'See all')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 199,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20),
              scrollDirection: Axis.horizontal,
              itemCount: controller.recentlyPlayed.length,
              itemBuilder: (context, index) {
                final track = controller.recentlyPlayed[index];
                return CollectionCard(
                  title: track.title,
                  subtitle: track.artist,
                  color: track.color,
                  imageUrl: track.artworkUrl,
                  onTap: () => controller.play(track),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
            child: SectionTitle(title: 'Albums & movie worlds')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 202,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20),
              scrollDirection: Axis.horizontal,
              itemCount: controller.albums.length,
              itemBuilder: (context, index) {
                final album = controller.albums[index];
                return CollectionCard(
                  title: album.title,
                  subtitle: album.isMovie
                      ? 'Movie • ' + album.year.toString()
                      : album.artist,
                  color: album.color,
                  imageUrl: album.artworkUrl,
                  movie: album.isMovie,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(album: album))),
                );
              },
            ),
          ),
        ),
        if (controller.allTracks.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.library_music_outlined,
              title: controller.isAdmin
                  ? 'Your music space is ready'
                  : 'No songs are available yet',
              body: controller.isAdmin
                  ? 'Add an audio file or a music link to begin building your private library.'
                  : 'An administrator can add songs to the shared catalog.',
              action: controller.isAdmin ? 'Add music' : null,
              onAction: controller.isAdmin
                  ? () => showImportMusicSheet(context)
                  : null,
            ),
          ),
        ...controller.collections
            .where((collection) => collection.tracks.isNotEmpty)
            .expand((collection) => [
                  SliverToBoxAdapter(
                      child: SectionTitle(
                          title: collection.title,
                          action: 'Play all',
                          onAction: () =>
                              controller.play(collection.tracks.first))),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 126,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(left: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: collection.tracks.length,
                        itemBuilder: (context, index) {
                          final track = collection.tracks[index];
                          return SizedBox(
                            width: 220,
                            child: Card(
                              margin: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => controller.play(track),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(children: [
                                    Artwork(
                                        color: track.color,
                                        label: track.album,
                                        imageUrl: track.artworkUrl,
                                        size: 58),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 3),
                                          Text(track.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                          if (controller
                                              .isDownloaded(track)) ...[
                                            const SizedBox(height: 6),
                                            const Pill(
                                                label: 'Offline',
                                                icon:
                                                    Icons.download_done_rounded)
                                          ],
                                        ])),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<_DashboardRecommendedGroup> _allGroups(
      List<RecommendedPlaylist> source) {
    final groups = <String, List<RecommendedPlaylist>>{};
    for (final item in source) {
      final key =
          '${item.name.trim().toLowerCase()}|${item.type.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups.values.map(_DashboardRecommendedGroup.new).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Widget _playlistFamilyCard(
      BuildContext context, _DashboardRecommendedGroup group) {
    final colors = Theme.of(context).colorScheme;
    final subtypes =
        group.variants.map((item) => item.subtype).take(3).toList();
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecommendedPlaylistScheduleScreen(
                name: group.name,
                type: group.type,
                variants: group.variants,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Artwork(
                  color: group.first.color,
                  label: group.name,
                  imageUrl: group.first.artworkUrl,
                  size: 64,
                ),
                const Spacer(),
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ]),
              const Spacer(),
              Text(group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${group.type} • ${group.variants.length} subtypes',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: subtypes
                    .map((name) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(name,
                              style: Theme.of(context).textTheme.labelSmall),
                        ))
                    .toList(),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showRecommended(BuildContext context, RecommendedPlaylist playlist) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Artwork(
                color: playlist.color,
                label: playlist.name,
                imageUrl: playlist.artworkUrl,
                size: 54),
            title: Text(playlist.name,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
                '${playlist.type} • ${playlist.subtype}\n${playlist.scheduleLabel}\n${playlist.description}'),
            isThreeLine: true,
          ),
          ...playlist.tracks.map((track) => TrackTile(
                track: track,
                onTap: () {
                  context.read<MusicController>().play(track);
                  Navigator.pop(sheetContext);
                },
                onMore: () => showTrackActions(context, track),
              )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _showAssistant(BuildContext context) async {
    final input = TextEditingController(text: 'Make me a mellow evening mix');
    final controller = context.read<MusicController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tune AI',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(controller.remoteMode
                  ? 'Prompts are sent only to your private backend.'
                  : 'Connect the private backend to enable Gemini suggestions.'),
              const SizedBox(height: 14),
              TextField(
                  controller: input,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.auto_awesome_rounded),
                      hintText: 'What should we play?')),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await controller.askAssistant(input.text);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) _showAssistantReply(context);
                      } catch (error) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                                content: Text(error
                                    .toString()
                                    .replaceFirst('Bad state: ', ''))),
                          );
                        }
                      }
                    },
                    child: const Text('Get a suggestion'),
                  )),
            ]),
      ),
    );
  }

  void _showAssistantReply(BuildContext context) {
    final reply = context.read<MusicController>().assistantReply;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded),
        title: const Text('Tune AI suggestion'),
        content: Text(reply),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'))
        ],
      ),
    );
  }
}
