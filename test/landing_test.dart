import 'package:er/bootstrap/stub.dart';
import 'package:er/landing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('landing page renders and buttons tap safely', (t) async {
    await t.pumpWidget(const LandingApp());
    await t.pumpAndSettle();

    expect(find.text('er 二'), findsOneWidget);
    expect(find.textContaining('Run the same flatpak'), findsOneWidget);
    expect(find.text('Real isolation'), findsOneWidget);
    expect(find.text('Private session bus'), findsOneWidget);
    expect(find.text('Zero setup'), findsOneWidget);

    await t.tap(find.text('Download for Linux'));
    await t.tap(find.text('Source'));
    await t.pump();
  });

  test('stub bootstrap returns the landing app', () {
    expect(buildApp(), isA<LandingApp>());
  });
}
