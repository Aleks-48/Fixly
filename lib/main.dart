import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixly_app/theme_notifier.dart';
import 'package:fixly_app/screens/login_page.dart';
import 'package:fixly_app/screens/register_page.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'firebase_options.dart';

// Глобальные нотификаторы для быстрого доступа из любой точки приложения
final ValueNotifier<String> appLanguage = ValueNotifier<String>('ru');
final ValueNotifier<String> userRole = ValueNotifier<String>('resident'); // По умолчанию житель
final ValueNotifier<double> userRating = ValueNotifier<double>(0.0);

/// Функция для смены языка с сохранением в память устройства (SharedPreferences)
Future<void> changeLanguage(String newLang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_lang', newLang);
  appLanguage.value = newLang;
}

/// Обработчик фоновых уведомлений Firebase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Сохранение токена уведомлений в Supabase для конкретного пользователя
Future<void> saveTokenToSupabase() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user != null) {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint("FCM Token успешно сохранен для пользователя: ${user.id}");
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация сервисов
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance().then((prefs) {
      final String? savedLang = prefs.getString('saved_lang');
      if (savedLang != null) {
        appLanguage.value = savedLang;
      }
    }),
  ]);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Конфигурация Supabase
  await Supabase.initialize(
    url: 'https://wqxzraqzonyxnsrlysyt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxeHpyYXF6b255eG5zcmx5c3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4MzM5ODAsImV4cCI6MjA4NTQwOTk4MH0.ZhrKi9Ko1dJzyDGzpzVN53EKd1XC7mdyWUcHJl_qHu4',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    
    return MaterialApp(
      title: 'Fixly',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        useMaterial3: true, 
        brightness: Brightness.light, 
        colorSchemeSeed: Colors.blue,
        fontFamily: 'Inter', // Если добавишь шрифты позже
      ),
      darkTheme: ThemeData(
        useMaterial3: true, 
        brightness: Brightness.dark, 
        colorSchemeSeed: Colors.blue,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginPage();
            break;
          case '/register':
            page = const RegisterPage();
            break;
          case '/home':
            page = const MainWrapper();
            break;
          case '/masters':
            page = const MastersListScreen();
            break;
          default:
            page = const AuthGate();
        }
        return MaterialPageRoute(
          builder: (context) => page, 
          settings: settings,
        );
      },
    );
  }
}

/// Виджет проверки авторизации (Gate)
/// Решает, показать экран логина или главный экран приложения
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // Функция для обновления глобальной роли пользователя при входе
  Future<void> _updateGlobalUserRole(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      if (data != null && data['role'] != null) {
        userRole.value = data['role'];
      }
    } catch (e) {
      debugPrint("Ошибка обновления роли в AuthGate: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Состояние загрузки
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }
        
        final session = snapshot.data?.session;
        
        if (session != null) {
          // Если сессия есть:
          // 1. Сохраняем токен для пушей
          Future.microtask(() => saveTokenToSupabase());
          // 2. Обновляем роль, чтобы MainWrapper сразу знал, что рисовать
          _updateGlobalUserRole(session.user.id);
          
          return const MainWrapper();
        } else {
          // Если сессии нет — на страницу входа
          return const LoginPage();
        }
      },
    );
  }
}