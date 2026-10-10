import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:derby_bins/screens/bin_guide_screen.dart';
import 'package:derby_bins/theme/app_theme.dart';

/// Renders the guide at a tall-enough surface that every section is on screen,
/// so the section order can be compared without scrolling.
Future<void> _pumpGuide(WidgetTester tester, String councilSlug) async {
  tester.view.physicalSize = const Size(430, 2400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: BinGuideScreen(councilSlug: councilSlug),
  ));
  await tester.pumpAndSettle();
}

/// Asserts that [labels] are each rendered exactly once and appear top-to-bottom
/// in the given order.
///
/// Order is the point: the guide renders streams in the canonical order general,
/// recycling, garden, food, so the position of a label pins which waste stream
/// it was paired with. Merely finding "Burgundy bin" somewhere on screen would
/// still pass if it had been paired with the food stream instead.
Future<void> _expectOrder(WidgetTester tester, List<String> labels) async {
  var previousBottom = double.negativeInfinity;
  for (final label in labels) {
    final finder = find.text(label);
    expect(finder, findsOneWidget, reason: '"$label" should be rendered once');
    final topLeft = tester.getTopLeft(finder);
    final bottomRight = tester.getBottomRight(finder);
    expect(
      topLeft.dy,
      greaterThan(previousBottom),
      reason: '"$label" should be rendered below the previous section',
    );
    previousBottom = bottomRight.dy;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bolsover slug renders Bolsover\'s scheme, not Derby\'s',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGuide(tester, 'bolsover');

    // Bolsover: black refuse, burgundy recycling, green garden, brown food.
    await _expectOrder(
      tester,
      ['Black bin', 'Burgundy bin', 'Green bin', 'Brown food caddy'],
    );

    expect(find.text('Blue bin'), findsNothing,
        reason: 'Blue bin is Derby\'s recycling colour, not Bolsover\'s');
    expect(find.text('Green food caddy'), findsNothing,
        reason: 'Green food caddy is Derby\'s food colour, not Bolsover\'s');
    expect(find.text('Brown bin'), findsNothing,
        reason: 'Brown bin is Derby\'s garden colour, not Bolsover\'s');
  });

  testWidgets('passed slug is not overridden by the cached reminder slug',
      (tester) async {
    // This is the bug this file exists for. ReminderStore only wrote
    // cachedCouncilSlug when reminders were switched on, so a stale/absent cache
    // used to silently fall back to Derby for every non-Derby user.
    SharedPreferences.setMockInitialValues({'cachedCouncilSlug': 'derby'});
    await _pumpGuide(tester, 'bolsover');

    expect(find.text('Burgundy bin'), findsOneWidget,
        reason: 'constructor slug must win over the cached reminder slug');
    expect(find.text('Blue bin'), findsNothing);
  });

  testWidgets('Derby slug still renders Derby\'s scheme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGuide(tester, 'derby');

    await _expectOrder(
      tester,
      ['Black bin', 'Blue bin', 'Brown bin', 'Green food caddy'],
    );
  });
}