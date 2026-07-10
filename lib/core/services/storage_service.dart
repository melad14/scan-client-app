import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyAccessToken = 'accessToken';
  static const String _keyRefreshToken = 'refreshToken';
  static const String _keyUserRole = 'userRole';
  static const String _keyUserData = 'userData';
  static const String _keyCachedOrders = 'cachedOrders';

  // Persistence getters
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRefreshToken, token);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_keyUserData);
    if (dataStr == null) return null;
    return jsonDecode(dataStr) as Map<String, dynamic>;
  }

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(data));
  }

  static Future<List<dynamic>?> getCachedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_keyCachedOrders);
    if (dataStr == null) return null;
    return jsonDecode(dataStr) as List<dynamic>;
  }

  static Future<void> saveCachedOrders(List<dynamic> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedOrders, jsonEncode(orders));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserData);
    await prefs.remove(_keyCachedOrders);
  }
}
