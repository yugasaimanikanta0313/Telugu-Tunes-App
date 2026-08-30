import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../domain/models/music_models.dart';
import '../../state/music_controller.dart';
import '../shared/widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final track = controller.current;
    if (track == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.music_off_rounded,
          title: 'Nothing is playing',
          body: 'Choose a song to start your private listening session.',
        ),
      );
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorFromHex(track.color).withOpacity(.74),
              const Color(0xff101014),
              const Color(0xff101014),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artworkSize = math.min(
                390.0,
                math.max(
                    180.0,
                    math.min(constraints.maxWidth - 48,
                        constraints.maxHeight * .42)),
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.keyboard_arrow_down_rounded),
                            ),
                            Expanded(
                              child: Text(
                                'NOW PLAYING',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showSleepTimer(context),
                              tooltip: 'Sleep timer',
                              icon: Icon(controller.sleepEndsAt == null
                                  ? Icons.bedtime_outlined
                                  : Icons.bedtime_rounded),
                            ),
                            IconButton(
                              onPressed: () => showTrackActions(context, track),
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(
                              begin: .95, end: controller.playing ? 1 : .97),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Artwork(
                            color: track.color,
                            label: track.album,
                            imageUrl: track.artworkUrl,
                            size: artworkSize,
                            heroTag: 'track-${track.id}',
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${track.artist} • ${track.album}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: controller.isAuthenticated
                                  ? () => controller.toggleFavorite(track)
                                  : null,
                              icon: Icon(
                                controller.isFavorite(track)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: controller.isFavorite(track)
                                    ? Colors.pinkAccent
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Slider(
                            value: controller.progress,
                            onChanged: controller.seek),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(controller.elapsedLabel,
                                style: Theme.of(context).textTheme.labelMedium),
                            Text(controller.remainingDurationLabel,
                                style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ),
                        if (controller.playerError != null) ...[
                          const SizedBox(height: 10),
                          _PlaybackNotice(message: controller.playerError!),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: controller.toggleShuffle,
                              tooltip: 'Shuffle',
                              color: controller.shuffleEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                            IconButton(
                              onPressed: controller.skipPrevious,
                              iconSize: 37,
                              tooltip: 'Previous',
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(16)),
                              onPressed: controller.togglePlay,
                              iconSize: 40,
                              tooltip: controller.playing ? 'Pause' : 'Play',
                              icon: Icon(controller.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                            ),
                            IconButton(
                              onPressed: controller.skipNext,
                              iconSize: 37,
                              tooltip: 'Next',
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                            IconButton(
                              onPressed: controller.toggleRepeat,
                              tooltip: 'Repeat',
                              color: controller.repeatEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              icon: const Icon(Icons.repeat_rounded),
                            ),
                            IconButton(
                              onPressed: () =>
                                  showRecommendationVoteSheet(context, track),
                              tooltip: 'Vote for a recommended playlist',
                              color: controller.isAuthenticated &&
                                      controller
                                          .eligibleVotePlaylists(track)
                                          .isNotEmpty
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              icon: const Icon(Icons.how_to_vote_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (controller.sleepRemaining != null) ...[
                          Chip(
                            avatar: const Icon(Icons.timer_outlined, size: 18),
                            label: Text(
                                'Stops in ${_durationLabel(controller.sleepRemaining!)}'),
                            onDeleted: controller.cancelSleepTimer,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _LyricsPanel(controller: controller, track: track),
                        const SizedBox(height: 16),
                        if (controller.room != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(.09),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.group_rounded, size: 19),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Listening together in ${controller.room!.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    controller.setTab(3);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Room'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _durationLabel(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _showSleepTimer(BuildContext context) async {
    final controller = context.read<MusicController>();
    final selected = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.bedtime_rounded),
              title: Text('Sleep timer',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Playback stops automatically on this device.'),
            ),
            for (final minutes in const [15, 30, 45, 60])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () =>
                    Navigator.pop(sheetContext, Duration(minutes: minutes)),
              ),
            if (controller.sleepEndsAt != null)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Cancel current timer'),
                onTap: () {
                  controller.cancelSleepTimer();
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
    if (selected != null) controller.startSleepTimer(selected);
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.controller, required this.track});

  final MusicController controller;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final lyrics = controller.currentLyrics;
    final currentLine = _currentLine(lyrics, controller.position);
    final currentEnglishLine =
        _currentLineFrom(lyrics?.englishLines ?? const [], controller.position);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lyrics_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Telugu lyrics',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (lyrics?.hasLyrics == true)
                TextButton(
                  onPressed: () => _showLyrics(context),
                  child: const Text('View all'),
                ),
            ],
          ),
          if (controller.lyricsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (currentLine != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(currentLine.start),
                children: [
                  Text(currentLine.text,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            height: 1.5,
                          )),
                  if (currentEnglishLine != null &&
                      currentEnglishLine.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(currentEnglishLine.text,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                              height: 1.35,
                            )),
                  ],
                ],
              ),
            )
          else if (lyrics?.plainLyrics.trim().isNotEmpty == true)
            Text(
              lyrics!.plainLyrics.split(RegExp(r'\r?\n')).first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(controller.lyricsError ??
                'No synced lyrics found. An admin can add an LRC file.'),
          if (controller.isAdmin) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: controller.lyricsLoading
                      ? null
                      : () => controller.loadLyrics(track, force: true),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Find synced lyrics'),
                ),
                TextButton.icon(
                  onPressed: () => _editLyrics(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit LRC'),
                ),
                TextButton.icon(
                  onPressed: lyrics?.hasLyrics == true
                      ? () => _generateEnglish(context)
                      : null,
                  icon: const Icon(Icons.translate_rounded, size: 18),
                  label: Text(lyrics?.hasEnglish == true
                      ? 'Regenerate English'
                      : 'Generate English'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  SyncedLyricLine? _currentLine(TrackLyrics? lyrics, Duration position) {
    return _currentLineFrom(lyrics?.lines ?? const [], position);
  }

  SyncedLyricLine? _currentLineFrom(
      List<SyncedLyricLine> lines, Duration position) {
    if (lines.isEmpty) return null;
    SyncedLyricLine? result;
    for (final line in lines) {
      if (line.start > position) break;
      result = line;
    }
    return result ?? lines.first;
  }

  Future<void> _generateEnglish(BuildContext context) async {
    final lyrics = controller.currentLyrics;
    if (lyrics == null || !lyrics.hasLyrics) return;
    final timestamp = RegExp(r'^(\[[^\]]+\]\s*)(.*)$');
    final sourceLines = lyrics.syncedLyrics.trim().isNotEmpty
        ? lyrics.syncedLyrics.split(RegExp(r'\r?\n'))
        : lyrics.plainLyrics.split(RegExp(r'\r?\n'));
    final prefixes = <String>[];
    final texts = <String>[];
    for (final raw in sourceLines) {
      final match = timestamp.firstMatch(raw.trim());
      prefixes.add(match?.group(1) ?? '');
      texts.add((match?.group(2) ?? raw).trim());
    }
    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8765/translate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sourceLanguage': 'tel_Telu',
              'targetLanguage': 'eng_Latn',
              'lines': texts,
            }),
          )
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw StateError('Local translator returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final translated = (decoded['translations'] as List?)
              ?.map((value) => value.toString().trim())
              .toList() ??
          const <String>[];
      if (translated.length != texts.length) {
        throw StateError('The translator returned an incomplete result.');
      }
      final englishSynced = List.generate(translated.length,
          (index) => '${prefixes[index]}${translated[index]}').join('\n');
      final englishPlain = translated.join('\n');
      if (!context.mounted) return;
      await _reviewEnglish(context, englishPlain, englishSynced);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Start the IndicTrans2 Admin Translator on this computer, then try again. ${error.toString().replaceFirst('Bad state: ', '')}'),
      ));
    }
  }

  Future<void> _reviewEnglish(
      BuildContext context, String plainValue, String syncedValue) async {
    final synced = TextEditingController(text: syncedValue);
    final plain = TextEditingController(text: plainValue);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Review English lyrics for ${track.title}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(children: [
              const Text(
                  'IndicTrans2 created this draft locally. Correct names, idioms and poetic meaning before publishing.'),
              const SizedBox(height: 12),
              TextField(
                controller: synced,
                minLines: 10,
                maxLines: 16,
                decoration: const InputDecoration(
                    labelText: 'Timestamped English lyrics'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plain,
                minLines: 5,
                maxLines: 10,
                decoration:
                    const InputDecoration(labelText: 'Plain English lyrics'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Approve & publish')),
        ],
      ),
    );
    if (save != true) return;
    await controller.updateLyricsTranslation(track,
        englishPlainLyrics: plain.text, englishSyncedLyrics: synced.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('English lyrics published.')));
    }
  }

  void _showLyrics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SyncedLyricsSheet(),
    );
  }

  Future<void> _editLyrics(BuildContext context) async {
    final existing = controller.currentLyrics;
    final plain = TextEditingController(text: existing?.plainLyrics ?? '');
    final synced = TextEditingController(text: existing?.syncedLyrics ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit lyrics for ${track.title}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: synced,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Synced LRC lyrics',
                    hintText: '[00:12.40] తెలుగు పాట లైన్',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plain,
                  minLines: 4,
                  maxLines: 8,
                  decoration:
                      const InputDecoration(labelText: 'Plain lyrics fallback'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save lyrics')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    try {
      await controller.updateLyrics(
        track,
        language: 'te',
        plainLyrics: plain.text,
        syncedLyrics: synced.text,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ));
      }
    }
  }
}

