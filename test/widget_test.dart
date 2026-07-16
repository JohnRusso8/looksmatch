import 'package:flutter_test/flutter_test.dart';

import 'package:looksmatch/main.dart';

void main() {
  testWidgets('LooksMatch app launches to the Discover tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LooksMatchApp());
    await tester.pumpAndSettle();

    expect(find.text('LooksMatch'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
