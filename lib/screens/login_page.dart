import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Добавь в pubspec.yaml
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
        SnackBar(content: Text(appLanguage.value == 'ru' ? "Введите email для сброса" : "Қалпына келтіру үшін email енгізіңіз")),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Ссылка отправлена на почту!" : "Сілтеме поштаңызға жіберілді!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error")));
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
        // Если это первый вход, можно сохранить имя из Apple
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Твои существующие методы без изменений
  Future<void> _checkAndHandleRole(String userId, String lang) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      if (data == null || data['role'] == null) {
        if (mounted) _showRoleSelectionDialog(userId, lang);
      } else {
        userRole.value = data['role'];
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showRoleSelectionDialog(String userId, String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang == 'ru' ? "Выберите роль" : "Рөлді таңдаңыз", textAlign: TextAlign.center),
        content: Text(lang == 'ru' ? "Кто вы в приложении?" : "Қосымшада кімсіз?"),
        actions: [
          Column(
            children: [
              _roleBtn(userId, 'master', lang == 'ru' ? "Я Мастер" : "Мен Шебермін", Colors.blueAccent),
              const SizedBox(height: 12),
              _roleBtn(userId, 'chairman', lang == 'ru' ? "Я Председатель" : "Мен Төрағамын", Colors.orangeAccent),
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
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: color),
      onPressed: () => _saveRole(userId, role),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> _saveRole(String userId, String selectedRole) async {
    await Supabase.instance.client.from('profiles').upsert({'id': userId, 'role': selectedRole});
    userRole.value = selectedRole;
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, '/home');
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
      if (response.user != null) await _checkAndHandleRole(response.user!.id, appLanguage.value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '700103731510-4nuteqagkbgk0r9s05dfvj3ng3oh0944.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) { setState(() => _isLoading = false); return; }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) await _checkAndHandleRole(response.user!.id, appLanguage.value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Error: $e')));
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
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const Icon(LucideIcons.wrench, size: 80, color: Color(0xFF3B82F6)),
                  const Text("FIXLY", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 40),
                  
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(LucideIcons.mail), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: lang == 'ru' ? 'Пароль' : 'Құпия сөз',
                      prefixIcon: const Icon(LucideIcons.lock),
                      suffixIcon: IconButton(icon: Icon(_obscureText ? LucideIcons.eyeOff : LucideIcons.eye), onPressed: () => setState(() => _obscureText = !_obscureText)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  
                  // ССЫЛКА НА СБРОС ПАРОЛЯ
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(lang == 'ru' ? "Забыли пароль?" : "Құпия сөзді ұмыттыңыз ба?", style: const TextStyle(fontSize: 12)),
                    ),
                  ),

                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator() : Text(lang == 'ru' ? "Войти" : "Кіру"),
                  ),

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text(lang == 'ru' ? "Создать аккаунт" : "Тіркелу", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 30),
                  const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("ИЛИ")), Expanded(child: Divider())]),
                  const SizedBox(height: 20),

                  // КНОПКА GOOGLE
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(LucideIcons.chrome, size: 20),
                    label: Text(lang == 'ru' ? "Google" : "Google"),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  
                  const SizedBox(height: 12),

                  // КНОПКА APPLE
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithApple,
                    icon: const Icon(Icons.apple, color: Colors.white),
                    label: Text(lang == 'ru' ? "Войти через Apple" : "Apple арқылы кіру", style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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