import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/services/socket_service.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      title: 'ScanGo | أشعتك',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          background: const Color(0xFF0B0F19),
        ),
        useMaterial3: true,
        fontFamily: 'Cairo', // Localized font mapping
      ),
      locale: const Locale('ar', 'EG'),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
