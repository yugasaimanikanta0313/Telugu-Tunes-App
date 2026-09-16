import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:telugu_tunes/features/shell/app_shell.dart';
import 'package:telugu_tunes/main.dart';
import 'package:telugu_tunes/state/music_controller.dart';

void main() {
  testWidgets('phone back follows tabs and asks before exit', (tester) async {
    await tester.pumpWidget(const TeluguTunesApp(useMockData: true));
    Future<void> pumpUi() async {
      for (var index = 0; index < 6; index++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await pumpUi();
    final controller =
        tester.element(find.byType(AppShell)).read<MusicController>();
    await tester.tap(find.byIcon(Icons.search_rounded).last);
    await pumpUi();
    await tester.tap(find.byIcon(Icons.library_music_rounded).last);
    await pumpUi();
    expect(controller.activeTab, 2);
    await tester.binding.handlePopRoute();
    await pumpUi();
    expect(controller.activeTab, 1);
    await tester.binding.handlePopRoute();
    await pumpUi();
    expect(controller.activeTab, 0);
    await tester.binding.handlePopRoute();
    await pumpUi();
    expect(find.text('Exit Telugu Tunes?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await pumpUi();
    expect(controller.activeTab, 0);
  });
}
