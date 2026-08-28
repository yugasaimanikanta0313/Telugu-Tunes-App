import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:telugu_tunes/data/repositories/music_repository.dart';
import 'package:telugu_tunes/features/shell/app_shell.dart';
import 'package:telugu_tunes/main.dart';
import 'package:telugu_tunes/state/music_controller.dart';

void main() {
  testWidgets('home loads the mock Telugu music client', (tester) async {
    await tester.pumpWidget(
      const TeluguTunesApp(useMockData: true),
    );

    // The home screen intentionally contains repeating player animations, so
    // wait for asynchronous repository loading without waiting for all visual
    // animations to become permanently idle.
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Namasthe!, Srinu'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Tune AI'), findsOneWidget);
  });

  testWidgets('closing a room returns to the lobby without a framework error',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MusicController(
          MockMusicRepository(),
          memberId: 'Srinu',
          authToken: 'test-token',
        )..load(),
        child: const MaterialApp(home: AppShell()),
      ),
    );
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    tester.element(find.byType(AppShell)).read<MusicController>().setTab(3);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Close room for everyone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Close room for everyone'), findsOneWidget);

    await tester.tap(find.text('Close room for everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Close room'));
    await tester.pumpAndSettle();

    expect(find.text('Start your own room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can browse but rooms require account binding',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MusicController(MockMusicRepository())..load(),
        child: const MaterialApp(home: AppShell()),
      ),
    );
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Recently played'), findsOneWidget);
    tester.element(find.byType(AppShell)).read<MusicController>().setTab(3);
    await tester.pumpAndSettle();

    expect(find.text('Sign in for listening rooms'), findsOneWidget);
  });
}
