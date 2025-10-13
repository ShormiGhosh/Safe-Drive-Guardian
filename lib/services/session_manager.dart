

import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserEmail = 'userEmail';
  static const String _keyUserType = 'userType';
  static const String _keyUserId = 'userId';

  static Future<void> saveLoginSession({
    required String email,
    required String userId,
    required bool isPolice,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserId, userId);
    await prefs.setBool(_keyUserType, isPolice);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<bool> isPoliceUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUserType) ?? false;
  }
}