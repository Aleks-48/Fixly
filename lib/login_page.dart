import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // Выполняем вход через Supabase
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // ИСПРАВЛЕНИЕ: Проверка mounted перед использованием context
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добро пожаловать в Fixly!'), 
          backgroundColor: Colors.green
        ),
      );

      // ПЕРЕХОД на главный экран
      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: Неверный логин или пароль'), 
          backgroundColor: Colors.red
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.wrench, size: 80, color: Color(0xFF3B82F6)),
              const SizedBox(height: 20),
              const Text(
                "FIXLY",
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 2, 
                  color: Color(0xFF1E293B)
                ),
              ),
              const Text("Сервис для ОСИ и подрядчиков", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),

              // Поле Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.mail, size: 20),
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Поле Пароль
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.lock, size: 20),
                  labelText: 'Пароль',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? LucideIcons.eyeOff : LucideIcons.eye, 
                      size: 20
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Кнопка входа
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Войти", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  "Нет аккаунта? Зарегистрироваться", 
                  style: TextStyle(color: Color(0xFF3B82F6))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}