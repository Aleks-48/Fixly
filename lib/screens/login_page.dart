import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:fixly_app/main.dart'; 

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

  // ==========================================
  // ВОССТАНОВЛЕНИЕ ПАРОЛЯ
  // ==========================================
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appLanguage.value == 'ru' ? "Введите корректный email для сброса" : "Қалпына келтіру үшін дұрыс email енгізіңіз"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Сброс пароля: ссылка отправлена на почту!" : "Сілтеме поштаңызға жіберілді!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка при отправке: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // ВХОД ЧЕРЕЗ APPLE
  // ==========================================
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    final lang = appLanguage.value;
    try {
      final rawNonce = Supabase.instance.client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw 'Apple ID Token is null';

      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        if (credential.givenName != null) {
          await Supabase.instance.client.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': '${credential.givenName} ${credential.familyName ?? ''}',
          });
        }
        await _checkAndHandleRole(response.user!.id, lang);
      }
    } catch (e) {
      debugPrint("Apple Auth Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка входа через Apple"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ПРОВЕРКА И ВЫБОР РОЛИ ПОСЛЕ ВХОДА
  // ==========================================
  Future<void> _checkAndHandleRole(String userId, String lang) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      if (data == null || data['role'] == null || data['role'].toString().isEmpty) {
        if (mounted) _showRoleSelectionDialog(userId, lang);
      } else {
        userRole.value = data['role'];
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // Если профиля еще нет, предлагаем выбрать роль
      if (mounted) _showRoleSelectionDialog(userId, lang);
    }
  }

  void _showRoleSelectionDialog(String userId, String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang == 'ru' ? "Выберите вашу роль" : "Рөлді таңдаңыз", textAlign: TextAlign.center),
        content: Text(lang == 'ru' ? "Укажите, кем вы являетесь в приложении. Это настроит ваш интерфейс." : "Қосымшада кімсіз?"),
        actions: [
          Column(
            children: [
              _roleBtn(userId, 'master', lang == 'ru' ? "Я Мастер" : "Мен Шебермін", Colors.blueAccent),
              const SizedBox(height: 12),
              _roleBtn(userId, 'chairman', lang == 'ru' ? "Я Председатель (ОСИ)" : "Мен Төрағамын", Colors.orangeAccent),
              const SizedBox(height: 12),
              _roleBtn(userId, 'resident', lang == 'ru' ? "Я Житель" : "Мен Тұрғынмын", Colors.green),
            ],
          )
        ],
      ),
    );
  }

  Widget _roleBtn(String userId, String role, String label, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50), 
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ),
      onPressed: () => _saveRole(userId, role),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _saveRole(String userId, String selectedRole) async {
    try {
      await Supabase.instance.client.from('profiles').upsert({'id': userId, 'role': selectedRole});
      userRole.value = selectedRole;
      if (mounted) {
        Navigator.pop(context); // закрываем диалог
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка сохранения роли"), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // ВХОД ПО EMAIL И ПАРОЛЮ
  // ==========================================
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLanguage.value == 'ru' ? "Заполните все поля" : "Барлық өрістерді толтырыңыз"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _checkAndHandleRole(response.user!.id, appLanguage.value);
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Произошла системная ошибка'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ВХОД ЧЕРЕЗ GOOGLE
  // ==========================================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // TODO: Убедись, что этот ID правильный для твоего проекта
        serverClientId: '700103731510-4nuteqagkbgk0r9s05dfvj3ng3oh0944.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) { 
        setState(() => _isLoading = false); 
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        await _checkAndHandleRole(response.user!.id, appLanguage.value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка входа через Google: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ЛОГОТИП
                  const Icon(LucideIcons.wrench, size: 80, color: Color(0xFF3B82F6)),
                  const SizedBox(height: 10),
                  const Text("FIXLY", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.black87)),
                  const SizedBox(height: 40),
                  
                  // ПОЛЯ ВВОДА
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email', 
                      prefixIcon: const Icon(LucideIcons.mail, color: Color.fromARGB(255, 0, 0, 0)), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: lang == 'ru' ? 'Пароль' : 'Құпия сөз',
                      prefixIcon: const Icon(LucideIcons.lock, color: Color.fromARGB(255, 0, 0, 0)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.grey), 
                        onPressed: () => setState(() => _obscureText = !_obscureText)
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                    ),
                  ),
                  
                  // ССЫЛКА НА СБРОС ПАРОЛЯ
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(lang == 'ru' ? "Забыли пароль?" : "Құпия сөзді ұмыттыңыз ба?", style: const TextStyle(fontSize: 13, color: Colors.blueAccent)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // КНОПКА ВОЙТИ
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 55), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(lang == 'ru' ? "Войти" : "Кіру", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),

                  // ПЕРЕХОД НА РЕГИСТРАЦИЮ
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: RichText(
                      text: TextSpan(
                        text: lang == 'ru' ? "Нет аккаунта? " : "Аккаунтыңыз жоқ па? ",
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                        children: [
                          TextSpan(
                            text: lang == 'ru' ? "Создать" : "Тіркелу",
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          )
                        ]
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("ИЛИ", style: TextStyle(color: Colors.grey))), Expanded(child: Divider())]),
                  const SizedBox(height: 20),

                  // КНОПКА GOOGLE
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(LucideIcons.chrome, size: 20, color: Colors.redAccent),
                    label: Text(lang == 'ru' ? "Войти через Google" : "Google арқылы кіру", style: const TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.grey)
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // КНОПКА APPLE
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, color: Colors.white),
                    label: Text(lang == 'ru' ? "Войти через Apple" : "Apple арқылы кіру", style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, 
                      minimumSize: const Size(double.infinity, 55), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}