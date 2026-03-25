import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import '../../models/user_model.dart'; 
import '../../services/profile_service.dart'; 

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Контроллеры ввода
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController(); 
  final _lastNameController = TextEditingController();
  final _binController = TextEditingController();
  
  // Роли: 'master', 'chairman' или 'resident'
  String _selectedRole = 'master'; 
  bool _isLoading = false;
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  // ОСНОВНАЯ ЛОГИКА РЕГИСТРАЦИИ
  Future<void> _signUp() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String bin = _binController.text.trim();
    final String lang = appLanguage.value;

    // Валидация (для жителя БИН не обязателен)
    bool isResident = _selectedRole == 'resident';
    bool isBinEmpty = !isResident && bin.isEmpty;

    if (email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty || isBinEmpty) {
      _showSnackBar(
        lang == 'ru' ? 'Заполните все обязательные поля' : 'Барлық міндетті өрістерді толтырыңыз', 
        Colors.orange
      );
      return;
    }

    if (password.length < 6) {
      _showSnackBar(
        lang == 'ru' ? 'Пароль слишком короткий' : 'Құпия сөз тым қысқа', 
        Colors.orange
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // 1. Регистрация в Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'role': _selectedRole,
          'bin': isResident ? "" : bin, // Для жителя пустая строка
        }, 
      );

      final user = response.user;
      if (user != null) {
        // 2. Создаем модель для БД
        final newUser = UserModel(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: '', 
          bin: isResident ? "" : bin,
          role: _selectedRole,
        );

        // 3. Сохраняем в таблицу profiles
        final success = await ProfileService().saveProfile(newUser);

        if (success) {
          userRole.value = _selectedRole; // Обновляем глобальное состояние
          if (!mounted) return;
          _showSnackBar(
            lang == 'ru' ? 'Успешная регистрация!' : 'Тіркелу сәтті аяқталды!', 
            Colors.green
          );
          
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          throw Exception(lang == 'ru' ? 'Ошибка базы данных' : 'Деректер қорының қатесі');
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.redAccent);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _binController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = appLanguage.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'ru' ? "Регистрация" : "Тіркелу"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'ru' ? "Создать профиль" : "Профиль жасау", 
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'ru' ? "Заполните данные для регистрации" : "Тіркелу үшін деректерді толтырыңыз",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            _buildField(_firstNameController, lang == 'ru' ? 'Имя' : 'Есімі', LucideIcons.user),
            const SizedBox(height: 16),
            _buildField(_lastNameController, lang == 'ru' ? 'Фамилия' : 'Тегі', LucideIcons.user),
            const SizedBox(height: 16),
            
            // Динамическое поле БИН/ИИН (скрывается для жителя)
            if (_selectedRole != 'resident') ...[
              _buildField(_binController, 'БИН / ИИН', LucideIcons.fileDigit, isNumeric: true),
              const SizedBox(height: 16),
            ],

            _buildField(_emailController, 'Email', LucideIcons.mail, isEmail: true),
            const SizedBox(height: 16),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _buildInputDecoration(lang == 'ru' ? 'Пароль' : 'Құпия сөз', LucideIcons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            const SizedBox(height: 32),
            
            Text(
              lang == 'ru' ? "Ваша роль" : "Сіздің рөліңіз", 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            
            // Сетка выбора ролей (теперь 3 роли)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildRoleCard(
                  'master', 
                  lang == 'ru' ? "Подрядчик" : "Мердігер", 
                  LucideIcons.wrench, 
                  "ИП / ТОО", 
                  isDark
                ),
                _buildRoleCard(
                  'chairman', 
                  lang == 'ru' ? "ОСИ" : "МИБ", 
                  LucideIcons.building, 
                  lang == 'ru' ? "Председатель" : "Төраға", 
                  isDark
                ),
                _buildRoleCard(
                  'resident', 
                  lang == 'ru' ? "Житель" : "Тұрғын", 
                  LucideIcons.home, 
                  lang == 'ru' ? "Собственник" : "Меншік иесі", 
                  isDark
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    lang == 'ru' ? "Зарегистрироваться" : "Тіркелу", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
            
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  lang == 'ru' ? "Уже есть аккаунт? Войти" : "Аккаунт бар ма? Кіру", 
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isNumeric = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: _buildInputDecoration(label, icon),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildRoleCard(String role, String title, IconData icon, String subtitle, bool isDark) {
    final isSelected = _selectedRole == role;
    // Используем фиксированную ширину для карточек в Wrap, чтобы они смотрелись аккуратно
    double cardWidth = (MediaQuery.of(context).size.width - 68) / 2;
    if (role == 'resident') cardWidth = MediaQuery.of(context).size.width - 48;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: cardWidth,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.blueAccent : null)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}