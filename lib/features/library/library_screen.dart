import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Row(children: [
              Expanded(
                  child: Text('Your library',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900))),
              IconButton.filledTonal(
                  onPressed: () => showImportMusicSheet(context),
                  tooltip: 'Add music',
                  icon: const Icon(Icons.add_rounded)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Pill(
                  label: controller.favoriteTracks.length.toString() +
                      ' favorites',
                  icon: Icons.favorite_rounded,
                  color: Colors.pinkAccent),
              const SizedBox(width: 8),
              Pill(
                  label: controller.downloaded.length.toString() + ' offline',
                  icon: Icons.download_done_rounded),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SectionTitle(title: 'Your playlists')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 206,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              children: [
                SizedBox(
                  width: 126,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => showCreatePlaylistDialog(context),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.add_rounded, size: 32),
                          ),
                          const SizedBox(height: 8),
                          const Text('New playlist',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                  ),
                ),
                ...controller.playlists.map((playlist) => CollectionCard(
                      title: playlist.name,
                      subtitle: playlist.tracks.length.toString() + ' songs',
                      color: playlist.color,
                      imageUrl: playlist.artworkUrl,
                      onTap: () => _showPlaylist(context, playlist),
                    )),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
            child: SectionTitle(title: 'Favorites', action: 'Play all')),
        if (controller.favoriteTracks.isEmpty)
          const SliverToBoxAdapter(
              child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorites yet',
                  body: 'Tap the heart on a song to keep it close.'))
        else
          SliverList.builder(
            itemCount: controller.favoriteTracks.length,
            itemBuilder: (context, index) {
              final track = controller.favoriteTracks[index];
              return TrackTile(
                  track: track,
                  onTap: () => controller.play(track),
                  onMore: () => showTrackActions(context, track));
            },
          ),
        const SliverToBoxAdapter(
            child: SectionTitle(title: 'Offline downloads')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.storage_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Private cache',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            controller.downloaded.length.toString() +
                                ' tracks stored privately on this device',
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                  const Icon(Icons.offline_pin_rounded),
                ]),
              ),
            ),
          ),
        ),
        if (controller.downloadedTracks.isNotEmpty)
          SliverList.builder(
            itemCount: controller.downloadedTracks.length,
            itemBuilder: (context, index) {
              final track = controller.downloadedTracks[index];
              return TrackTile(
                track: track,
                onTap: () => controller.play(track),
                onMore: () => showTrackActions(context, track),
              );
            },
          ),
        if (controller.imports.isNotEmpty) ...[
          const SliverToBoxAdapter(
              child: SectionTitle(title: 'Recent import requests')),
          SliverList.builder(
            itemCount: controller.imports.length,
            itemBuilder: (context, index) {
              final receipt = controller.imports[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Awaiting backend import'),
                subtitle: Text(receipt.message,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  void _showPlaylist(BuildContext context, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Artwork(
                  color: playlist.color,
                  label: playlist.name,
                  imageUrl: playlist.artworkUrl,
                  size: 52,
                  icon: Icons.queue_music_rounded),
              title: Text(playlist.name,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(playlist.description),
              trailing: IconButton(
                tooltip: 'Edit playlist',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _editPlaylist(context, playlist);
                },
              ),
            ),
            ...playlist.tracks.map<Widget>((track) => TrackTile(
                track: track,
                onTap: () {
                  context.read<MusicController>().play(track);
                  Navigator.pop(sheetContext);
                },
                onMore: () => showTrackActions(context, track))),
          ]),
        ),
      ),
    );
  }

  Future<void> _editPlaylist(BuildContext context, Playlist playlist) async {
    final music = context.read<MusicController>();
    final name = TextEditingController(text: playlist.name);
    final description = TextEditingController(text: playlist.description);
    final artworkUrl = TextEditingController(text: playlist.artworkUrl);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Edit playlist'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Artwork(
                    color: playlist.color,
                    label: name.text.trim().isEmpty
                        ? playlist.name
                        : name.text.trim(),
                    imageUrl: artworkUrl.text.trim(),
                    size: 132,
                    icon: Icons.queue_music_rounded,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: artworkUrl,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Playlist artwork URL (optional)',
                      helperText:
                          'Leave empty to use the first song cover automatically.',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final queryParts = <String>[name.text];
                          if (playlist.tracks.isNotEmpty) {
                            queryParts.add(playlist.tracks.first.title);
                            queryParts.add(playlist.tracks.first.artist);
                          }
                          final result = await music.suggestMetadata(
                            queryParts
                                .where((value) => value.trim().isNotEmpty)
                                .join(' '),
                          );
                          if (!dialogContext.mounted) return;
                          if (result.artworkCandidates.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text('No matching cover found.')),
                            );
                            return;
                          }
                          final selected = await showArtworkPicker(
                            dialogContext,
                            result.artworkCandidates,
                          );
                          if (!dialogContext.mounted || selected == null) {
                            return;
                          }
                          artworkUrl.text = selected.imageUrl;
                          setDialogState(() {});
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(error
                                    .toString()
                                    .replaceFirst('Bad state: ', '')),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.image_search_rounded),
                      label: const Text('Find playlist cover'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                try {
                  await music.updatePlaylist(Playlist(
                    id: playlist.id,
                    name: name.text.trim(),
                    description: description.text.trim(),
                    color: playlist.color,
                    artworkUrl: artworkUrl.text.trim(),
                    tracks: playlist.tracks,
                    isPinned: playlist.isPinned,
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                            error.toString().replaceFirst('Bad state: ', '')),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    artworkUrl.dispose();
  }
}
