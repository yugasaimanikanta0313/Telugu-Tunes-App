import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final playlist =
        music.playlists.where((item) => item.id == playlistId).firstOrNull;
    if (playlist == null) {
      return const Scaffold(
          body: Center(child: Text('Playlist is no longer available.')));
    }
    final isOwner = playlist.ownedByCurrentMember ??
        (playlist.ownerMemberId.isEmpty ||
            playlist.ownerMemberId == music.memberId);
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (isOwner)
            IconButton(
                onPressed: () => _invite(context, playlist),
                tooltip: 'Invite collaborator',
                icon: const Icon(Icons.person_add_alt_1_rounded)),
          if (isOwner)
            IconButton(
                onPressed: () => _edit(context, playlist),
                tooltip: 'Edit playlist',
                icon: const Icon(Icons.edit_outlined)),
          if (isOwner)
            IconButton(
                onPressed: () => _delete(context, playlist),
                tooltip: 'Delete playlist',
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 22,
              runSpacing: 16,
              children: [
                Artwork(
                    color: playlist.color,
                    label: playlist.name,
                    imageUrl: playlist.artworkUrl,
                    size: 190,
                    icon: Icons.queue_music_rounded),
                SizedBox(
                    width: 420,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(playlist.description.isEmpty
                              ? 'Created in Telugu Tunes'
                              : playlist.description),
                          const SizedBox(height: 12),
                          Text(
                              '${playlist.tracks.length} songs • ${playlist.sharedWithMemberIds.length} collaborators'),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                              onPressed: playlist.tracks.isEmpty
                                  ? null
                                  : () {
                                      music.play(playlist.tracks.first);
                                    },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play playlist')),
                        ])),
              ]),
        )),
        if (playlist.tracks.isEmpty)
          const SliverFillRemaining(
              child: EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: 'This playlist is empty',
                  body: 'Add songs from the catalog or song menu.'))
        else
          SliverList.builder(
              itemCount: playlist.tracks.length,
              itemBuilder: (_, index) {
                final track = playlist.tracks[index];
                return TrackTile(
                    track: track,
                    index: index + 1,
                    subtitle:
                        'Added by ${playlist.trackAddedByNames[track.id] ?? 'Playlist owner'} • ${track.artist} • ${track.album}',
                    onTap: () => music.play(track),
                    onMore: () => showTrackActions(context, track));
              }),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ]),
    );
  }

  Future<void> _invite(BuildContext context, Playlist playlist) async {
    final input = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Invite a collaborator'),
              content: SizedBox(
                  width: 420,
                  child: TextField(
                      controller: input,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Telugu Tunes account email',
                          helperText:
                              'They can accept or reject this invitation from notifications.'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton.icon(
                    onPressed: () async {
                      try {
                        await context
                            .read<MusicController>()
                            .invitePlaylistCollaborator(
                                playlist.id, input.text.trim());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Collaboration invitation sent.')));
                      } catch (error) {
                        if (dialogContext.mounted)
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                  content: Text(error
                                      .toString()
                                      .replaceFirst('Bad state: ', ''))));
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send invite')),
              ],
            ));
    input.dispose();
  }

  Future<void> _edit(BuildContext context, Playlist playlist) async {
    final name = TextEditingController(text: playlist.name);
    final description = TextEditingController(text: playlist.description);
    final artwork = TextEditingController(text: playlist.artworkUrl);
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Edit playlist'),
              content: SizedBox(
                  width: 480,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: description,
                        decoration:
                            const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: artwork,
                        decoration: const InputDecoration(
                            labelText: 'Square artwork URL')),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      await context.read<MusicController>().updatePlaylist(
                          Playlist(
                              id: playlist.id,
                              name: name.text.trim(),
                              description: description.text.trim(),
                              color: playlist.color,
                              artworkUrl: artwork.text.trim(),
                              tracks: playlist.tracks,
                              isPinned: playlist.isPinned,
                              ownerMemberId: playlist.ownerMemberId,
                              sharedWithMemberIds: playlist.sharedWithMemberIds,
                              trackAddedByNames: playlist.trackAddedByNames));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Save')),
              ],
            ));
    name.dispose();
    description.dispose();
    artwork.dispose();
  }

  Future<void> _delete(BuildContext context, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete playlist?'),
            content: Text(
                'Delete “${playlist.name}”? Songs will remain in the catalog, but this playlist and its collaboration access will be removed.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<MusicController>().deletePlaylist(playlist.id);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
  }
}
