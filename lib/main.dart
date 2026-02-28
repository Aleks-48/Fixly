import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// Импорты твоих файлов
import 'package:fixly_app/theme_notifier.dart';
import 'package:fixly_app/screens/login_page.dart';
import 'package:fixly_app/screens/register_page.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'firebase_options.dart';

// Глобальные переменные
final ValueNotifier<String> appLanguage = ValueNotifier<String>('ru');
final ValueNotifier<String> userRole = ValueNotifier<String>('user');
final ValueNotifier<double> userRating = ValueNotifier<double>(0.0);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

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
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }
}

Future<void> initAppPermissions() async {
  await [Permission.camera, Permission.microphone, Permission.notification].request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://wqxzraqzonyxnsrlysyt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxeHpyYXF6b255eG5zcmx5c3l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4MzM5ODAsImV4cCI6MjA4NTQwOTk4MH0.ZhrKi9Ko1dJzyDGzpzVN53EKd1XC7mdyWUcHJl_qHu4',
  );

  unawaited(initAppPermissions());

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MainWrapper(),
        '/masters': (context) => const MastersListScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void> _initUser(String uid) async {
    final client = Supabase.instance.client;
    final res = await client.from('profiles').select().eq('id', uid).maybeSingle();
    if (res != null) {
      userRole.value = res['role'] ?? 'user';
      userRating.value = (res['avg_rating'] as num?)?.toDouble() ?? 0.0;
    }
    await saveTokenToSupabase();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session != null) {
          _initUser(session.user.id);
          return const MainWrapper();
        }
        return const LoginPage();
      },
    );
  }
}