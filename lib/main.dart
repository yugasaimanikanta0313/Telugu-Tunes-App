import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'data/repositories/music_repository.dart';
import 'data/services/api_music_service.dart';
import 'data/services/auth_session_service.dart';
import 'design/telugu_tunes_design.dart';
import 'features/shared/server_wake_gate.dart';
import 'features/shell/app_shell.dart';
import 'state/music_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep decoded artwork useful without allowing an unbounded memory cache.
  PaintingBinding.instance.imageCache
    ..maximumSize = 160
    ..maximumSizeBytes = 80 << 20;
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.telugutunes.audio',
      androidNotificationChannelName: 'Telugu Tunes playback',
      androidNotificationOngoing: true,
    );
  }
  const useMockData = bool.fromEnvironment('USE_MOCK_DATA');
  final restoredSession = useMockData
      ? null
      : await AuthSessionService().restore(BackendConfig.development);
  runApp(TeluguTunesApp(
      useMockData: useMockData, initialSession: restoredSession));
}

class TeluguTunesApp extends StatefulWidget {
  const TeluguTunesApp(
      {super.key, required this.useMockData, this.initialSession});
  final bool useMockData;
  final ApiSession? initialSession;

  @override
  State<TeluguTunesApp> createState() => _TeluguTunesAppState();
}

class _TeluguTunesAppState extends State<TeluguTunesApp> {
  ApiSession? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

  Future<void> _authenticated(ApiSession session) async {
    await AuthSessionService().save(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _signOut() async {
    await AuthSessionService().clear();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMockData) {
      return ChangeNotifierProvider(
        create: (_) => MusicController(MockMusicRepository())..load(),
        child: const _MusicMaterialApp(home: AppShell()),
      );
    }

    final config = _session?.config ?? BackendConfig.development;
    return ChangeNotifierProvider(
      key: ValueKey(config.authToken.isEmpty ? 'guest' : config.authToken),
      create: (_) => MusicController(
        SpringBootMusicRepository(SpringBootMusicApiService(config)),
        remoteMode: true,
        apiBaseUrl: config.baseUrl,
        authToken: config.authToken,
        memberName: _session?.member.displayName ?? 'Guest listener',
        memberId: _session?.member.id ?? '',
        isAdmin: _session?.member.isAdmin ?? false,
      )..load(),
      child: _MusicMaterialApp(
        home: ServerWakeGate(
          apiBaseUrl: config.baseUrl,
          child: AppShell(
            onSignOut: _session == null ? null : _signOut,
            onSignIn: _session == null ? _authenticated : null,
          ),
        ),
      ),
    );
  }
}

class _MusicMaterialApp extends StatelessWidget {
  const _MusicMaterialApp({required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final colorValue =
        context.select<MusicController, int>((value) => value.themeColorValue);
    return _buildMaterialApp(home, seedColor: Color(colorValue));
  }
}

Widget _buildMaterialApp(Widget home,
        {Color seedColor = const Color(0xffe15184)}) =>
    MaterialApp(
      title: 'Telugu Tunes',
      debugShowCheckedModeBanner: false,
      theme: teluguTunesTheme(),
      home: home,
    );
