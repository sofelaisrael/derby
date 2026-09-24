import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:derby_bins/main.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/services/onboarding_store.dart';
import 'package:derby_bins/services/reminder_store.dart';
import 'package:derby_bins/services/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    CouncilApi.client = http.Client();
  });

  testWidgets('calendar flow schedules reminders like the postcode flow',
      (tester) async {
    SharedPreferences.setMockInitialValues({'remindersEnabled': true});
    await OnboardingStore.setSeen();
    CouncilApi.client = MockClient((request) async {
      final url = request.url.toString();
      if (url.endsWith('/bins') || url.endsWith('/bins?')) {
        return http.Response(
            jsonEncode({
              'councils': [
                {
                  'id': 'NEDDC',
                  'name': 'North East Derbyshire District Council',
                  'slug': 'northeastderbyshire',
                  'calendarBased': true
                }
              ]
            }),
            200);
      }
      if (url.contains('council=northeastderbyshire') &&
          url.contains('postcode') &&
          !url.contains('uprn=')) {
        return http.Response(
            jsonEncode({
              'council': {
                'id': 'NEDDC',
                'name': 'North East Derbyshire District Council'
              },
              'addresses': [
                {
                  'uprn': 'calendar-a',
                  'label': 'Calendar A - The North',
                  'town': 'The North'
                },
                {
                  'uprn': 'calendar-b',
                  'label': 'Calendar B - The South',
                  'town': 'The South'
                }
              ]
            }),
            200);
      }
      if (url.contains('council=northeastderbyshire') &&
          url.contains('uprn=calendar-a')) {
        return http.Response(
            jsonEncode({
              'council': {
                'id': 'NEDDC',
                'name': 'North East Derbyshire District Council'
              },
              'collections': [
                {
                  'stream': 'general',
                  'dayOfWeek': 1,
                  'frequency': 'weekly',
                  'anchorDate': '2026-09-28'
                },
                {
                  'stream': 'recycling',
                  'dayOfWeek': 1,
                  'frequency': 'fortnightly',
                  'anchorDate': '2026-09-28'
                },
                {
                  'stream': 'food',
                  'dayOfWeek': 1,
                  'frequency': 'weekly',
                  'anchorDate': '2026-09-28'
                }
              ]
            }),
            200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(const BinApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing,
        reason: 'calendar-based councils must not show a postcode field');

    expect(find.text('Choose your bin calendar'), findsOneWidget,
        reason: 'calendar button should be shown for calendar-based councils');

    await tester.ensureVisible(find.text('Choose your bin calendar'));
    await tester.tap(find.text('Choose your bin calendar'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Choose your calendar'), findsOneWidget,
        reason: 'calendar picker screen should show');

    await tester.tap(find.text('Calendar A - The North'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('DerbyBins'), findsOneWidget,
        reason: 'home page should show after calendar selection');
    expect(find.text('Black bin'), findsWidgets,
        reason: 'home should show collection info');

    final slug = await ReminderStore.getCachedCouncilSlug();
    expect(slug, 'northeastderbyshire',
        reason: 'council slug must be cached for the reminder pipeline');

    final area = await ReminderStore.getCachedArea();
    expect(area, isNotNull,
        reason: 'area must be cached for the reminder pipeline');
    expect(area!.schedules, isNotEmpty,
        reason: 'cached area must contain schedules');

    final days = getNextCollectionDays(area, 8, DateTime.now());
    expect(days, isNotEmpty,
        reason: 'upcoming collection days must exist so reminders fire');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('postcode flow schedules reminders', (tester) async {
    SharedPreferences.setMockInitialValues({'remindersEnabled': true});
    await OnboardingStore.setSeen();
    CouncilApi.client = MockClient((request) async {
      final url = request.url.toString();
      if (url.endsWith('/bins') || url.endsWith('/bins?')) {
        return http.Response(
            jsonEncode({
              'councils': [
                {'id': 'DCC', 'name': 'Derby City Council', 'slug': 'derby'}
              ]
            }),
            200);
      }
      if (url.contains('council=derby') && url.contains('uprn=')) {
        return http.Response(
            jsonEncode({
              'council': {'id': 'DCC', 'name': 'Derby City Council'},
              'collections': [
                {
                  'stream': 'general',
                  'dayOfWeek': 5,
                  'frequency': 'weekly',
                  'anchorDate': '2026-07-24'
                }
              ]
            }),
            200);
      }
      if (url.contains('council=derby') &&
          url.contains('postcode=') &&
          !url.contains('uprn=')) {
        return http.Response(
            jsonEncode({
              'council': {'id': 'DCC', 'name': 'Derby City Council'},
              'addresses': [
                {'uprn': 'UPRN123', 'label': '1 Test Street, Derby, DE1 1AA'}
              ]
            }),
            200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(const BinApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'DE1 1AA');
    await tester.ensureVisible(find.text('Find my bins'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find my bins'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Choose your address'), findsOneWidget,
        reason: 'picker should show after first lookup');

    await tester.tap(find.text('DE1 1AA'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('DerbyBins'), findsOneWidget,
        reason: 'home page should show');
    expect(find.text('Black bin'), findsWidgets,
        reason: 'home should show collection info');

    final slug = await ReminderStore.getCachedCouncilSlug();
    expect(slug, 'derby',
        reason: 'council slug must be cached for the reminder pipeline');

    final area = await ReminderStore.getCachedArea();
    expect(area, isNotNull,
        reason: 'area must be cached for the reminder pipeline');
    expect(area!.schedules, isNotEmpty,
        reason: 'cached area must contain schedules');

    final days = getNextCollectionDays(area, 8, DateTime.now());
    expect(days, isNotEmpty,
        reason: 'upcoming collection days must exist so reminders fire');
  }, timeout: const Timeout(Duration(seconds: 60)));
}