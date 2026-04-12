import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/login_page.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ============================================================
//  RegisterPage — экран регистрации
//  • Анимированное появление
//  • Email + пароль через Supabase
//  • Google Sign-Up (реальная OAuth интеграция)
//  • Выбор роли: житель / мастер
//  • Сохранение профиля в таблицу profiles
//  • Без Apple Sign-In
// ============================================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _supabase   = Supabase.instance.client;
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _pass2Ctrl  = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool    _isLoading       = false;
  bool    _isGoogleLoading = false;
  bool    _obscurePass     = true;
  bool    _obscurePass2    = true;
  String  _selectedRole    = 'resident'; // resident | master
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
        duration: const Duration(milliseconds: 1400));

    final intervals = [
      const Interval(0.0,  0.35),
      const Interval(0.1,  0.45),
      const Interval(0.2,  0.55),
      const Interval(0.3,  0.65),
      const Interval(0.4,  0.75),
      const Interval(0.5,  0.85),
      const Interval(0.6,  1.0),
    ];

    _fadeAnims = intervals
        .map((i) => CurvedAnimation(parent: _animCtrl, curve: i))
        .toList();

    _slideAnims = intervals
        .map((i) => Tween<Offset>(
                begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl,
                curve: Interval(i.begin, i.end,
                    curve: Curves.easeOutCubic))))
        .toList();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  // ── РЕГИСТРАЦИЯ ЧЕРЕЗ EMAIL ───────────────────────────────
  Future<void> _registerWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // 1. Создаём пользователя в Auth
      final res = await _supabase.auth.signUp(
        email   : _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = res.user;
      if (user == null) throw Exception('User is null after signUp');

      // 2. Создаём профиль в таблице profiles
      await _supabase.from('profiles').upsert({
        'id'       : user.id,
        'full_name': _nameCtrl.text.trim(),
        'role'     : _selectedRole,
        'email'    : _emailCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSuccess();
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      debugPrint('Register error: $e');
      _showError(appLanguage.value == 'ru'
          ? 'Ошибка регистрации'
          : 'Тіркелу қатесі');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── GOOGLE SIGN-UP ────────────────────────────────────────
  Future<void> _signUpWithGoogle() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });

    try {
      const webClientId ='700103731510-4nuteqagkbgk0r9s05dfvj3ng3oh0944.apps.googleusercontent.com';
      // ↑ Замени на свой Client ID из Google Cloud Console

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final googleAuth  = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken     = googleAuth.idToken;

      if (idToken == null) throw Exception('Google ID token is null');

      // Вход/регистрация через Supabase
      final res = await _supabase.auth.signInWithIdToken(
        provider   : OAuthProvider.google,
        idToken    : idToken,
        accessToken: accessToken,
      );

      final user = res.user;
      if (user == null) throw Exception('User is null');

      // Создаём/обновляем профиль
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // Новый пользователь — создаём профиль
        await _supabase.from('profiles').insert({
          'id'        : user.id,
          'full_name' : googleUser.displayName ?? '',
          'avatar_url': googleUser.photoUrl,
          'email'     : googleUser.email,
          'role'      : _selectedRole,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

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
      debugPrint('Google Sign-Up error: $e');
      _showError(appLanguage.value == 'ru'
          ? 'Ошибка входа через Google'
          : 'Google арқылы кіру қатесі');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) setState(() => _errorMessage = msg);
  }

  void _showSuccess() {
    final lang = appLanguage.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.15),
              ),
              child: const Icon(LucideIcons.mailCheck,
                  color: Colors.green, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              lang == 'ru' ? 'Проверьте почту' : 'Поштаңызды тексеріңіз',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              lang == 'ru'
                  ? 'На ${_emailCtrl.text.trim()} отправлено письмо для подтверждения аккаунта'
                  : '${_emailCtrl.text.trim()} мекенжайына аккаунтты растау хаты жіберілді',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF6B7A9E), fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginPage()),
                  );
                },
                child: Text(
                  lang == 'ru' ? 'Перейти к входу' : 'Кіруге өту',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mapAuthError(String msg) {
    final lang = appLanguage.value;
    final m    = msg.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return lang == 'ru'
          ? 'Этот email уже зарегистрирован'
          : 'Бұл email тіркелген';
    }
    if (m.contains('password') && m.contains('weak')) {
      return lang == 'ru'
          ? 'Пароль слишком простой (мин. 6 символов)'
          : 'Пароль тым қарапайым (кем дегенде 6 таңба)';
    }
    if (m.contains('invalid email')) {
      return lang == 'ru' ? 'Некорректный email' : 'Email дұрыс емес';
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── ЗАГОЛОВОК ─────────────────────────────
                    _animated(0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ru'
                                ? 'Создайте\nаккаунт'
                                : 'Аккаунт\nжасаңыз',
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
                                ? 'Заполните данные для регистрации'
                                : 'Тіркелу үшін деректерді толтырыңыз',
                            style: const TextStyle(
                                color: Color(0xFF6B7A9E), fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── ВЫБОР РОЛИ ────────────────────────────
                    _animated(1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ru' ? 'Я являюсь:' : 'Мен:',
                            style: const TextStyle(
                                color: Color(0xFF6B7A9E),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _roleCard(
                                  role    : 'resident',
                                  label   : lang == 'ru' ? 'Житель' : 'Тұрғын',
                                  subtitle: lang == 'ru'
                                      ? 'Нахожу мастеров'
                                      : 'Шебер іздеймін',
                                  icon    : LucideIcons.home,
                                  lang    : lang,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _roleCard(
                                  role    : 'master',
                                  label   : lang == 'ru' ? 'Мастер' : 'Шебер',
                                  subtitle: lang == 'ru'
                                      ? 'Принимаю заказы'
                                      : 'Тапсырыс қабылдаймын',
                                  icon    : LucideIcons.hardHat,
                                  lang    : lang,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── ИМЯ ──────────────────────────────────
                    _animated(2,
                      child: _buildTextField(
                        controller: _nameCtrl,
                        label     : lang == 'ru' ? 'Имя и фамилия' : 'Аты-жөні',
                        hint      : lang == 'ru' ? 'Иван Иванов' : 'Иван Иванов',
                        icon      : LucideIcons.user,
                        validator : (v) {
                          if (v == null || v.trim().length < 2) {
                            return lang == 'ru'
                                ? 'Введите имя (мин. 2 символа)'
                                : 'Атыңызды енгізіңіз';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── EMAIL ─────────────────────────────────
                    _animated(3,
                      child: _buildTextField(
                        controller: _emailCtrl,
                        label     : 'Email',
                        hint      : 'example@email.com',
                        icon      : LucideIcons.mail,
                        keyboard  : TextInputType.emailAddress,
                        validator : (v) {
                          if (v == null || !v.contains('@')) {
                            return lang == 'ru'
                                ? 'Введите корректный email'
                                : 'Дұрыс email енгізіңіз';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── ПАРОЛЬ ────────────────────────────────
                    _animated(4,
                      child: _buildTextField(
                        controller: _passCtrl,
                        label     : lang == 'ru' ? 'Пароль' : 'Пароль',
                        hint      : '••••••••',
                        icon      : LucideIcons.lock,
                        obscure   : _obscurePass,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: const Color(0xFF4361EE), size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return lang == 'ru'
                                ? 'Минимум 6 символов'
                                : 'Кем дегенде 6 таңба';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

// ── ПОВТОР ПАРОЛЯ ─────────────────────────
_animated(4,
  child: _buildTextField(
    controller: _pass2Ctrl,
    label     : lang == 'ru' ? 'Повторите пароль' : 'Парольды қайталаңыз',
    hint      : '••••••••',
    icon      : LucideIcons.lock, // ЗАМЕНИЛ LucideIcons.lockKeyhole на LucideIcons.lock
    obscure   : _obscurePass2,
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePass2 ? LucideIcons.eyeOff : LucideIcons.eye,
        color: const Color(0xFF4361EE), size: 18,
      ),
      onPressed: () =>
          setState(() => _obscurePass2 = !_obscurePass2),
    ),
    validator: (v) {
      if (v != _passCtrl.text) {
        return lang == 'ru'
            ? 'Пароли не совпадают'
            : 'Парольдар сәйкес емес';
      }
      return null;
    },
  ),
),

                    const SizedBox(height: 14),

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
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── КНОПКА РЕГИСТРАЦИИ ────────────────────
                    _animated(5,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _registerWithEmail,
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
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  lang == 'ru'
                                      ? 'Зарегистрироваться'
                                      : 'Тіркелу',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── РАЗДЕЛИТЕЛЬ ───────────────────────────
                    _animated(5,
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
                                  color: Color(0xFF4A5568), fontSize: 13),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: Color(0xFF1E2A45))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── GOOGLE ────────────────────────────────
                    _animated(6,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isGoogleLoading
                              ? null
                              : _signUpWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF1E2A45), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            backgroundColor: const Color(0xFF0F1625),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 22, height: 22,
                                      child: CustomPaint(
                                          painter: _GoogleIconPainter()),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      lang == 'ru'
                                          ? 'Регистрация через Google'
                                          : 'Google арқылы тіркелу',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── УЖЕ ЕСТЬ АККАУНТ ──────────────────────
                    _animated(6,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: lang == 'ru'
                                  ? 'Уже есть аккаунт?  '
                                  : 'Аккаунт бар ма?  ',
                              style: const TextStyle(
                                  color: Color(0xFF6B7A9E),
                                  fontSize: 14),
                              children: [
                                TextSpan(
                                  text: lang == 'ru'
                                      ? 'Войти'
                                      : 'Кіру',
                                  style: const TextStyle(
                                      color: Color(0xFF4361EE),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Карточка роли ─────────────────────────────────────────
  Widget _roleCard({
    required String   role,
    required String   label,
    required String   subtitle,
    required IconData icon,
    required String   lang,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4361EE).withOpacity(0.15)
              : const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4361EE)
                : const Color(0xFF1E2A45),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon,
                    color: isSelected
                        ? const Color(0xFF4361EE)
                        : const Color(0xFF4A5568),
                    size: 22),
                if (isSelected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4361EE),
                    ),
                    child: const Icon(LucideIcons.check,
                        color: Colors.white, size: 11),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF8899BB),
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                  color: Color(0xFF4A5568), fontSize: 11),
            ),
          ],
        ),
      ),
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
      controller  : controller,
      keyboardType: keyboard,
      obscureText : obscure,
      validator   : validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF4361EE),
      decoration: InputDecoration(
        labelText : label,
        hintText  : hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568)),
        hintStyle : const TextStyle(color: Color(0xFF2A3A55)),
        prefixIcon:
            Icon(icon, color: const Color(0xFF4361EE), size: 19),
        suffixIcon: suffixIcon,
        filled    : true,
        fillColor : const Color(0xFF0F1625),
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
          borderSide: const BorderSide(
              color: Color(0xFF4361EE), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(
            color: Colors.redAccent, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
    );
  }
}

// Google G icon painter
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
        -1.55, 1.57, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
        0.02, 1.57, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
        1.59, 1.57, true, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r),
        3.16, 1.57, true, paint);
    paint.color = const Color(0xFF0F1625);
    canvas.drawCircle(center, r * 0.65, paint);
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