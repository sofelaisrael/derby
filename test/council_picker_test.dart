import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:derby_bins/screens/postcode_input_screen.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _body(List<Map<String, Object>> councils) =>
    jsonEncode({'councils': councils});

int _staleTimestamp() =>
    DateTime.now().millisecondsSinceEpoch -
    const Duration(hours: 25).inMilliseconds;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CouncilApi.client = http.Client();
  });

  testWidgets('council picker lists councils before the network responds',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<http.Response>();
    CouncilApi.client = MockClient((_) => pending.future);

    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const PostcodeInputScreen()));
    await tester.pump(const Duration(milliseconds: 2000));

    expect(find.text('Derby City Council'), findsOneWidget,
        reason: 'a council should be selected before the network responds');

    await tester.ensureVisible(find.text('Your council'));
    await tester.tap(find.text('Your council'));
    await tester.pumpAndSettle();

    expect(find.text('Select council'), findsOneWidget);
    expect(find.text('Erewash Borough Council'), findsOneWidget,
        reason: 'the picker must not open empty');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a non-empty list must not be held back by a spinner');
    expect(find.text('Try again'), findsNothing,
        reason: 'a non-empty list must not offer a retry');

    pending.complete(http.Response('{}', 500));
    await tester.pumpAndSettle();

    expect(find.text('Erewash Borough Council'), findsOneWidget,
        reason: 'a failed refresh must not blank the picker');
  });

  test('the immediate list applies calendar flags without a network call', () {
    SharedPreferences.setMockInitialValues({});

    final councils = CouncilApi.cachedCouncils();

    expect(councils, isNotEmpty);
    expect(
        councils.firstWhere((c) => c.slug == 'bolsover').calendarBased, isTrue);
    expect(
        councils
            .firstWhere((c) => c.slug == 'northeastderbyshire')
            .calendarBased,
        isTrue);
    expect(
        councils.firstWhere((c) => c.slug == 'derby').calendarBased, isFalse);
  });

  test('a refresh persists the network list and reuses it inside the cache ttl',
      () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    CouncilApi.client = MockClient((_) async {
      calls++;
      return http.Response(
          _body([
            {'id': 'DCC', 'name': 'Derby City Council', 'slug': 'derby'},
            {'id': 'XDC', 'name': 'Extra District Council', 'slug': 'extra'},
          ]),
          200);
    });

    final first = await CouncilApi.refreshCouncils();
    expect(first!.map((c) => c.slug), contains('extra'));
    expect(calls, 1);

    final second = await CouncilApi.refreshCouncils();
    expect(second!.map((c) => c.slug), contains('extra'));
    expect(calls, 1, reason: 'a list inside the ttl must not hit the network');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('council_list_ts', _staleTimestamp());

    final third = await CouncilApi.refreshCouncils();
    expect(third!.map((c) => c.slug), contains('extra'));
    expect(calls, 2, reason: 'a stale list must be refreshed');
  });

  test('a stale stored list outranks the fallback and a failure keeps it',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'council_list_data',
        _body([
          {'id': 'XDC', 'name': 'Extra District Council', 'slug': 'extra'}
        ]));
    await prefs.setInt('council_list_ts', _staleTimestamp());

    CouncilApi.client = MockClient((_) async => http.Response('{}', 500));

    final primed = await CouncilApi.primeCouncilCache();
    expect(primed.map((c) => c.slug), contains('extra'),
        reason: 'a stale stored list must beat the hardcoded fallback');

    final refreshed = await CouncilApi.refreshCouncils();
    expect(refreshed, isNull,
        reason: 'a failed fetch must be reported as null');

    expect(CouncilApi.cachedCouncils().map((c) => c.slug), contains('extra'),
        reason: 'a failed fetch must not blank the list');
  });
}
