// Smoke test: the app boots without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derby_bins/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const BinApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
