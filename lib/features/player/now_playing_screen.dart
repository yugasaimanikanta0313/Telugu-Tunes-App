import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                              onPressed: () => controller.toggleFavorite(track),
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
                          ],
                        ),
                        const SizedBox(height: 22),
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
