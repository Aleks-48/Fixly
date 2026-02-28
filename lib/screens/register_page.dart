import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart'; 
import '../../services/profile_service.dart'; 

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 1. Контроллеры для всех полей ввода
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController(); 
  final _lastNameController = TextEditingController();
  final _binController = TextEditingController();
  
  // Роли: 'master' (Подрядчик) или 'osi' (Председатель)
  String _selectedRole = 'master'; 
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  // ОСНОВНАЯ ЛОГИКА РЕГИСТРАЦИИ
  Future<void> _signUp() async {
    // Извлекаем текст из контроллеров
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String bin = _binController.text.trim();
    final String roleToSave = _selectedRole;

    // 2. Валидация данных
    if (email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty || bin.isEmpty) {
      _showSnackBar('Заполните все поля, включая БИН/ИИН', Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Пароль должен быть не менее 6 символов', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      debugPrint("Попытка регистрации: $email | Роль: $roleToSave");

      // 3. Регистрация в Supabase Auth
      // Передаем данные в метаданные (data), чтобы они сохранились в системе Auth
      final response = await supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'first_name': firstName,
    'last_name': lastName,
    'role': _selectedRole, // Убедись, что тут реально 'osi' или 'master'
    'bin': bin,
        }, 
      );

      final user = response.user;
      if (user != null) {
        debugPrint("Auth успешна, ID: ${user.id}. Создаем профиль...");

        // 4. Создаем объект модели пользователя
        final newUser = UserModel(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: '', // Телефон можно будет добавить позже в профиле
          bin: bin,
          role: roleToSave,
        );

        // 5. Сохраняем данные в таблицу 'profiles' через ProfileService
        final success = await ProfileService().saveProfile(newUser);

        if (success) {
          if (!mounted) return;
          _showSnackBar('Регистрация завершена успешно!', Colors.green);
          
          // Переход на главный экран (убедись, что роут '/home' или '/main' настроен)
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showSnackBar('Ошибка при создании профиля в базе данных', Colors.redAccent);
        }
      }
    } on AuthException catch (e) {
      debugPrint("Ошибка Supabase Auth: ${e.message}");
      _showSnackBar(e.message, Colors.redAccent);
    } catch (e) {
      debugPrint("ПОЛНАЯ ОШИБКА ТУТ: $e"); // Это покажет детали в консоли дебага
      _showSnackBar('Ошибка: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Метод для показа уведомлений (SnackBar)
  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    // Очищаем контроллеры при закрытии экрана
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Регистрация", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Создать профиль", 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            const Text(
              "Заполните данные для начала работы в системе",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // ПОЛЕ: ИМЯ
            TextField(
              controller: _firstNameController, 
              decoration: _buildInputDecoration('Имя', LucideIcons.user),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            
            // ПОЛЕ: ФАМИЛИЯ
            TextField(
              controller: _lastNameController, 
              decoration: _buildInputDecoration('Фамилия', LucideIcons.user),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // ПОЛЕ: БИН / ИИН
            TextField(
              controller: _binController, 
              decoration: _buildInputDecoration('БИН / ИИН организации', LucideIcons.badgeCheck),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // ПОЛЕ: EMAIL
            TextField(
              controller: _emailController, 
              decoration: _buildInputDecoration('Email', LucideIcons.mail),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            // ПОЛЕ: ПАРОЛЬ
            TextField(
              controller: _passwordController, 
              obscureText: true, 
              decoration: _buildInputDecoration('Пароль', LucideIcons.lock),
            ),
            const SizedBox(height: 32),
            
            const Text(
              "Выберите вашу роль", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),
            
            // КАРТОЧКИ ВЫБОРА РОЛИ
            Row(
              children: [
                _buildRoleCard(
                  'master', 
                  "Подрядчик", 
                  LucideIcons.wrench, 
                  "ИП / ТОО", 
                  theme, 
                  isDark
                ),
                const SizedBox(width: 12),
                _buildRoleCard(
                  'osi', 
                  "ОСИ", 
                  LucideIcons.building, 
                  "Председатель", 
                  theme, 
                  isDark
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // КНОПКА РЕГИСТРАЦИИ
            _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Зарегистрироваться", 
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
                ),
            
            const SizedBox(height: 16),
            
            // ПЕРЕХОД К ВХОДУ
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Уже есть аккаунт? Войти", 
                  style: TextStyle(
                    color: theme.primaryColor, 
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Общий стиль для всех полей ввода
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: const TextStyle(fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  // Виджет карточки выбора роли
  Widget _buildRoleCard(String role, String title, IconData icon, String subtitle, ThemeData theme, bool isDark) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.blue.withOpacity(isDark ? 0.2 : 0.1) 
                : (isDark ? Colors.grey[900] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.blue : (isDark ? Colors.grey[800]! : Colors.grey[300]!), 
              width: 2
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4)
              )
            ] : null,
          ),
          child: Column(
            children: [
              Icon(
                icon, 
                color: isSelected ? Colors.blue : Colors.grey, 
                size: 32
              ),
              const SizedBox(height: 12),
              Text(
                title, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: isSelected ? Colors.blue : theme.textTheme.bodyLarge?.color
                )
              ),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  fontSize: 10, 
                  color: theme.textTheme.bodySmall?.color
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}