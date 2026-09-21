import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';
import 'services/onboarding_store.dart';
import 'services/session_store.dart';
import 'screens/onboarding_screen.dart';
import 'screens/postcode_input_screen.dart';
import 'screens/home_page.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const DerbyBinsApp());
}

class DerbyBinsApp extends StatelessWidget {
  const DerbyBinsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Derby Bins',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeService.themeMode,
            home: const AppStartup(),
            routes: {
              '/postcode': (_) => const PostcodeInputScreen(),
              '/home': (_) => const HomePage(),
              '/calendar': (_) => const CalendarScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/report': (_) => const ReportScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Checks onboarding status and routes accordingly.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final onboardingStore = OnboardingStore();
    final sessionStore = SessionStore();

    final onboardingComplete = await onboardingStore.isComplete();
    final hasSession = await sessionStore.hasSession();

    if (!mounted) return;

    Widget destination;
    if (!onboardingComplete) {
      destination = const OnboardingScreen();
    } else if (!hasSession) {
      destination = const PostcodeInputScreen();
    } else {
      destination = const HomePage();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
