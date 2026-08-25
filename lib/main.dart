import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/music_repository.dart';
import 'data/services/api_music_service.dart';
import 'data/services/auth_session_service.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/shared/server_wake_gate.dart';
import 'features/shell/app_shell.dart';
import 'state/music_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        child: _materialApp(const AppShell()),
      );
    }

    if (_session == null) {
      return _materialApp(
        ServerWakeGate(
          apiBaseUrl: BackendConfig.development.baseUrl,
          child: SignInScreen(onAuthenticated: _authenticated),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => MusicController(
        SpringBootMusicRepository(SpringBootMusicApiService(_session!.config)),
        remoteMode: true,
        apiBaseUrl: _session!.config.baseUrl,
        authToken: _session!.config.authToken,
        memberName: _session!.member.displayName,
        memberId: _session!.member.id,
        isAdmin: _session!.member.isAdmin,
      )..load(),
      child: _materialApp(
        ServerWakeGate(
          apiBaseUrl: _session!.config.baseUrl,
          child: AppShell(onSignOut: _signOut),
        ),
      ),
    );
  }

  Widget _materialApp(Widget home) => MaterialApp(
        title: 'Telugu Tunes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffe15184), brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xff101014),
          cardTheme: const CardThemeData(color: Color(0xff1d1d24)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xff1d1d24),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xffe15184)),
            ),
          ),
        ),
        home: home,
      );
}
