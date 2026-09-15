import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/main.dart';

void main() {
  testWidgets('Greeting page shows Hello there!', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });
}
