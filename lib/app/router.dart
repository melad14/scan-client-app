import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/order_create/order_wizard_screen.dart';
import '../features/order_detail/order_detail_screen.dart';
import 'package:patient_app/core/services/storage_service.dart';
import 'package:patient_app/core/services/notification_service.dart';

final GoRouter appRouter = GoRouter(
  // Wire the global navigator key so NotificationService can navigate
  navigatorKey: notificationNavigatorKey,
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final token = await StorageService.getAccessToken();
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (token == null && !isLoggingIn) {
      return '/login';
    }
    
    if (token != null && isLoggingIn) {
      return '/';
    }
    
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/orders/create',
      builder: (BuildContext context, GoRouterState state) {
        final category = state.uri.queryParameters['category'] ?? 'xray';
        return OrderWizardScreen(category: category);
      },
    ),
    GoRoute(
      path: '/orders/:orderId', // Deep linking configuration for notification redirection
      builder: (BuildContext context, GoRouterState state) {
        final orderId = state.pathParameters['orderId']!;
        return OrderDetailScreen(orderId: orderId);
      },
    ),
  ],
);
