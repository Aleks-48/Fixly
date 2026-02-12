import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'contractor'; 
  bool _isLoading = false;

  Future<void> _signUp() async {
    // Валидация пустых полей
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // 1. Регистрация в Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // 2. Создание профиля
        await Supabase.instance.client.from('profiles').insert({
          'id': response.user!.id,
          'role': _selectedRole,
          'full_name': 'Пользователь ${response.user!.email!.split('@')[0]}',
        });

        // ИСПРАВЛЕНИЕ: Проверка mounted перед использованием context (Async Gap)
        if (!mounted) return;

        // 3. Переход на главную
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // ИСПРАВЛЕНИЕ: Проверка mounted для показа ошибок
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'), 
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
      appBar: AppBar(title: const Text("Регистрация в Fixly")),
      body: SingleChildScrollView( // Добавили скролл, чтобы клавиатура не закрывала кнопки
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController, 
              obscureText: true, 
              decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            
            const Text("Выберите вашу роль:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Радио-кнопки
            RadioListTile<String>(
              title: const Text("Подрядчик"),
              value: 'contractor',
              groupValue: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            RadioListTile<String>(
              title: const Text("ОСИ (Председатель)"),
              value: 'chairman',
              groupValue: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            
            const SizedBox(height: 30),
            
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Создать аккаунт", style: TextStyle(fontSize: 16)),
                ),
          ],
        ),
      ),
    );
  }
}