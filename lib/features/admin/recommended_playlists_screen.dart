import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../import/import_music_sheet.dart';
import '../shared/widgets.dart';

class RecommendedPlaylistsScreen extends StatefulWidget {
  const RecommendedPlaylistsScreen({super.key});
  @override
  State<RecommendedPlaylistsScreen> createState() =>
      _RecommendedPlaylistsScreenState();
}

class _RecommendedPlaylistsScreenState
    extends State<RecommendedPlaylistsScreen> {
  List<RecommendedPlaylist> items = const [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await context.read<MusicController>().getAdminRecommendedPlaylists();
    if (mounted)
      setState(() {
        items = result;
        loading = false;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recommended playlists')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Create')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                      'These playlists are curated by administrators and shown to every listener.'),
                  const SizedBox(height: 12),
                  ...items.map((item) => Card(
                          child: ListTile(
                        leading: Artwork(
                            color: item.color,
                            label: item.name,
                            imageUrl: item.artworkUrl,
                            size: 52),
                        title: Text(item.name),
                        subtitle: Text(
                            '${item.type} • ${item.subtype} • ${item.tracks.length} songs${item.active ? '' : ' • Hidden'}'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(item),
                      ))),
                ],
              ),
      );

  Future<void> _edit([RecommendedPlaylist? existing]) async {
    final music = context.read<MusicController>();
    final name = TextEditingController(text: existing?.name ?? '');
    final description =
        TextEditingController(text: existing?.description ?? '');
    var type = existing?.type ?? recommendedPlaylistSubtypes.keys.first;
    var subtype = existing?.subtype ?? recommendedPlaylistSubtypes[type]!.first;
    var active = existing?.active ?? true;
    var catalogQuery = '';
    final selected = <String>{
      if (existing != null) ...existing.tracks.map((track) => track.id),
    };
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (_, setDialogState) => AlertDialog(
                  title: Text(existing == null
                      ? 'Create recommendation'
                      : 'Edit recommendation'),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                            TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'Playlist name')),
                            TextField(
                                controller: description,
                                decoration: const InputDecoration(
                                    labelText: 'Details')),
                            DropdownButtonFormField<String>(
                                value: type,
                                decoration:
                                    const InputDecoration(labelText: 'Type'),
                                items: recommendedPlaylistSubtypes.keys
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setDialogState(() {
                                      type = v;
                                      subtype =
                                          recommendedPlaylistSubtypes[v]!.first;
                                    });
                                }),
                            DropdownButtonFormField<String>(
                                value: subtype,
                                decoration:
                                    const InputDecoration(labelText: 'Subtype'),
                                items: recommendedPlaylistSubtypes[type]!
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setDialogState(() => subtype = v);
                                }),
                            SwitchListTile(
                                value: active,
                                onChanged: (v) =>
                                    setDialogState(() => active = v),
                                title: const Text('Visible to listeners')),
                            const Divider(),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search catalog',
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText:
                                    'Song, singer, album, director or genre',
                              ),
                              onChanged: (value) => setDialogState(() =>
                                  catalogQuery = value.trim().toLowerCase()),
                            ),
                            Row(children: [
                              const Expanded(
                                  child: Text('Choose songs from catalog',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              TextButton.icon(
                                  onPressed: () =>
                                      showImportMusicSheet(context),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Add from device'))
                            ]),
                            ...music.allTracks.where((track) {
                              if (catalogQuery.isEmpty) return true;
                              return [
                                track.title,
                                track.artist,
                                track.album,
                                track.singers,
                                track.musicDirector,
                                track.genre,
                              ].join(' ').toLowerCase().contains(catalogQuery);
                            }).map((track) => CheckboxListTile(
                                dense: true,
                                value: selected.contains(track.id),
                                title: Text(track.title),
                                subtitle:
                                    Text('${track.artist} • ${track.album}'),
                                onChanged: (v) => setDialogState(() {
                                      if (v == true) {
                                        selected.add(track.id);
                                      } else {
                                        selected.remove(track.id);
                                      }
                                    }))),
                          ]))),
                  actions: [
                    if (existing != null)
                      TextButton(
                          onPressed: () async {
                            await music.deleteRecommendedPlaylist(existing.id);
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext, true);
                          },
                          child: const Text('Delete')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          if (name.text.trim().isEmpty) return;
                          await music.saveRecommendedPlaylist(
                              RecommendedPlaylist(
                                  id: existing?.id ?? '',
                                  name: name.text.trim(),
                                  description: description.text.trim(),
                                  type: type,
                                  subtype: subtype,
                                  color: existing?.color ?? '7C4DFF',
                                  artworkUrl: existing?.artworkUrl ?? '',
                                  tracks: music.allTracks
                                      .where((t) => selected.contains(t.id))
                                      .toList(),
                                  active: active));
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Save')),
                  ],
                )));
    name.dispose();
    description.dispose();
    if (saved == true) await _load();
  }
}
