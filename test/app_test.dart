import 'package:flutter_test/flutter_test.dart';
import 'package:telugu_tunes/main.dart';

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

    expect(find.text('నమస్కారం, Srinu'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Tune AI'), findsOneWidget);
  });
}
