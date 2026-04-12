import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/register_page.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ============================================================
//  LoginPage — экран входа
//  • Анимированное появление элементов
//  • Email + пароль через Supabase
//  • Google Sign-In (реальная OAuth интеграция)
//  • Двуязычность ru/kz
//  • Тёмный стиль с акцентом #4361EE
// ============================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _supabase    = Supabase.instance.client;
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _obscurePass     = true;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>>  _slideAnims;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animCtrl.forward();
  }

  void _setupAnimations() {
    _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200));

    // 6 элементов появляются с задержкой друг за другом
    final intervals = [
      const Interval(0.0,  0.4),
      const Interval(0.1,  0.5),
      const Interval(0.2,  0.6),
      const Interval(0.3,  0.7),
      const Interval(0.4,  0.8),
      const Interval(0.55, 1.0),
    ];

    _fadeAnims = intervals
        .map((i) => CurvedAnimation(
            parent: _animCtrl, curve: i))
        .toList();

    _slideAnims = intervals
        .map((i) => Tween<Offset>(
                begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl,
                curve: Interval(i.begin, i.end,
                    curve: Curves.easeOutCubic))))
        .toList();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── ВХОД ЧЕРЕЗ EMAIL ──────────────────────────────────────
  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await _supabase.auth.signInWithPassword(
        email   : _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      _showError(appLanguage.value == 'ru'
          ? 'Ошибка подключения'
          : 'Байланыс қатесі');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ВХОД ЧЕРЕЗ GOOGLE ─────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });

    try {
      const webClientId ='700103731510-v907afamoo1v6goub4dih92998g1fg0p.apps.googleusercontent.com';
      // ↑ Замени на свой Client ID из Google Cloud Console
      //   (Проект → APIs & Services → Credentials → OAuth 2.0 Web Client)

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Пользователь закрыл диалог
        setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken  = googleAuth.accessToken;
      final idToken      = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google ID token is null');
      }

      // Передаём Google токен в Supabase
      await _supabase.auth.signInWithIdToken(
        provider   : OAuthProvider.google,
        idToken    : idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _showError(appLanguage.value == 'ru'
          ? 'Ошибка входа через Google'
          : 'Google арқылы кіру қатесі');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── СБРОС ПАРОЛЯ ─────────────────────────────────────────
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    final lang  = appLanguage.value;

    if (email.isEmpty || !email.contains('@')) {
      _showError(lang == 'ru'
          ? 'Введите email для сброса пароля'
          : 'Парольды қалпына келтіру үшін email енгізіңіз');
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'ru'
              ? 'Письмо для сброса пароля отправлено на $email'
              : 'Парольды қалпына келтіру хаты $email-ге жіберілді'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      _showError(lang == 'ru' ? 'Ошибка отправки письма' : 'Хат жіберу қатесі');
    }
  }

  void _showError(String msg) {
    if (mounted) setState(() => _errorMessage = msg);
  }

  String _mapAuthError(String msg) {
    final lang = appLanguage.value;
    final m    = msg.toLowerCase();
    if (m.contains('invalid') || m.contains('credentials')) {
      return lang == 'ru'
          ? 'Неверный email или пароль'
          : 'Email немесе пароль қате';
    }
    if (m.contains('not confirmed') || m.contains('email not confirmed')) {
      return lang == 'ru'
          ? 'Подтвердите email перед входом'
          : 'Кіру алдында email-ді растаңыз';
    }
    if (m.contains('too many')) {
      return lang == 'ru'
          ? 'Слишком много попыток. Попробуйте позже'
          : 'Тым көп әрекет. Кейінірек көріңіз';
    }
    return lang == 'ru' ? 'Ошибка: $msg' : 'Қате: $msg';
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // ── ЛОГОТИП ──────────────────────────────
                    _animated(0,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Text('F',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Fixly',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── ЗАГОЛОВОК ─────────────────────────────
                    _animated(1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ru' ? 'Добро\nпожаловать!' : 'Қош\nкелдіңіз!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'ru'
                                ? 'Войдите в свой аккаунт'
                                : 'Есептік жазбаңызға кіріңіз',
                            style: const TextStyle(
                                color: Color(0xFF6B7A9E), fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── EMAIL ─────────────────────────────────
                    _animated(2,
                      child: _buildTextField(
                        controller: _emailCtrl,
                        label     : lang == 'ru' ? 'Email' : 'Email',
                        hint      : 'example@email.com',
                        icon      : LucideIcons.mail,
                        keyboard  : TextInputType.emailAddress,
                        validator : (v) {
                          if (v == null || v.isEmpty) {
                            return lang == 'ru'
                                ? 'Введите email'
                                : 'Email енгізіңіз';
                          }
                          if (!v.contains('@')) {
                            return lang == 'ru'
                                ? 'Некорректный email'
                                : 'Email дұрыс емес';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ПАРОЛЬ ────────────────────────────────
                    _animated(3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildTextField(
                            controller: _passCtrl,
                            label     : lang == 'ru' ? 'Пароль' : 'Пароль',
                            hint      : '••••••••',
                            icon      : LucideIcons.lock,
                            obscure   : _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                color: const Color(0xFF4361EE),
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return lang == 'ru'
                                    ? 'Введите пароль'
                                    : 'Пароль енгізіңіз';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _resetPassword,
                            child: Text(
                              lang == 'ru'
                                  ? 'Забыли пароль?'
                                  : 'Парольды ұмыттыңыз ба?',
                              style: const TextStyle(
                                  color: Color(0xFF4361EE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── ОШИБКА ────────────────────────────────
                    if (_errorMessage != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertCircle,
                                color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),

                    // ── КНОПКА ВХОДА ──────────────────────────
                    _animated(4,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _signInWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4361EE),
                            disabledBackgroundColor:
                                const Color(0xFF4361EE).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5),
                                )
                              : Text(
                                  lang == 'ru' ? 'Войти' : 'Кіру',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── РАЗДЕЛИТЕЛЬ ───────────────────────────
                    _animated(4,
                      child: Row(
                        children: [
                          const Expanded(
                              child: Divider(color: Color(0xFF1E2A45))),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            child: Text(
                              lang == 'ru' ? 'или' : 'немесе',
                              style: const TextStyle(
                                  color: Color(0xFF4A5568),
                                  fontSize: 13),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: Color(0xFF1E2A45))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── GOOGLE ────────────────────────────────
                    _animated(5,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isGoogleLoading
                              ? null
                              : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF1E2A45), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            backgroundColor: const Color(0xFF0F1625),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    // Google G logo
                                    _googleIcon(),
                                    const SizedBox(width: 12),
                                    Text(
                                      lang == 'ru'
                                          ? 'Войти через Google'
                                          : 'Google арқылы кіру',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── РЕГИСТРАЦИЯ ───────────────────────────
                    _animated(5,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterPage()),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: lang == 'ru'
                                  ? 'Нет аккаунта?  '
                                  : 'Аккаунт жоқ па?  ',
                              style: const TextStyle(
                                  color: Color(0xFF6B7A9E),
                                  fontSize: 14),
                              children: [
                                TextSpan(
                                  text: lang == 'ru'
                                      ? 'Зарегистрироваться'
                                      : 'Тіркелу',
                                  style: const TextStyle(
                                    color: Color(0xFF4361EE),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Анимированная обёртка ─────────────────────────────────
  Widget _animated(int index, {required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
          position: _slideAnims[index], child: child),
    );
  }

  // ── Поле ввода ────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF4361EE),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568)),
        hintStyle: const TextStyle(color: Color(0xFF2A3A55)),
        prefixIcon:
            Icon(icon, color: const Color(0xFF4361EE), size: 19),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0F1625),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E2A45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E2A45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF4361EE), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle:
            const TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ── Google G иконка (SVG-like через Canvas) ───────────────
  Widget _googleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

// Рисует Google G иконку без внешних ассетов
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Упрощённый G
    final paint = Paint()..style = PaintingStyle.fill;

    // Красный
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -1.55, 1.57, true, paint);

    // Жёлтый
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        0.02, 1.57, true, paint);

    // Зелёный
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        1.59, 1.57, true, paint);

    // Синий
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        3.16, 1.57, true, paint);

    // Белый центр
    paint.color = const Color(0xFF0F1625);
    canvas.drawCircle(center, r * 0.65, paint);

    // Горизонтальная полоска G
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx, center.dy - r * 0.12, r * 0.85, r * 0.25),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}