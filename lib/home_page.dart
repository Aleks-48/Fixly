import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  // ТА САМАЯ СИСТЕМА ОПРЕДЕЛЕНИЯ КТО ЗАШЕЛ
  Future<void> _checkRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      
      if (mounted) {
        setState(() {
          role = data['role']; // 'chairman' или 'contractor'
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        // Заголовок меняется в зависимости от роли
        title: Text(role == 'chairman' ? 'Панель ОСИ' : 'Заказы Подрядчика'),
        actions: [
          // Кнопка выхода, чтобы вернуться к регистрации
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              role == 'chairman' ? LucideIcons.building : LucideIcons.hardHat,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              "Добро пожаловать, ${role == 'chairman' ? 'Председатель' : 'Подрядчик'}!",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
      // Кнопка добавления заявок видна ТОЛЬКО для ОСИ
      floatingActionButton: role == 'chairman' 
        ? FloatingActionButton(
            onPressed: () {
              // Здесь будет вызов диалога создания заявки
            },
            child: const Icon(LucideIcons.plus),
          )
        : null,
    );
  }
}