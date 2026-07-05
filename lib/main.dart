import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:patient_app/core/services/notification_service.dart';
import 'package:patient_app/core/services/socket_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/core/theme/theme_provider.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & notifications only on native mobile platforms
  if (!kIsWeb) {
    await Firebase.initializeApp();
    await NotificationService.init();
  } else {
    debugPrint('Running on Web: Skipping mobile push notifications init.');
  }

  // Connect to socket in background if enabled
  await SocketService.connect();

  runApp(
    const ProviderScope(
      child: ScanGoPatientApp(),
    ),
  );
}

class ScanGoPatientApp extends ConsumerWidget {
  const ScanGoPatientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Update system UI overlay style based on active theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp.router(
      title: 'ScanGo | سكان جو',
      // Light mode — default, warm cream for patient trust
      theme: AppTheme.lightTheme,
      // Dark mode — deep navy for night comfort
      darkTheme: AppTheme.darkTheme,
      // Controlled by the persisted user preference
      themeMode: themeMode,
      locale: const Locale('ar', 'EG'),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
