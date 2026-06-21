import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/services/socket_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Light status bar for light theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Connect to socket in background if enabled
  await SocketService.connect();

  runApp(
    const ProviderScope(
      child: ScanGoPatientApp(),
    ),
  );
}

class ScanGoPatientApp extends StatelessWidget {
  const ScanGoPatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ScanGo | سكان جو',
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
