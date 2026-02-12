import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Supabase
  await Supabase.initialize(
    url: 'ТВОЙ_URL',
    anonKey: 'ТВОЙ_KEY',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fixly',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Стартуем всегда с проверки авторизации
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthCheck(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

// Виджет-контролер: решает куда направить пользователя при старте
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    // Проверяем, есть ли активная сессия (залогинен ли кто-то)
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Если никто не зашел — строго на логин
      return const LoginPage();
    } else {
      // Если сессия есть — идем на главную, она сама определит роль
      return const HomePage();
    }
  }
}