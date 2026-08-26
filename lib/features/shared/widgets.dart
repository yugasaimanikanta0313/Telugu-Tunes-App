import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';

const _maximumStoredAudioBytes = 5000000;

Color colorFromHex(String value) {
  final clean = value.replaceFirst('#', '');
  return Color(int.parse('FF' + clean, radix: 16));
}

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.color,
    required this.label,
    this.size = 64,
    this.icon = Icons.music_note_rounded,
    this.heroTag,
    this.imageUrl = '',
  });

  final String color;
  final String label;
  final double size;
  final IconData icon;
  final String? heroTag;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final artwork = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorFromHex(color).withOpacity(.95),
            const Color(0xff171721)
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: colorFromHex(color).withOpacity(.24),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: SizedBox(width: size, height: size, child: _content()),
    );
    return heroTag == null ? artwork : Hero(tag: heroTag!, child: artwork);
  }

  Widget _content() {
    final placeholder = Stack(
      children: [
        Positioned(
          top: size * .14,
          right: size * .13,
          child: Icon(icon,
              size: size * .30, color: Colors.white.withOpacity(.86)),
        ),
        Positioned(
          left: size * .12,
          right: size * .12,
          bottom: size * .12,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              height: 1,
              fontSize: size * .15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
    if (imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .18),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.onMore,
    this.showAlbum = true,
  });

  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: index == null
          ? Artwork(
              color: track.color,
              label: track.album,
              imageUrl: track.artworkUrl,
              size: 52,
            )
          : SizedBox(
              width: 52,
              child: Center(
                child: Text(index.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ),
            ),
      title: Text(track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          showAlbum ? track.artist + ' • ' + track.album : track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.isDownloaded(track))
            Icon(Icons.download_done_rounded,
                color: Theme.of(context).colorScheme.primary, size: 19),
          IconButton(
            tooltip: controller.isFavorite(track)
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: () => controller.toggleFavorite(track),
            icon: Icon(
                controller.isFavorite(track)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: controller.isFavorite(track) ? Colors.pinkAccent : null),
          ),
          IconButton(
            onPressed: onMore,
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap,
      this.movie = false});

  final String title;
  final String subtitle;
  final String color;
  final VoidCallback onTap;
  final bool movie;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 154,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Artwork(
                    color: color,
                    label: title,
                    size: 142,
                    icon: movie
                        ? Icons.local_movies_rounded
                        : Icons.album_rounded),
                const SizedBox(height: 10),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color:
              (color ?? Theme.of(context).colorScheme.primary).withOpacity(.14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: color ?? Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5)
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color ?? Theme.of(context).colorScheme.primary)),
          ],
        ),
      );
}

