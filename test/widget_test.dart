import 'package:flutter_test/flutter_test.dart';
import 'package:aurashow/app.dart';

void main() {
  testWidgets('Counter increment smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuraShowApp());

    expect(find.text('1'), findsNothing);
  });
}