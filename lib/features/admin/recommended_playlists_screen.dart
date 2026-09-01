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
  String? loadError;
  String playlistQuery = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        loadError = null;
      });
    try {
      final result =
          await context.read<MusicController>().getAdminRecommendedPlaylists();
      if (!mounted) return;
      setState(() {
        items = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    return Scaffold(
      appBar: AppBar(title: const Text('Recommended playlists')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Create')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_rounded, size: 48),
                      const SizedBox(height: 12),
                      const Text('Recommended playlists could not be loaded.'),
                      const SizedBox(height: 8),
                      Text(loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                        'These playlists are curated by administrators and shown to every listener.'),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search existing playlists',
                        hintText: 'Name, type or subtype',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(
                          () => playlistQuery = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    ...groups.map((group) => Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: Artwork(
                                color: group.first.color,
                                label: group.name,
                                imageUrl: group.first.artworkUrl,
                                size: 52),
                            title: Text(group.name),
                            subtitle: Text(
                                '${group.type} • ${group.variants.length} subtype${group.variants.length == 1 ? '' : 's'}'),
                            children: [
                              ...group.variants.map((item) => ExpansionTile(
                                    tilePadding: const EdgeInsets.only(
                                        left: 28, right: 8),
                                    childrenPadding: const EdgeInsets.only(
                                        left: 54, right: 16, bottom: 8),
                                    leading:
                                        const Icon(Icons.queue_music_rounded),
                                    title: Text(item.subtype),
                                    subtitle: Text(
                                        '${item.tracks.length} songs${item.active ? '' : ' • Hidden'}\n${item.scheduleLabel}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit ${item.subtype}',
                                          onPressed: () => _edit(item),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete ${item.subtype}',
                                          onPressed: () => _confirmDelete(item),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded),
                                        ),
                                      ],
                                    ),
                                    children: item.tracks.isEmpty
                                        ? const [
                                            ListTile(
                                              dense: true,
                                              leading:
                                                  Icon(Icons.music_off_rounded),
                                              title:
                                                  Text('No songs included yet'),
                                            )
                                          ]
                                        : item.tracks
                                            .map((track) => ListTile(
                                                  dense: true,
                                                  leading: Artwork(
                                                    color: track.color,
                                                    label: track.title,
                                                    imageUrl: track.artworkUrl,
                                                    size: 38,
                                                  ),
                                                  title: Text(track.title),
                                                  subtitle: Text(
                                                      '${track.artist} • ${track.album}'),
                                                ))
                                            .toList(),
                                  )),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _edit(group.first, true),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add subtype'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
    );
  }

  List<_RecommendedPlaylistGroup> _groups() {
    final grouped = <String, List<RecommendedPlaylist>>{};
    for (final item in items) {
      final searchable =
          '${item.name} ${item.type} ${item.subtype}'.toLowerCase();
      if (playlistQuery.isNotEmpty && !searchable.contains(playlistQuery)) {
        continue;
      }
      final key =
          '${item.name.trim().toLowerCase()}|${item.type.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped.values.map((variants) {
      variants.sort((a, b) => a.subtype.compareTo(b.subtype));
      return _RecommendedPlaylistGroup(variants);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _confirmDelete(RecommendedPlaylist item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete recommended playlist?'),
            content: Text(
              'Delete the ${item.subtype} subtype from ${item.name}? '
              'Its songs and schedule will be removed from recommendations.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await context.read<MusicController>().deleteRecommendedPlaylist(item.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.subtype} was deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete playlist: $error')),
      );
    }
  }

  Future<void> _edit(
      [RecommendedPlaylist? existing, bool createSubtype = false]) async {
    final music = context.read<MusicController>();
    final name = TextEditingController(text: existing?.name ?? '');
    final description =
        TextEditingController(text: existing?.description ?? '');
    const customChoice = 'Custom…';
    final initialType =
        existing?.type ?? recommendedPlaylistSubtypes.keys.first;
    var typeChoice = recommendedPlaylistSubtypes.containsKey(initialType)
        ? initialType
        : customChoice;
    final customType = TextEditingController(
        text: typeChoice == customChoice ? initialType : '');
    final initialSubtypes =
        recommendedPlaylistSubtypes[initialType] ?? const [];
    final usedSubtypes = createSubtype && existing != null
        ? items
            .where((item) =>
                item.name.toLowerCase() == existing.name.toLowerCase() &&
                item.type.toLowerCase() == existing.type.toLowerCase())
            .map((item) => item.subtype.toLowerCase())
            .toSet()
        : const <String>{};
    final initialSubtype = createSubtype
        ? initialSubtypes.firstWhere(
            (value) => !usedSubtypes.contains(value.toLowerCase()),
            orElse: () => '')
        : existing?.subtype ??
            (initialSubtypes.isEmpty ? '' : initialSubtypes.first);
    var subtypeChoice = initialSubtypes.contains(initialSubtype)
        ? initialSubtype
        : customChoice;
    final customSubtype = TextEditingController(
        text: subtypeChoice == customChoice ? initialSubtype : '');
    var active = existing?.active ?? true;
    var scheduleEnabled = existing?.scheduleEnabled ?? false;
    final scheduleDays = <int>{...?existing?.scheduleDays};
    var scheduleStart = existing?.scheduleStart ?? '';
    var scheduleEnd = existing?.scheduleEnd ?? '';
    var catalogQuery = '';
    final selected = <String>{
      if (existing != null && !createSubtype)
        ...existing.tracks.map((track) => track.id),
    };
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (_, setDialogState) => AlertDialog(
                  title: Text(createSubtype
                      ? 'Add subtype to ${existing?.name}'
                      : existing == null
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
                                readOnly: createSubtype,
                                decoration: const InputDecoration(
                                    labelText: 'Playlist name')),
                            TextField(
                                controller: description,
                                decoration: const InputDecoration(
                                    labelText: 'Details')),
                            DropdownButtonFormField<String>(
                                initialValue: typeChoice,
                                decoration:
                                    const InputDecoration(labelText: 'Type'),
                                items: [
                                  ...recommendedPlaylistSubtypes.keys,
                                  customChoice
                                ]
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                                onChanged: createSubtype
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          setDialogState(() {
                                            typeChoice = v;
                                            final choices =
                                                recommendedPlaylistSubtypes[v];
                                            subtypeChoice =
                                                choices?.first ?? customChoice;
                                          });
                                        }
                                      }),
                            if (typeChoice == customChoice)
                              TextField(
                                controller: customType,
                                decoration: const InputDecoration(
                                  labelText: 'Preferred type name',
                                  hintText: 'e.g. Festival Specials',
                                ),
                              ),
                            DropdownButtonFormField<String>(
                                key: ValueKey(typeChoice),
                                initialValue: subtypeChoice,
                                decoration:
                                    const InputDecoration(labelText: 'Subtype'),
                                items: [
                                  ...?recommendedPlaylistSubtypes[typeChoice],
                                  customChoice
                                ]
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(v)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => subtypeChoice = v);
                                  }
                                }),
                            if (subtypeChoice == customChoice)
                              TextField(
                                controller: customSubtype,
                                decoration: const InputDecoration(
                                  labelText: 'Preferred subtype name',
                                  hintText: 'e.g. Sankranti Celebration',
                                ),
                              ),
                            SwitchListTile(
                                value: active,
                                onChanged: (v) =>
                                    setDialogState(() => active = v),
                                title: const Text('Visible to listeners')),
                            Card(
                              margin: const EdgeInsets.only(top: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: scheduleEnabled,
                                      onChanged: (value) => setDialogState(
                                          () => scheduleEnabled = value),
                                      secondary: const Icon(
                                          Icons.auto_awesome_rounded),
                                      title:
                                          const Text('Schedule this playlist'),
                                      subtitle: const Text(
                                          'Choose when this subtype should be highlighted.'),
                                    ),
                                    if (scheduleEnabled) ...[
                                      const Text('Days of the week',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: List.generate(7, (index) {
                                          const labels = [
                                            'Mon',
                                            'Tue',
                                            'Wed',
                                            'Thu',
                                            'Fri',
                                            'Sat',
                                            'Sun'
                                          ];
                                          final day = index + 1;
                                          return FilterChip(
                                            label: Text(labels[index]),
                                            selected:
                                                scheduleDays.contains(day),
                                            onSelected: (selectedDay) =>
                                                setDialogState(() {
                                              selectedDay
                                                  ? scheduleDays.add(day)
                                                  : scheduleDays.remove(day);
                                            }),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        Expanded(
                                            child: OutlinedButton.icon(
                                          icon: const Icon(
                                              Icons.wb_sunny_outlined),
                                          label: Text(scheduleStart.isEmpty
                                              ? 'Starts anytime'
                                              : 'From $scheduleStart'),
                                          onPressed: () async {
                                            final picked = await showTimePicker(
                                              context: dialogContext,
                                              initialTime: _time(
                                                  scheduleStart,
                                                  const TimeOfDay(
                                                      hour: 6, minute: 0)),
                                            );
                                            if (picked != null)
                                              setDialogState(() =>
                                                  scheduleStart =
                                                      _clock(picked));
                                          },
                                        )),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: OutlinedButton.icon(
                                          icon: const Icon(
                                              Icons.nights_stay_outlined),
                                          label: Text(scheduleEnd.isEmpty
                                              ? 'Ends anytime'
                                              : 'Until $scheduleEnd'),
                                          onPressed: () async {
                                            final picked = await showTimePicker(
                                              context: dialogContext,
                                              initialTime: _time(
                                                  scheduleEnd,
                                                  const TimeOfDay(
                                                      hour: 22, minute: 0)),
                                            );
                                            if (picked != null)
                                              setDialogState(() =>
                                                  scheduleEnd = _clock(picked));
                                          },
                                        )),
                                      ]),
                                      if (scheduleStart.isNotEmpty ||
                                          scheduleEnd.isNotEmpty)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => setDialogState(() {
                                              scheduleStart = '';
                                              scheduleEnd = '';
                                            }),
                                            child: const Text('Use all day'),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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
                            const SizedBox(height: 8),
                            ExpansionTile(
                              initiallyExpanded: true,
                              tilePadding: EdgeInsets.zero,
                              leading: const Icon(Icons.folder_copy_rounded),
                              title: const Text(
                                'Choose album folders',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                  'Select an album to add all of its songs'),
                              children: music.albums.where((album) {
                                if (catalogQuery.isEmpty) return true;
                                return [
                                  album.title,
                                  album.artist,
                                  ...album.tracks.map((track) => track.title),
                                ]
                                    .join(' ')
                                    .toLowerCase()
                                    .contains(catalogQuery);
                              }).map((album) {
                                final albumTrackIds = album.tracks
                                    .map((track) => track.id)
                                    .toSet();
                                final selectedCount = albumTrackIds
                                    .where(selected.contains)
                                    .length;
                                final allSelected = albumTrackIds.isNotEmpty &&
                                    selectedCount == albumTrackIds.length;
                                final partiallySelected =
                                    selectedCount > 0 && !allSelected;
                                return CheckboxListTile(
                                  secondary: const Icon(Icons.album_rounded),
                                  dense: true,
                                  tristate: true,
                                  value: partiallySelected ? null : allSelected,
                                  title: Text(album.title),
                                  subtitle: Text(
                                    '${album.artist} • ${album.tracks.length} songs'
                                    '${selectedCount == 0 ? '' : ' • $selectedCount selected'}',
                                  ),
                                  onChanged: albumTrackIds.isEmpty
                                      ? null
                                      : (value) => setDialogState(() {
                                            if (value == true ||
                                                partiallySelected) {
                                              selected.addAll(albumTrackIds);
                                            } else {
                                              selected.removeAll(albumTrackIds);
                                            }
                                          }),
                                );
                              }).toList(),
                            ),
                            const Divider(),
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
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          if (name.text.trim().isEmpty) return;
                          final type = typeChoice == customChoice
                              ? customType.text.trim()
                              : typeChoice;
                          final subtype = subtypeChoice == customChoice
                              ? customSubtype.text.trim()
                              : subtypeChoice;
                          if (type.isEmpty || subtype.isEmpty) return;
                          await music.saveRecommendedPlaylist(
                              RecommendedPlaylist(
                                  id: createSubtype ? '' : existing?.id ?? '',
                                  name: name.text.trim(),
                                  description: description.text.trim(),
                                  type: type,
                                  subtype: subtype,
                                  color: existing?.color ?? '7C4DFF',
                                  artworkUrl: existing?.artworkUrl ?? '',
                                  tracks: music.allTracks
                                      .where((t) => selected.contains(t.id))
                                      .toList(),
                                  active: active,
                                  scheduleEnabled: scheduleEnabled,
                                  scheduleDays: scheduleDays.toList()..sort(),
                                  scheduleStart: scheduleStart,
                                  scheduleEnd: scheduleEnd));
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Save')),
                  ],
                )));
    name.dispose();
    description.dispose();
    customType.dispose();
    customSubtype.dispose();
    if (saved == true) await _load();
  }

  TimeOfDay _time(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? fallback.hour,
        minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _clock(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _RecommendedPlaylistGroup {
  _RecommendedPlaylistGroup(this.variants);
  final List<RecommendedPlaylist> variants;
  RecommendedPlaylist get first => variants.first;
  String get name => first.name;
  String get type => first.type;
}
