import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';
import 'playlist_detail_screen.dart';

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
                  onPressed: () => _showInvitations(context),
                  tooltip: 'Playlist invitations',
                  icon: const Icon(Icons.notifications_outlined)),
              const SizedBox(width: 8),
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
                ...controller.ownedPlaylists.map((playlist) => CollectionCard(
                      title: playlist.name,
                      subtitle: playlist.tracks.length.toString() + ' songs',
                      color: playlist.color,
                      imageUrl: playlist.artworkUrl,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(
                                  playlistId: playlist.id))),
                    )),
              ],
            ),
          ),
        ),
        if (controller.collaborativePlaylists.isNotEmpty) ...[
          const SliverToBoxAdapter(
              child: SectionTitle(title: 'Collaborative playlists')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 206,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                children: controller.collaborativePlaylists
                    .map((playlist) => CollectionCard(
                          title: playlist.name,
                          subtitle:
                              '${playlist.tracks.length} songs • Shared with you',
                          color: playlist.color,
                          imageUrl: playlist.artworkUrl,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaylistDetailScreen(playlistId: playlist.id),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
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

  Future<void> _showInvitations(BuildContext context) async {
    final music = context.read<MusicController>();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Row(children: [
                Icon(Icons.notifications_active_outlined),
                SizedBox(width: 10),
                Text('Playlist invitations')
              ]),
              content: SizedBox(
                  width: 520,
                  child: FutureBuilder<List<PlaylistInvitation>>(
                    future: music.getPlaylistInvitations(),
                    builder: (_, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done)
                        return const Center(child: CircularProgressIndicator());
                      final invites =
                          snapshot.data ?? const <PlaylistInvitation>[];
                      if (invites.isEmpty)
                        return const Padding(
                            padding: EdgeInsets.all(24),
                            child:
                                Text('No pending collaboration invitations.'));
                      return ListView(
                        shrinkWrap: true,
                        children: invites
                            .map((invite) => _InvitationCard(
                                  invitation: invite,
                                  onReject: () async {
                                    await music.respondToPlaylistInvitation(
                                        invite.id, false);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                  onAccept: () async {
                                    await music.respondToPlaylistInvitation(
                                        invite.id, true);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                ))
                            .toList(),
                      );
                    },
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'))
              ],
            ));
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onReject,
    required this.onAccept,
  });

  final PlaylistInvitation invitation;
  final Future<void> Function() onReject;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(Icons.group_add_rounded)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invitation.playlistName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '${invitation.inviterName} invited you to collaborate.',
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