Future<void> showTrackActions(BuildContext context, Track track) async {
  final controller = context.read<MusicController>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Play now'),
                  onTap: () {
                    controller.play(track);
                    Navigator.pop(sheetContext);
                  }),
              ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Add to a playlist'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showAddToPlaylistSheet(context, track);
                  }),
              ListTile(
                leading: Icon(controller.isDownloaded(track)
                    ? Icons.delete_outline_rounded
                    : Icons.download_for_offline_rounded),
                title: Text(controller.isDownloaded(track)
                    ? 'Remove download'
                    : 'Download for offline'),
                subtitle: controller.isDownloading(track)
                    ? Text(
                        '${((controller.downloadProgress[track.id] ?? 0) * 100).round()}% downloaded')
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await controller.toggleDownload(track);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(controller.isDownloaded(track)
                            ? '${track.title} is ready offline.'
                            : 'Offline copy removed.'),
                      ));
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(error
                            .toString()
                            .replaceFirst('Unsupported operation: ', '')
                            .replaceFirst('Bad state: ', '')),
                      ));
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: const Text('Add to room queue'),
                onTap: () {
                  final hasRoom = controller.room != null;
                  if (hasRoom) controller.addToRoomQueue(track);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        hasRoom
                            ? 'Added to the shared room queue.'
                            : 'Create or join a room first.',
                      ),
                    ),
                  );
                },
              ),
              if (controller.isAdmin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit song details'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showEditTrackDialog(context, track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.audio_file_rounded),
                  title: const Text('Replace audio file'),
                  subtitle: const Text('Keeps this song’s details and album'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _replaceTrackAudio(context, track);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Delete from private library',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  subtitle: const Text(
                      'Removes the uploaded audio and its library entry'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDeleteTrack(context, track);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _replaceTrackAudio(BuildContext context, Track track) async {
  try {
    final result =
        await FilePicker.pickFiles(type: FileType.audio, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      throw StateError(
          'The selected file could not be read. Please try again.');
    }
    if (!context.mounted) return;
    final originalSize = file.bytes!.length;
    final needsCompression = originalSize > _maximumStoredAudioBytes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace audio file?'),
        content: Text(
          needsCompression
              ? '“${file.name}” is ${_megabytes(originalSize)}, which exceeds 5 MB. It will be converted to M4A and stored below 5 MB. Replace “${track.title}” with the compressed file?'
              : '“${track.title}” will keep its details, but play the new file “${file.name}”. The old private file will be removed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child:
                  Text(needsCompression ? 'Compress and replace' : 'Replace')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final replacement = await context
        .read<MusicController>()
        .replaceTrackAudio(track, file.name, file.bytes!);
    if (context.mounted) {
      final sizeMessage = replacement.compressed
          ? ' ${_megabytes(replacement.originalBytes)} → ${_megabytes(replacement.storedBytes)}.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Audio replaced for “${track.title}”.$sizeMessage')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

String _megabytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(2)} MB';

Future<void> showAddToPlaylistSheet(BuildContext context, Track track) async {
  final controller = context.read<MusicController>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
              title: Text('Add to playlist',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          ...controller.playlists.map((playlist) => ListTile(
                leading: Artwork(
                    color: playlist.color,
                    label: playlist.name,
                    size: 42,
                    icon: Icons.queue_music_rounded),
                title: Text(playlist.name),
                subtitle: Text(playlist.tracks.length.toString() + ' songs'),
                onTap: () async {
                  try {
                    await controller.addToPlaylist(playlist.id, track);
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to ' + playlist.name)));
                  } catch (error) {
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                          content: Text(error
                              .toString()
                              .replaceFirst('Bad state: ', ''))),
                    );
                  }
                },
              )),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Create a playlist'),
            onTap: () {
              Navigator.pop(sheetContext);
              showCreatePlaylistDialog(context, initialTrack: track);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmDeleteTrack(BuildContext context, Track track) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this track?'),
      content: Text(
        '“${track.title}” will be removed from the library and private Drive storage. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<MusicController>().deleteTrack(track);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Track deleted.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

Future<void> showEditTrackDialog(BuildContext context, Track track) async {
  final title = TextEditingController(text: track.title);
  final artist = TextEditingController(text: track.artist);
  final album = TextEditingController(text: track.album);
  final singers = TextEditingController(text: track.singers);
  final director = TextEditingController(text: track.musicDirector);
  final genre = TextEditingController(text: track.genre);
  final color = TextEditingController(text: track.color);
  final artworkUrl = TextEditingController(text: track.artworkUrl);
  final sourceUrl = TextEditingController(text: track.sourceUrl);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit song details'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Song title')),
              const SizedBox(height: 10),
              TextField(
                  controller: artist,
                  decoration:
                      const InputDecoration(labelText: 'Primary artist')),
              const SizedBox(height: 10),
              TextField(
                  controller: album,
                  decoration:
                      const InputDecoration(labelText: 'Album / movie')),
              const SizedBox(height: 10),
              TextField(
                  controller: singers,
                  decoration: const InputDecoration(labelText: 'Singer(s)')),
              const SizedBox(height: 10),
              TextField(
                  controller: director,
                  decoration:
                      const InputDecoration(labelText: 'Music director')),
              const SizedBox(height: 10),
              TextField(
                  controller: genre,
                  decoration: const InputDecoration(labelText: 'Genre')),
              const SizedBox(height: 10),
              TextField(
                  controller: color,
                  decoration:
                      const InputDecoration(labelText: 'Artwork color (hex)')),
              const SizedBox(height: 10),
              TextField(
                  controller: artworkUrl,
                  keyboardType: TextInputType.url,
                  decoration:
                      const InputDecoration(labelText: 'Thumbnail URL')),
              const SizedBox(height: 10),
              TextField(
                  controller: sourceUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Source URL')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            try {
              await context.read<MusicController>().updateTrack(Track(
                    id: track.id,
                    title: title.text.trim(),
                    artist: artist.text.trim(),
                    album: album.text.trim(),
                    albumId: track.albumId,
                    duration: track.duration,
                    color: color.text.trim(),
                    singers: singers.text.trim(),
                    musicDirector: director.text.trim(),
                    genre: genre.text.trim(),
                    artworkUrl: artworkUrl.text.trim(),
                    sourceUrl: sourceUrl.text.trim(),
                    downloaded: track.downloaded,
                    isExplicit: track.isExplicit,
                  ));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Song updated.')));
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                    content: Text(
                        error.toString().replaceFirst('Bad state: ', ''))));
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  title.dispose();
  artist.dispose();
  album.dispose();
  singers.dispose();
  director.dispose();
  genre.dispose();
  color.dispose();
  artworkUrl.dispose();
  sourceUrl.dispose();
}

Future<void> showCreatePlaylistDialog(BuildContext context,
    {Track? initialTrack}) async {
  final input = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Morning energy')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = input.text.trim();
            if (name.isEmpty) return;
            final controller = context.read<MusicController>();
            try {
              final playlist = await controller.createPlaylist(name);
              if (initialTrack != null) {
                await controller.addToPlaylist(playlist.id, initialTrack);
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Created ' + playlist.name)),
              );
            } catch (error) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                    content:
                        Text(error.toString().replaceFirst('Bad state: ', ''))),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.body,
      this.action,
      this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (action != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(action!))
              ],
            ],
          ),
        ),
      );
}
