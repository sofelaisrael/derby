import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/screens/bin_guide_screen.dart';
import 'package:derby_bins/screens/calendar_view_screen.dart';
import 'package:derby_bins/screens/home_page.dart';
import 'package:derby_bins/screens/onboarding_screen.dart';
import 'package:derby_bins/screens/settings_tab.dart';
import 'package:derby_bins/services/weather_service.dart';
import 'package:derby_bins/theme/app_theme.dart';

Future<void> _loadRealFonts() async {
  const weights = {
    400: 'assets/fonts/PlusJakartaSans-400.ttf',
    500: 'assets/fonts/PlusJakartaSans-500.ttf',
    600: 'assets/fonts/PlusJakartaSans-600.ttf',
    700: 'assets/fonts/PlusJakartaSans-700.ttf',
    800: 'assets/fonts/PlusJakartaSans-800.ttf',
  };
  for (final path in weights.values) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

AreaSchedule _sampleArea() => AreaSchedule(
      postcode: 'DE1 1AA',
      areaName: '1 Test Street, Derby',
      council: 'Derby City Council',
      schedules: [
        BinSchedule(
          stream: WasteStream.recycling,
          dayOfWeek: 4,
          frequency: Frequency.fortnightly,
          anchorDate: DateTime(2026, 9, 24),
        ),
        BinSchedule(
          stream: WasteStream.general,
          dayOfWeek: 7,
          frequency: Frequency.weekly,
          anchorDate: DateTime(2026, 9, 27),
        ),
        BinSchedule(
          stream: WasteStream.garden,
          dayOfWeek: 3,
          frequency: Frequency.fortnightly,
          anchorDate: DateTime(2026, 9, 30),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadRealFonts();
  });

  final now = DateTime(2026, 9, 24);
  final area = _sampleArea();
  const previewWeather = WeatherBundle(
    now: WeatherData(
      temperature: 14,
      weatherCode: 2,
      condition: 'Partly Cloudy',
      willRain: false,
    ),
  );

  Future<void> setSurface(WidgetTester tester, Size logical, double dpr) async {
    tester.view.physicalSize = logical * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('home page iPhone screenshot', (tester) async {
    await setSurface(tester, const Size(430, 932), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HomePage(
          postcode: 'DE1 1AA',
          councilSlug: 'derby',
          councilName: 'Derby City Council',
          addressLabel: '1 Test Street, Derby',
          area: area,
          isLive: false,
          now: now,
          weatherOverride: previewWeather,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile('store_screenshots/home_iphone.png'),
    );
  });

  testWidgets('home page Android screenshot', (tester) async {
    await setSurface(tester, const Size(411, 915), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HomePage(
          postcode: 'DE1 1AA',
          councilSlug: 'derby',
          councilName: 'Derby City Council',
          addressLabel: '1 Test Street, Derby',
          area: area,
          isLive: false,
          now: now,
          weatherOverride: previewWeather,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile('store_screenshots/home_android.png'),
    );
  });

  testWidgets('calendar iPhone screenshot', (tester) async {
    await setSurface(tester, const Size(430, 932), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: CalendarViewScreen(
        area: area,
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        postcode: 'DE1 1AA',
        addressLabel: '1 Test Street',
        now: now,
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CalendarViewScreen),
      matchesGoldenFile('store_screenshots/calendar_iphone.png'),
    );
  });

  testWidgets('calendar Android screenshot', (tester) async {
    await setSurface(tester, const Size(411, 915), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: CalendarViewScreen(
        area: area,
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        postcode: 'DE1 1AA',
        addressLabel: '1 Test Street',
        now: now,
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CalendarViewScreen),
      matchesGoldenFile('store_screenshots/calendar_android.png'),
    );
  });

  void mockBatteryChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('derbybins/battery'),
      (call) async {
        if (call.method == 'isIgnoringBatteryOptimizations') return false;
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('derbybins/battery'),
        null,
      );
    });
  }

  testWidgets('onboarding iPhone screenshot', (tester) async {
    await setSurface(tester, const Size(430, 932), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: OnboardingScreen(onDone: () {}, themeService: null),
    ));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/illustrations/onboarding_step0.png'),
        tester.element(find.byType(OnboardingScreen)),
      );
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('store_screenshots/onboarding_iphone.png'),
    );
  });

  testWidgets('onboarding Android screenshot', (tester) async {
    await setSurface(tester, const Size(411, 915), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: OnboardingScreen(onDone: () {}, themeService: null),
    ));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/illustrations/onboarding_step0.png'),
        tester.element(find.byType(OnboardingScreen)),
      );
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('store_screenshots/onboarding_android.png'),
    );
  });

  testWidgets('reminders iPhone screenshot', (tester) async {
    SharedPreferences.setMockInitialValues({'remindersEnabled': true});
    mockBatteryChannel();
    await setSurface(tester, const Size(430, 932), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: SettingsTab(
        postcode: 'DE1 1AA',
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        addressLabel: '1 Test Street, Derby',
        area: area,
        isLive: true,
        themeService: null,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable reminders'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsTab),
      matchesGoldenFile('store_screenshots/reminders_iphone.png'),
    );
  });

  testWidgets('reminders Android screenshot', (tester) async {
    SharedPreferences.setMockInitialValues({'remindersEnabled': true});
    mockBatteryChannel();
    await setSurface(tester, const Size(411, 915), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: SettingsTab(
        postcode: 'DE1 1AA',
        councilSlug: 'derby',
        councilName: 'Derby City Council',
        addressLabel: '1 Test Street, Derby',
        area: area,
        isLive: true,
        themeService: null,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable reminders'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsTab),
      matchesGoldenFile('store_screenshots/reminders_android.png'),
    );
  });

  testWidgets('bin guide iPhone screenshot', (tester) async {
    SharedPreferences.setMockInitialValues({'cachedCouncilSlug': 'derby'});
    await setSurface(tester, const Size(430, 932), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const BinGuideScreen(),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BinGuideScreen),
      matchesGoldenFile('store_screenshots/binguide_iphone.png'),
    );
  });

  testWidgets('bin guide Android screenshot', (tester) async {
    SharedPreferences.setMockInitialValues({'cachedCouncilSlug': 'derby'});
    await setSurface(tester, const Size(411, 915), 3.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const BinGuideScreen(),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BinGuideScreen),
      matchesGoldenFile('store_screenshots/binguide_android.png'),
    );
  });
}
