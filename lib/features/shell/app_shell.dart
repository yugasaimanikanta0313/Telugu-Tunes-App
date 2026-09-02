import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/music_controller.dart';
import '../../data/services/api_music_service.dart';
import '../../design/telugu_tunes_design.dart';
import '../auth/sign_in_screen.dart';
import '../home/home_screen.dart';
import '../import/import_music_sheet.dart';
import '../library/library_screen.dart';
import '../player/now_playing_screen.dart';
import '../room/room_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.onSignOut, this.onSignIn});

  final Future<void> Function()? onSignOut;
  final ValueChanged<ApiSession>? onSignIn;

  static const _primaryPages = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    RoomScreen(),
  ];
  static const _labels = ['Home', 'Search', 'Library', 'Room', 'Settings'];
  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.library_music_rounded,
    Icons.group_rounded,
    Icons.settings_rounded
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _pageNavigatorKeys =
      List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final pages = [
      AppShell._primaryPages[0],
      AppShell._primaryPages[1],
      controller.isAuthenticated
          ? AppShell._primaryPages[2]
          : _SignInRequiredScreen(
              feature: 'playlists and favorites', onSignIn: widget.onSignIn),
      controller.isAuthenticated
          ? AppShell._primaryPages[3]
          : _SignInRequiredScreen(
              feature: 'listening rooms', onSignIn: widget.onSignIn),
      SettingsScreen(onSignOut: widget.onSignOut, onSignIn: widget.onSignIn),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final pageNavigatorKey = _pageNavigatorKeys[controller.activeTab];
        final pageContent = Stack(children: [
          Column(children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Navigator(
                  key: pageNavigatorKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => pages[controller.activeTab],
                  ),
                ),
              ),
            ),
            if (controller.current != null &&
                controller.activeTab != 4 &&
                !controller.nowPlayingScreenVisible)
              _MiniPlayer(
                onOpen: () => pageNavigatorKey.currentState?.push<void>(
                  MaterialPageRoute(
                    builder: (_) => const _NowPlayingRoute(),
                  ),
                ),
              ),
          ]),
          if (controller.votePromptTrack case final track?)
            Positioned(
              left: 16,
              right: 16,
              bottom: controller.current == null || controller.activeTab == 4
                  ? 16
                  : 82,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Card(
                    elevation: 12,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(children: [
                        const Icon(Icons.how_to_vote_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                'Should “${track.title}” be added to a recommended playlist?')),
                        TextButton(
                            onPressed: () {
                              controller.dismissVotePrompt();
                              showRecommendationVoteSheet(context, track);
                            },
                            child: const Text('Go to voting')),
                        IconButton(
                            onPressed: controller.dismissVotePrompt,
                            tooltip: 'Not now',
                            icon: const Icon(Icons.close_rounded)),
                      ]),
                    )),
              )),
            ),
        ]);
        final content = SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: pageContent,
          ),
        );
        return Scaffold(
          body: MusicalAurora(
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: controller.activeTab,
                        onDestinationSelected: controller.setTab,
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: IconButton.filled(
                              onPressed: controller.isAuthenticated &&
                                      controller.isAdmin
                                  ? () => showImportMusicSheet(context)
                                  : null,
                              tooltip: 'Add music',
                              icon: const Icon(Icons.add_rounded)),
                        ),
                        destinations: List.generate(
                            AppShell._labels.length,
                            (index) => NavigationRailDestination(
                                icon: Icon(AppShell._icons[index]),
                                selectedIcon: Icon(AppShell._icons[index]),
                                label: Text(AppShell._labels[index]))),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: controller.activeTab,
                  onDestinationSelected: controller.setTab,
                  destinations: List.generate(
                      AppShell._labels.length,
                      (index) => NavigationDestination(
                          icon: Icon(AppShell._icons[index]),
                          selectedIcon: Icon(AppShell._icons[index]),
                          label: AppShell._labels[index])),
                ),
        );
      },
    );
  }
}

class _NowPlayingRoute extends StatefulWidget {
  const _NowPlayingRoute();

  @override
  State<_NowPlayingRoute> createState() => _NowPlayingRouteState();
}

class _NowPlayingRouteState extends State<_NowPlayingRoute> {
  late MusicController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<MusicController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.setNowPlayingScreenVisible(true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.setNowPlayingScreenVisible(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const NowPlayingScreen();
}

class _SignInRequiredScreen extends StatelessWidget {
  const _SignInRequiredScreen({required this.feature, this.onSignIn});
  final String feature;
  final ValueChanged<ApiSession>? onSignIn;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_person_outlined, size: 48),
                const SizedBox(height: 16),
                Text('Sign in for $feature',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 8),
                const Text(
                  'Listening to Telugu Tunes is free without an account. Sign in only when you want personal or social features.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onSignIn == null
                      ? null
                      : () => _openSignIn(context, onSignIn!),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in or create account'),
                ),
              ]),
            ),
          ),
        ),
      );
}

Future<void> _openSignIn(
    BuildContext context, ValueChanged<ApiSession> onSignIn) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SignInScreen(
        onAuthenticated: (session) {
          Navigator.pop(context);
          onSignIn(session);
        },
      ),
    ),
  );
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final track = controller.current!;
    return Material(
      color: TeluguTunesColors.surfaceHigh.withValues(alpha: .97),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          children: [
            LinearProgressIndicator(value: controller.progress, minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              child: Row(children: [
                Hero(
                    tag: 'track-' + track.id,
                    child: Artwork(
                        color: track.color,
                        label: track.album,
                        imageUrl: track.artworkUrl,
                        size: 48)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
                if (controller.isDownloaded(track))
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.download_done_rounded, size: 18)),
                IconButton(
                    onPressed: controller.togglePlay,
                    tooltip: controller.playing ? 'Pause' : 'Play',
                    icon: Icon(controller.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded)),
                IconButton(
                    onPressed: controller.skipNext,
                    tooltip: 'Next',
                    icon: const Icon(Icons.skip_next_rounded)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
