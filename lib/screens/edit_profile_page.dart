import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';

class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialBin;

  const EditProfilePage({
    super.key, 
    required this.initialName, 
    required this.initialBin
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _binController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры переданными данными
    _nameController = TextEditingController(text: widget.initialName);
    _binController = TextEditingController(text: widget.initialBin);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // 1. Валидация формы
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Проверка на случай, если сессия истекла
    if (user == null) {
      _showMsg("Пользователь не найден. Перезайдите в приложение", isError: true);
      setState(() => _isSaving = false);
      return;
    }

    try {
      // ВАЖНО: Проверь имена колонок в своей таблице 'profiles' в Supabase!
      // Если колонки называются по-другому (например full_name), измени тут:
      await supabase.from('profiles').update({
        'name': _nameController.text.trim(), 
        'bin': _binController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(), // Хорошим тоном считается обновлять дату
      }).eq('id', user.id);

      if (mounted) {
        // Возвращаем данные назад в ProfilePage, чтобы она сразу обновилась без перезагрузки
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'bin': _binController.text.trim(),
        }); 
        _showMsg("Данные успешно сохранены");
      }
    } catch (e) {
      debugPrint("❌ Ошибка сохранения в Supabase: $e");
      if (mounted) {
        _showMsg("Ошибка сохранения: проверьте интернет или структуру базы", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Редактирование" : "Өңдеу"),
            elevation: 0,
            actions: [
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else
                IconButton(
                  icon: const Icon(Icons.check_rounded, color: Colors.green, size: 30),
                  onPressed: _saveProfile,
                )
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                _buildField(
                  controller: _nameController,
                  label: lang == 'ru' ? "ФИО или Название" : "Аты-жөні немесе атауы",
                  hint: lang == 'ru' ? "Введите ваше имя" : "Атыңызды енгізіңіз",
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? "Поле не может быть пустым" : null,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _binController,
                  label: lang == 'ru' ? "БИН организации" : "БСН",
                  hint: "123456789012",
                  icon: Icons.business_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null; // БИН может быть необязательным
                    if (v.length != 12) return "БИН должен содержать 12 цифр";
                    if (int.tryParse(v) == null) return "Только цифры";
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  lang == 'ru' 
                    ? "Убедитесь, что данные верны. БИН используется для верификации ваших услуг." 
                    : "Мәліметтердің дұрыстығын тексеріңіз. БСН қызметтерді растау үшін қолданылады.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blueAccent),
            counterText: "", // Скрываем стандартный счетчик символов
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}