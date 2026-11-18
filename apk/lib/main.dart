import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/user.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/app_settings_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.init();
  await AppSettingsService.init();

  // Protect against blank white screen: register custom error widget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 48),
              const SizedBox(height: 14),
              const Text(
                'Application Display Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  // Safe dotenv load
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Notice: could not load .env asset: $e");
  }

  // Safe user session load
  AppUser? storedUser;
  try {
    storedUser = await ApiService.getStoredUser();
  } catch (e) {
    debugPrint("Notice: could not load stored user: $e");
  }

  runApp(MerkatoCreditApp(initialUser: storedUser));
}

class MerkatoCreditApp extends StatefulWidget {
  final AppUser? initialUser;

  const MerkatoCreditApp({super.key, this.initialUser});

  @override
  State<MerkatoCreditApp> createState() => _MerkatoCreditAppState();
}

class _MerkatoCreditAppState extends State<MerkatoCreditApp> {
  AppUser? _initialUser;

  @override
  void initState() {
    super.initState();
    _initialUser = widget.initialUser;
    LanguageService.currentLanguage.addListener(_onChanged);
    LanguageService.translationChanged.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MerkatoCreditApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initialUser = widget.initialUser;
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onChanged);
    LanguageService.translationChanged.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: LanguageService.t('appName'),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Accepts system bg color and text color
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );
        return child ?? const SizedBox();
      },
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: _initialUser != null
          ? MainScreen(currentUser: _initialUser!)
          : const LoginScreen(),
    );
  }
}
