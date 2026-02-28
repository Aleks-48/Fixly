import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; // Добавили для доступа к appLanguage и userRole

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

  // Метод для получения роли сразу после логина
Future<void> _updateUserRole(String userId) async {
  try {
    // maybeSingle() не выдает ошибку, если строки нет, а возвращает null
    final data = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    
    if (data != null) {
      userRole.value = data['role'] ?? 'master';
    } else {
      // Если профиля нет (например, удалили вручную), создаем дефолтную роль
      userRole.value = 'master';
      debugPrint("Профиль не найден для ID: $userId. Используем роль по умолчанию.");
    }
  } catch (e) {
    debugPrint("Ошибка обновления роли: $e");
  }
}

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Сначала обновляем роль, потом идем дальше
        await _updateUserRole(response.user!.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appLanguage.value == 'ru' ? 'Добро пожаловать в Fixly!' : 'Fixly-ге қош келдіңіз!'), 
          backgroundColor: Colors.green
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appLanguage.value == 'ru' ? 'Ошибка: Неверный логин или пароль' : 'Қате: Логин немесе пароль дұрыс емес'), 
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
    // Используем ValueListenableBuilder для мгновенной реакции на смену языка (если она есть в настройках)
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  Text(
                    lang == 'ru' ? "Сервис для ОСИ и подрядчиков" : "МТБ мен мердігерлерге арналған сервис", 
                    style: const TextStyle(color: Colors.grey)
                  ),
                  const SizedBox(height: 50),

                  // Поле Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.mail, size: 20),
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
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
                      labelText: lang == 'ru' ? 'Пароль' : 'Құпия сөз',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? LucideIcons.eyeOff : LucideIcons.eye, 
                          size: 20
                        ),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
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
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        ) 
                      : Text(
                          lang == 'ru' ? "Войти" : "Киру", 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                  ),
                  
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: Text(
                      lang == 'ru' ? "Нет аккаунта? Зарегистрироваться" : "Аккаунт жоқ па? Тіркелу", 
                      style: const TextStyle(color: Color(0xFF3B82F6))
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}