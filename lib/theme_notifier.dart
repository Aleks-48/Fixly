import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  // По умолчанию ставим системную или светлую
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    _loadFromPrefs(); // Загружаем при старте
  }

  // Главный метод переключения
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    // ЭТО САМАЯ ВАЖНАЯ СТРОЧКА: она заставляет MaterialApp перерисоваться
    notifyListeners(); 

    // Сохраняем в память
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  // Загрузка из памяти
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode');
    
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners(); // Сообщаем main.dart, что мы нашли сохраненную тему
    }
  }
}