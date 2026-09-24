import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derby_bins/screens/address_picker_screen.dart';
import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/theme/app_theme.dart';

void main() {
  testWidgets('address picker uses readable count subtitles',
      (WidgetTester tester) async {
    const postcode = 'DE1 1AA';
    const singularAddresses = [
      CouncilAddress(uprn: '1', label: '1 Test Street, Derby'),
    ];
    const pluralAddresses = [
      CouncilAddress(uprn: '1', label: '1 Test Street, Derby'),
      CouncilAddress(uprn: '2', label: '2 Test Street, Derby'),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AddressPickerScreen(
        postcode: postcode,
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        addresses: singularAddresses,
      ),
    ));
    await tester.pump();
    expect(find.text('1 address found - $postcode'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AddressPickerScreen(
        postcode: postcode,
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        addresses: pluralAddresses,
      ),
    ));
    await tester.pump();
    expect(find.text('2 addresses found - $postcode'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AddressPickerScreen(
        postcode: postcode,
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        addresses: pluralAddresses,
        isCalendar: true,
      ),
    ));
    await tester.pump();
    expect(find.text('2 calendars · Derby City Council'), findsOneWidget);
  });

  test('calendar integration config declares required native access', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final queriesMatch = RegExp(
      r'<queries\b[^>]*>([\s\S]*?)</queries>',
    ).firstMatch(manifest);
    expect(queriesMatch, isNotNull);
    final queries = queriesMatch!.group(1)!;
    expect(queries, contains('android.intent.action.PROCESS_TEXT'));

    final insertIntentMatch = RegExp(
      r'<intent\s*>\s*<action\s+[^>]*android:name\s*=\s*"android\.intent\.action\.INSERT"[^>]*\s*/>\s*<data\s+[^>]*android:mimeType\s*=\s*"vnd\.android\.cursor\.dir/event"[^>]*\s*/>\s*</intent\s*>',
    ).firstMatch(queries);
    expect(insertIntentMatch, isNotNull);

    final plugin = File(
      'third_party/add_2_calendar/android/src/main/kotlin/com/javih/add_2_calendar/Add2CalendarPlugin.kt',
    ).readAsStringSync();
    expect(plugin, isNot(contains('resolveActivity')));
    final tryCatchMatch = RegExp(
      r'try\s*\{[\s\S]*?mContext\s*\.\s*startActivity\s*\(\s*intent\s*\)[\s\S]*?return\s+true[\s\S]*?\}\s*catch\s*\(\s*_:\s*ActivityNotFoundException\s*\)\s*\{[\s\S]*?return\s+false[\s\S]*?\}',
    ).firstMatch(plugin);
    expect(tryCatchMatch, isNotNull);

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final usageDescriptionMatches = RegExp(
      r'<key>\s*(NSCalendars\w*UsageDescription)\s*</key>\s*<string>\s*(.*?)\s*</string>',
      dotAll: true,
    ).allMatches(plist).toList();
    expect(
      usageDescriptionMatches.map((match) => match.group(1)),
      containsAll(<String>{
        'NSCalendarsUsageDescription',
        'NSCalendarsFullAccessUsageDescription',
      }),
    );
    for (final match in usageDescriptionMatches) {
      expect(match.group(1), isNotEmpty);
      expect(match.group(2)!.trim(), isNotEmpty);
    }
  });
}
