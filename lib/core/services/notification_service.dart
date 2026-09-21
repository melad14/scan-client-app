import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:dr_ray/core/api/api_client.dart';
import 'package:dr_ray/core/services/storage_service.dart';

// ─── Global navigator key — used to navigate from notification taps ──────────
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

// ─── High-importance Android notification channel ────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'drray_high_importance',
  'Dr Ray Notifications',
  description: 'إشعارات تطبيق Dr Ray للخدمات الطبية المنزلية',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

// ─── Local notifications plugin instance ─────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  // Real-time foreground notification event notifier
  static final ValueNotifier<RemoteMessage?> onNotificationReceived =
      ValueNotifier<RemoteMessage?>(null);

  // ── Init (called once at app startup, after Firebase.initializeApp) ─────────
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      // 1. Register background handler FIRST (before any other FCM setup)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Set up local notifications (for foreground display)
      await _initLocalNotifications();

      // 3. Foreground messages → show as local notification & trigger local real-time callback
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        onNotificationReceived.value = message;
        _showLocalNotification(message);
      });

      // 4. Background tap → navigate when app resumes
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // 5. Terminated state tap → app was cold-started from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Small delay to let the router finish mounting
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // 6. Auto-refresh token when Firebase rotates it
      _messaging.onTokenRefresh.listen((String token) async {
        await _sendTokenToServer(token);
      });
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  // ── Initialize FlutterLocalNotifications ────────────────────────────────────
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Tapped a foreground local notification → navigate
        if (response.payload != null && response.payload!.isNotEmpty) {
          final parts = response.payload!.split('|');
          final type = parts.isNotEmpty ? parts[0] : '';
          final orderId = parts.length > 1 ? parts[1] : response.payload!;
          _handleNotificationTap({'orderId': orderId, 'type': type});
        }
      },
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Show a local notification banner (foreground) ───────────────────────────
  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final orderId = message.data['orderId'] ?? '';
    final type = message.data['type'] ?? '';

    _localNotifications.show(
      id: (message.messageId ?? '').hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      // Carry the type too, so a foreground tap can reach the right screen
      payload: '$type|$orderId',
    );
  }

  static bool _isNavigating = false;

  // ── Navigate to the relevant screen based on notification data ──────────────
  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (_isNavigating) return;
    _isNavigating = true;
    Future.delayed(const Duration(milliseconds: 1500), () {
      _isNavigating = false;
    });

    final orderId = data['orderId'] as String?;
    final context = notificationNavigatorKey.currentContext;
    if (context == null) return;

    if (orderId != null && orderId.isNotEmpty) {
      final type = data['type']?.toString() ?? '';
      final target = type == 'new_message' ? '/orders/$orderId/chat' : '/orders/$orderId';
      final currentRoute = GoRouterState.of(context).matchedLocation;
      if (currentRoute != target) {
        GoRouter.of(context).push(target);
      }
    } else {
      GoRouter.of(context).go('/');
    }
  }

  // ── Request permission + register FCM token with backend ────────────────────
  /// True when the user has refused the Android 13+ notification permission.
  static final ValueNotifier<bool> notificationsBlocked =
      ValueNotifier<bool>(false);

  static Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final denied =
          settings.authorizationStatus == AuthorizationStatus.denied;
      notificationsBlocked.value = denied;
      if (denied) {
        debugPrint('[NotificationService] Permission denied by user');
      }

      // Always register the token even when permission is denied — in-app
      // notifications still work, and pushes start as soon as the user
      // re-enables notifications from Settings.
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[NotificationService] registerDeviceToken error: $e');
    }
  }

  /// This device's token — sent with /auth/logout so only this device is forgotten.
  static Future<String?> currentToken() async {
    if (kIsWeb) return null;
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  // ── Send FCM token to ScanGo backend ────────────────────────────────────────
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('[NotificationService] Not authenticated — skipping token upload');
        return;
      }

      final client = ApiClient();
      final response = await client.dio.put(
        '/auth/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        debugPrint('[NotificationService] FCM token updated on server ✅');
      }
    } catch (e) {
      debugPrint('[NotificationService] _sendTokenToServer error: $e');
    }
  }
}

// ─── Background message handler — MUST be a top-level function ───────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[NotificationService] Background message: ${message.messageId}');
}
