import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../shared/widgets.dart';
import 'playlist_detail_screen.dart';

class CollaborativePlaylistsScreen extends StatefulWidget {
  const CollaborativePlaylistsScreen({super.key});

  @override
  State<CollaborativePlaylistsScreen> createState() =>
      _CollaborativePlaylistsScreenState();
}

class _CollaborativePlaylistsScreenState
    extends State<CollaborativePlaylistsScreen> {
  Future<void> _loading = Future<void>.value();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loading = context.read<MusicController>().refreshPlaylists();
  }

  Future<void> _refresh() async {
    final request = context.read<MusicController>().refreshPlaylists();
    setState(() => _loading = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaborated playlists'),
        actions: [
          IconButton(
            tooltip: 'Refresh shared playlists',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              music.collaborativePlaylists.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && music.collaborativePlaylists.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load collaborated playlists',
              body: snapshot.error.toString(),
              action: 'Try again',
              onAction: _refresh,
            );
          }
          if (music.collaborativePlaylists.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              title: 'No collaborated playlists yet',
              body: 'Accept a playlist invitation and it will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: music.collaborativePlaylists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final playlist = music.collaborativePlaylists[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: SizedBox(
                      width: 64,
                      height: 64,
                      child: Artwork(
                        imageUrl: playlist.artworkUrl,
                        color: playlist.color,
                        label: playlist.name,
                        size: 64,
                        icon: Icons.group_rounded,
                      ),
                    ),
                    title: Text(playlist.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        '${playlist.tracks.length} songs • Shared with you'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaylistDetailScreen(playlistId: playlist.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