class _SyncedLyricsSheet extends StatelessWidget {
  const _SyncedLyricsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final lyrics = controller.currentLyrics;
    final lines = lyrics?.lines ?? const <SyncedLyricLine>[];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.lyrics_rounded),
              title: Text(controller.current?.title ?? 'Lyrics'),
              subtitle: Text(
                  'Source: ${lyrics?.source ?? 'unavailable'} • ${lines.isEmpty ? 'plain' : 'time-synced'}'),
            ),
            Expanded(
              child: lines.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(lyrics?.plainLyrics ??
                          'No lyrics have been added for this song.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                      itemCount: lines.length,
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        final englishLine =
                            index < (lyrics?.englishLines.length ?? 0)
                                ? lyrics!.englishLines[index]
                                : null;
                        final next = index + 1 < lines.length
                            ? lines[index + 1].start
                            : const Duration(days: 1);
                        final active = controller.position >= line.start &&
                            controller.position < next;
                        return ListTile(
                          selected: active,
                          title: Text(
                            line.text,
                            style: TextStyle(
                              fontSize: active ? 21 : 17,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w500,
                            ),
                          ),
                          subtitle: englishLine == null ||
                                  englishLine.text.trim().isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(englishLine.text,
                                      style: TextStyle(
                                        fontSize: active ? 17 : 15,
                                        color: active
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.white60,
                                      )),
                                ),
                          onTap: () => controller.seekTo(line.start),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackNotice extends StatelessWidget {
  const _PlaybackNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(.72),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      );
}
