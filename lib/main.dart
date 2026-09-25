import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'screens/calendar_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/postcode_input_screen.dart';
import 'services/notification_service.dart';
import 'services/onboarding_store.dart';
import 'services/session_store.dart';
import 'services/theme_service.dart';

const String appName = 'Derby Bins';
const String supportedCouncilsText =
    'Covers Derby City, Erewash, Amber Valley, High Peak, Derbyshire Dales, Bolsover, Chesterfield, South Derbyshire & North East Derbyshire. More councils coming soon.';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  await NotificationService.init();
  await NotificationService.configureBackgroundFetch();
  runApp(const BinApp());
}

class BinApp extends StatefulWidget {
  const BinApp({super.key});

  @override
  State<BinApp> createState() => _BinAppState();
}

class _BinAppState extends State<BinApp> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _themeService.removeListener(() {});
    _themeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _themeService.theme,
      home: _AppHome(themeService: _themeService),
    );
  }
}

class _AppHome extends StatefulWidget {
  final ThemeService themeService;
  const _AppHome({required this.themeService});

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> with WidgetsBindingObserver {
  late Future<Widget> _homeFuture;
  StreamSubscription<String?>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeFuture = _decideHome();
    _notificationSub = NotificationService.onNotifications.listen((payload) {
      // Notification tapped — no deep-link action needed.
      // App opens to the default home screen.
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<Widget> _decideHome() async {
    // A saved session means the app was set up before. Prefer it over the
    // onboarding flag so a lost/cleared flag (e.g. after an app update) never
    // forces a returning user back through onboarding.
    final session = await SessionStore.load();
    if (session != null) {
      return CalendarScreen(
        postcode: session.postcode,
        councilSlug: session.councilSlug,
        councilName: session.councilName,
        uprn: session.uprn,
        addressLabel: session.addressLabel,
        themeService: widget.themeService,
      );
    }
    if (!await OnboardingStore.hasSeen()) {
      return OnboardingScreen(
        themeService: widget.themeService,
        onDone: _refreshHome,
      );
    }
    return PostcodeInputScreen(themeService: widget.themeService);
  }

  void _refreshHome() {
    setState(() {
      _homeFuture = _decideHome();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.maybeRescheduleIfExactAlarmGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
