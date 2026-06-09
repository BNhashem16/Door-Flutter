import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './auth/app_lock.dart';
import './auth/auth_gate.dart';
import './auth/auth_service.dart';
import './gate/gate_widget_callback.dart';
import './l10n/app_strings.dart';
import './l10n/locale_scope.dart';
import './l10n/locale_store.dart';
import './theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load Brevo (and other) secrets from the bundled .env asset. Non-fatal if
  // missing — BrevoConfig.isConfigured then stays false and OTP send returns
  // OtpError instead of crashing.
  try {
    await dotenv.load(fileName: '.env');
  } on Exception {
    // .env absent or unreadable; BrevoConfig.isConfigured stays false and OTP
    // send returns OtpError instead of crashing.
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline persistence: the user profile loads instantly from the on-disk
  // cache on later launches instead of blocking on a network round-trip, so
  // returning users skip the splash spinner. Must run before any DB access.
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: AuthService.databaseUrl,
  ).setPersistenceEnabled(true);
  // Route home-screen widget taps to the headless gate toggle callback.
  HomeWidget.registerInteractivityCallback(gateWidgetTapped);
  final locale = await LocaleStore.initial();
  runApp(MyApp(initialLocale: locale));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialLocale});

  final Locale initialLocale;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late Locale _locale = widget.initialLocale;
  final _authService = AuthService();

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _toggleLocale() {
    final next =
        _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    setState(() => _locale = next);
    LocaleStore.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: _locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Wrap the Navigator (not just `home`) so LocaleScope is reachable from
      // every route — including pushed routes like RegisterScreen. Wrapping
      // `home` alone left pushed routes above the scope and crashed
      // LanguageToggleButton with a null LocaleScope.
      builder: (context, child) => LocaleScope(
        locale: _locale,
        onToggle: _toggleLocale,
        child: child!,
      ),
      home: AppLock(
        authService: _authService,
        child: AuthGate(
          onThemeToggle: _toggleTheme,
          isDarkMode: _isDarkMode,
          onLocaleToggle: _toggleLocale,
        ),
      ),
    );
  }
}
