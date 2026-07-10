import 'package:flutter/foundation.dart';

class Constants {
  // Base API URLs dynamically detected
  static String get _baseUrl => 'https://scan-backend-nine.vercel.app';

  static String get apiBaseUrl => '$_baseUrl/api/v1';
  static String get socketUrl => _baseUrl;

  // ─── Patient Auth Endpoints ─────────────────────────────────────────────────
  static const String patientRegister = '/auth/patient/register';
  static const String patientLogin = '/auth/patient/login';

  // ─── Shared Auth Endpoints ──────────────────────────────────────────────────
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // ─── Technician Auth (used by tech_app) ─────────────────────────────────────
  static const String loginTech = '/auth/technician/login';

  // ─── Patient App Endpoints ──────────────────────────────────────────────────
  static const String services = '/services';
  static const String categories = '/categories';
  static const String orders = '/orders';
  static const String ordersHistory = '/orders/history';
  static const String savedPatients = '/patients/saved';
  static const String savedAddresses = '/addresses/saved';

  // ─── Technician App Endpoints ────────────────────────────────────────────────
  static const String techAvailableOrders = '/technician/orders/available';
  static const String techActiveOrder = '/technician/orders/active';
  static const String techOrdersHistory = '/technician/orders/history';
  static const String techLocation = '/technician/location';
  static const String techAvailability = '/technician/availability';

  // ─── Profile ─────────────────────────────────────────────────────────────────
  static const String profile = '/profile';
}

class FeatureFlags {
  // Flag controls whether live tracking map moves via socket
  static const bool realtimeTracking =
      bool.fromEnvironment('REALTIME_TRACKING_ENABLED', defaultValue: false);
}
