import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ThemeService extends ChangeNotifier {
  static const themeKey = 'theme_mode';
  final SharedPreferences _prefs;
  
  ThemeService(this._prefs);

  bool get isDarkMode => _prefs.getBool(themeKey) ?? false;

  Future<void> toggleTheme() async {
    await _prefs.setBool(themeKey, !isDarkMode);
    notifyListeners();
  }
}
