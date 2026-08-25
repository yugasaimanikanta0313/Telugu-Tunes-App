import 'package:flutter_test/flutter_test.dart';
import 'package:telugu_tunes/main.dart';

void main() {
  testWidgets('home loads the mock Telugu music client', (tester) async {
    await tester.pumpWidget(
      const TeluguTunesApp(useMockData: true),
    );

    await tester.pumpAndSettle();

    expect(find.text('నమస్కారం, Srinu'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Tune AI'), findsOneWidget);
  });
}
