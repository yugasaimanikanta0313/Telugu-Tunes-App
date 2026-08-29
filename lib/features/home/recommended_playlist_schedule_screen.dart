import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class RecommendedPlaylistScheduleScreen extends StatefulWidget {
  const RecommendedPlaylistScheduleScreen({
    super.key,
    required this.name,
    required this.type,
    required this.variants,
  });

  final String name;
  final String type;
  final List<RecommendedPlaylist> variants;

  @override
  State<RecommendedPlaylistScheduleScreen> createState() =>
      _RecommendedPlaylistScheduleScreenState();
}

class _RecommendedPlaylistScheduleScreenState
    extends State<RecommendedPlaylistScheduleScreen> {
  int selectedWeekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicController>();
    final variants =
        widget.variants.map(music.effectiveRecommendedPlaylist).toList();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = List.generate(7, (i) => start.add(Duration(days: i)));
    final date = week[selectedWeekday - 1];
    final scheduled = variants.where((item) {
      return !item.scheduleEnabled ||
          item.scheduleDays.isEmpty ||
          item.scheduleDays.contains(selectedWeekday);
    }).toList();
    final first = widget.variants.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Customize my calendar',
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () => showRecommendationCalendar(
                context, widget.variants,
                title: widget.name),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(colors: [
                colorFromHex(first.color).withValues(alpha: .9),
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ]),
            ),
            child: Row(children: [
              Artwork(
                color: first.color,
                label: widget.name,
                imageUrl: first.artworkUrl,
                size: 74,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${widget.type} • ${variants.length} subtypes'),
                    const SizedBox(height: 8),
                    const Row(children: [
                      Icon(Icons.tune_rounded, size: 16),
                      SizedBox(width: 5),
                      Text('Your week, your soundtrack'),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: Text('Choose a day',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
            ),
            Text(_longDate(date),
                style: Theme.of(context).textTheme.labelLarge),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: week.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = week[index];
                final selected = item.weekday == selectedWeekday;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => selectedWeekday = item.weekday),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 68,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainer,
                      border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Column(children: [
                      Text(_dayName(item.weekday),
                          style: TextStyle(
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${item.day}',
                          style: TextStyle(
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (scheduled.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Icon(Icons.event_busy_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'No ${widget.name} subtype is scheduled for ${_longDate(date)}.'),
                  ),
                ]),
              ),
            )
          else
            ...scheduled.map((playlist) => _SubtypeScheduleCard(
                  playlist: playlist,
                  customized:
                      music.recommendationPreferences.containsKey(playlist.id),
                )),
        ],
      ),
    );
  }
}

class _SubtypeScheduleCard extends StatelessWidget {
  const _SubtypeScheduleCard(
      {required this.playlist, required this.customized});

  final RecommendedPlaylist playlist;
  final bool customized;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Artwork(
            color: playlist.color,
            label: playlist.subtype,
            imageUrl: playlist.artworkUrl,
            size: 52,
          ),
          title: Text(playlist.subtype,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(
              '${_timeLabel(playlist)} • ${playlist.tracks.length} songs${customized ? ' • My schedule' : ''}'),
          trailing: playlist.tracks.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Play this subtype',
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  onPressed: () => context
                      .read<MusicController>()
                      .play(playlist.tracks.first),
                ),
          children: playlist.tracks.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Text('No songs are included in this subtype yet.'),
                  )
                ]
              : playlist.tracks
                  .map((track) => TrackTile(
                        track: track,
                        onTap: () =>
                            context.read<MusicController>().play(track),
                        onMore: () => showTrackActions(context, track),
                      ))
                  .toList(),
        ),
      );
}

Future<void> showRecommendationCalendar(
    BuildContext context, List<RecommendedPlaylist> playlists,
    {String title = 'My recommendation calendar'}) async {
  final music = context.read<MusicController>();
  if (!music.isAuthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sign in from Account to create your personal calendar.'),
    ));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .78,
          child: Column(children: [
            ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.edit_calendar_rounded)),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              subtitle: const Text(
                  'Your choices override the app schedule only for your account.'),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final effective =
                      music.effectiveRecommendedPlaylist(playlist);
                  final personalized =
                      music.recommendationPreferences.containsKey(playlist.id);
                  return Card(
                    child: ListTile(
                      leading: Artwork(
                        color: playlist.color,
                        label: playlist.subtype,
                        imageUrl: playlist.artworkUrl,
                        size: 48,
                      ),
                      title: Text('${playlist.name} • ${playlist.subtype}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(personalized
                          ? 'My schedule: ${effective.scheduleLabel}'
                          : 'App schedule: ${playlist.scheduleLabel}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await _editPreference(
                            sheetContext, playlist, effective, personalized);
                        setSheetState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

Future<void> _editPreference(BuildContext context, RecommendedPlaylist original,
    RecommendedPlaylist effective, bool personalized) async {
  var enabled = effective.scheduleEnabled;
  final days = <int>{...effective.scheduleDays};
  var start = effective.scheduleStart;
  var end = effective.scheduleEnd;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(original.subtype),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use my schedule'),
                subtitle: Text(enabled
                    ? 'Show this subtype on my selected days.'
                    : 'Keep this subtype available every day.'),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
              if (enabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text(_dayName(day)),
                      selected: days.contains(day),
                      onSelected: (selected) => setDialogState(
                          () => selected ? days.add(day) : days.remove(day)),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(start.isEmpty ? 'Start time' : start),
                      onPressed: () async {
                        final picked = await showTimePicker(
                            context: context,
                            initialTime: _parseTime(
                                start, const TimeOfDay(hour: 6, minute: 0)));
                        if (picked != null) {
                          setDialogState(() => start = _formatTime(picked));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(end.isEmpty ? 'End time' : end),
                      onPressed: () async {
                        final picked = await showTimePicker(
                            context: context,
                            initialTime: _parseTime(
                                end, const TimeOfDay(hour: 10, minute: 0)));
                        if (picked != null) {
                          setDialogState(() => end = _formatTime(picked));
                        }
                      },
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
        actions: [
          if (personalized)
            TextButton(
              onPressed: () async {
                await context
                    .read<MusicController>()
                    .resetRecommendedPlaylistPreference(original.id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Use app default'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: enabled && days.isEmpty
                ? null
                : () async {
                    await context
                        .read<MusicController>()
                        .saveRecommendedPlaylistPreference(
                          RecommendedPlaylistPreference(
                            playlistId: original.id,
                            enabled: enabled,
                            scheduleDays: days.toList()..sort(),
                            scheduleStart: enabled ? start : '',
                            scheduleEnd: enabled ? end : '',
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

String _dayName(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _longDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String _timeLabel(RecommendedPlaylist playlist) {
  if (!playlist.scheduleEnabled) return 'Anytime';
  if (playlist.scheduleStart.isEmpty || playlist.scheduleEnd.isEmpty) {
    return 'All day';
  }
  return '${playlist.scheduleStart}–${playlist.scheduleEnd}';
}

TimeOfDay _parseTime(String value, TimeOfDay fallback) {
  final parts = value.split(':');
  if (parts.length != 2) return fallback;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return fallback;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
