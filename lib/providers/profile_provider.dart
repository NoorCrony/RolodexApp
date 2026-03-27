import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that stores and retrieves the user's profile details
/// using SharedPreferences (persisted locally on device).
class ProfileProvider with ChangeNotifier {
  static const _keyName  = 'profile_name';
  static const _keyRole  = 'profile_role';
  static const _keyPhone = 'profile_phone';

  String _name  = '';
  String _role  = '';
  String _phone = '';

  String get name  => _name.isNotEmpty  ? _name  : 'Your Name';
  String get role  => _role.isNotEmpty  ? _role  : 'Sales Executive';
  String get phone => _phone;

  /// Initial letter(s) for the avatar.
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Load saved profile from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _name  = prefs.getString(_keyName)  ?? '';
    _role  = prefs.getString(_keyRole)  ?? '';
    _phone = prefs.getString(_keyPhone) ?? '';
    notifyListeners();
  }

  /// Save updated profile.
  Future<void> update({
    required String name,
    required String role,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName,  name);
    await prefs.setString(_keyRole,  role);
    await prefs.setString(_keyPhone, phone);
    _name  = name;
    _role  = role;
    _phone = phone;
    notifyListeners();
  }
}
