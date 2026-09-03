import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final matchingAlbums = context
        .watch<MusicController>()
        .albums
        .where((item) => item.id == this.album.id);
    final album = matchingAlbums.isEmpty ? this.album : matchingAlbums.first;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorFromHex(album.color).withOpacity(.88),
                      const Color(0xff101014)
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Artwork(
                        color: album.color,
                        label: album.title,
                        imageUrl: album.artworkUrl,
                        size: 148,
                        icon: album.isMovie
                            ? Icons.local_movies_rounded
                            : Icons.album_rounded,
                        heroTag: 'album-' + album.id,
                      ),
                    ),
                    const Spacer(),
                    Text(album.isMovie ? 'MOVIE SOUNDTRACK' : 'ALBUM',
                        style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(album.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      album.artist +
                          ' • ' +
                          album.year.toString() +
                          ' • ' +
                          album.tracks.length.toString() +
                          ' songs',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Text(album.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: album.tracks.isEmpty
                              ? null
                              : () => context.read<MusicController>().play(
                                  album.tracks.first,
                                  sequence: album.tracks),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (context.read<MusicController>().isAdmin)
                        IconButton.filledTonal(
                          onPressed: () =>
                              showImportMusicSheet(context, album: album),
                          tooltip: 'Add songs',
                          icon: const Icon(Icons.library_add_rounded),
                        ),
                      IconButton.filledTonal(
                          onPressed: () =>
                              context.read<MusicController>().toggleShuffle(),
                          tooltip: 'Shuffle',
                          icon: const Icon(Icons.shuffle_rounded)),
                      IconButton.filledTonal(
                          onPressed: () => _showAlbumActions(context, album),
                          tooltip: 'More',
                          icon: const Icon(Icons.more_horiz_rounded)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: album.tracks.length,
            itemBuilder: (context, index) {
              final track = album.tracks[index];
              return TrackTile(
                  track: track,
                  index: index + 1,
                  onTap: () => context
                      .read<MusicController>()
                      .play(track, sequence: album.tracks),
                  onMore: () => showTrackActions(context, track));
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  void _showAlbumActions(BuildContext context, Album album) {
    final controller = context.read<MusicController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_for_offline_rounded),
              title: const Text('Download album for offline'),
              subtitle: Text('${album.tracks.length} songs'),
              onTap: album.tracks.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(sheetContext);
                      try {
                        for (final track in album.tracks) {
                          if (!controller.isDownloaded(track)) {
                            await controller.toggleDownload(track);
                          }
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '${album.title} is ready for offline playback.')));
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(error
                                  .toString()
                                  .replaceFirst('Unsupported operation: ', '')
                                  .replaceFirst('Bad state: ', ''))));
                        }
                      }
                    },
            ),
            if (controller.isAdmin) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.library_add_rounded),
                title: const Text('Add songs to this album'),
                subtitle: const Text('Upload one or several audio files'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showImportMusicSheet(context, album: album);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit album details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editAlbum(context, album);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Remove album grouping',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle:
                    const Text('Keeps the uploaded songs in Unsorted music'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmRemoveAlbum(context, album);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editAlbum(BuildContext context, Album album) async {
    final music = context.read<MusicController>();
    final title = TextEditingController(text: album.title);
    final artist = TextEditingController(text: album.artist);
    final description = TextEditingController(text: album.description);
    final year = TextEditingController(text: album.year.toString());
    final color = TextEditingController(text: album.color);
    final artworkUrl = TextEditingController(text: album.artworkUrl);
    var movie = album.isMovie;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Edit album'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(
                    controller: artist,
                    decoration:
                        const InputDecoration(labelText: 'Album artist')),
                const SizedBox(height: 10),
                TextField(
                    controller: year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year')),
                const SizedBox(height: 10),
                TextField(
                    controller: color,
                    decoration: const InputDecoration(
                        labelText: 'Artwork color (hex)')),
                const SizedBox(height: 10),
                Artwork(
                  color: album.color,
                  label: title.text.trim().isEmpty ? album.title : title.text,
                  imageUrl: artworkUrl.text.trim(),
                  size: 132,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: artworkUrl,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Album artwork URL (optional)',
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
                        final query = [title.text, artist.text]
                            .where((value) => value.trim().isNotEmpty)
                            .join(' ');
                        final result = await music.suggestMetadata(query);
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
                        if (!dialogContext.mounted || selected == null) return;
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
                    label: const Text('Find album cover'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: movie,
                  onChanged: (value) => setDialogState(() => movie = value),
                  title: const Text('Movie soundtrack'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final parsedYear = int.tryParse(year.text.trim()) ?? album.year;
                try {
                  await music.updateAlbum(Album(
                    id: album.id,
                    title: title.text.trim(),
                    artist: artist.text.trim(),
                    description: description.text.trim(),
                    year: parsedYear,
                    color: color.text.trim(),
                    artworkUrl: artworkUrl.text.trim(),
                    tracks: album.tracks,
                    isMovie: movie,
                  ));
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Album updated.')));
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text(
                          error.toString().replaceFirst('Bad state: ', ''))));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    artist.dispose();
    description.dispose();
    year.dispose();
    color.dispose();
    artworkUrl.dispose();
  }

  Future<void> _confirmRemoveAlbum(BuildContext context, Album album) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove album grouping?'),
        content: Text(
            '“${album.title}” will be removed as an album. Its ${album.tracks.length} uploaded songs stay safely in Unsorted music.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove album'),
          ),
        ],
      ),
    );
    if (remove != true || !context.mounted) return;
    try {
      await context.read<MusicController>().deleteAlbum(album);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Album grouping removed. Songs were kept.')));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }
}
