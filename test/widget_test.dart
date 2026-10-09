import 'package:flutter_test/flutter_test.dart';
import 'package:nba_trivia/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const NbaTriviaApp());
    expect(find.byType(NbaTriviaApp), findsOneWidget);
  });
}


