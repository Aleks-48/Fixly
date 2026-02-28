import 'package:fixly_app/services/ai_service.dart'; 
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
// Импортируем твой сервис (проверь путь к файлу, если он другой)

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController(text: "г. Кокшетау, ");
  
  XFile? _selectedImage; 
  String _selectedPriority = 'medium'; 
  bool _isSaving = false;
  bool _isAILoading = false;

  // Константы стиля из твоего дизайна
  final Color bgColor = const Color(0xFF0F0F0F);
  final Color cardColor = const Color(0xFF1C1C1E);
  final Color accentBlue = const Color(0xFF3383FF);

  // --- ИНТЕГРАЦИЯ ТВОЕГО AI SERVICE ---
Future<void> _analyzeWithAI(String lang) async {
  final text = _descController.text.trim();
  if (text.length < 5) return;

  setState(() => _isAILoading = true);

  try {
    final result = await AIService.generateActionPlan(
      _titleController.text.isEmpty ? "Заявка" : _titleController.text,
      text,
      lang,
    );

    // ПРОВЕРКА: Если результат начинается с ERROR, не показываем успех
    if (result.startsWith("ERROR")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ошибка ИИ: ${result.replaceAll('ERROR_', '')}"),
          backgroundColor: Colors.redAccent,
        )
      );
    } else {
      setState(() {
        _descController.text = "$text\n\n--- AI PLAN ---\n$result";
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ ИИ подготовил план работ"),
          backgroundColor: Colors.purpleAccent,
        )
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
  } finally {
    setState(() => _isAILoading = false);
  }
}

  // --- ЛОГИКА ЗАГРУЗКИ ФОТО ---
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'task_images/$fileName';

      await supabase.storage.from('task_images').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      return supabase.storage.from('task_images').getPublicUrl(filePath);
    } catch (e) {
      print("Ошибка загрузки фото: $e");
      return null;
    }
  }

  // --- ЛОГИКА СОХРАНЕНИЯ ЗАЯВКИ ---
  Future<void> _saveOrder(String lang) async {
    if (_titleController.text.isEmpty || _apartmentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ru' ? "Заполните заголовок и кв." : "Тақырып пен пәтерді толтырыңыз"))
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? imageUrl = await _uploadImage();
      final user = supabase.auth.currentUser;

      await supabase.from('tasks').insert({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'apartment': _apartmentController.text.trim(),
        'address': _addressController.text.trim(),
        'resident_phone': _phoneController.text.trim(),
        'priority': _selectedPriority,
        'status': 'new',
        'user_id': user?.id,
        'image_url': imageUrl,
      });

      if (mounted) {
        Navigator.pop(context, true); // Возвращаемся и обновляем список
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка сохранения: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(lang == 'ru' ? "Новая заявка" : "Жаңа өтінім", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // КАРТОЧКА ФОТО
                GestureDetector(
                  onTap: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (img != null) setState(() => _selectedImage = img);
                  },
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: kIsWeb ? NetworkImage(_selectedImage!.path) : FileImage(File(_selectedImage!.path)) as ImageProvider,
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.camera, color: accentBlue, size: 32),
                              const SizedBox(height: 8),
                              Text(lang == 'ru' ? "Прикрепить фото" : "Сурет қосу", 
                                style: TextStyle(color: Colors.white.withOpacity(0.5))),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 20),

                // ГРУППА ПОЛЕЙ (Адрес, Кв, Телефон)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildModernField(_addressController, lang == 'ru' ? "Адрес (улица, дом)" : "Мекен-жай", LucideIcons.mapPin),
                      const Divider(color: Colors.white10, height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildModernField(_apartmentController, "Кв. №", LucideIcons.home, keyboard: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildModernField(_phoneController, "Телефон", LucideIcons.phone, keyboard: TextInputType.phone, prefix: "+7 ")),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ОПИСАНИЕ С КНОПКОЙ ИИ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildModernField(_descController, lang == 'ru' ? "Опишите проблему" : "Мәселені сипаттаңыз", LucideIcons.pencil, maxLines: 4),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _isAILoading ? null : () => _analyzeWithAI(lang),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isAILoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.sparkles, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(lang == 'ru' ? "ИИ Магия" : "ЖИ Сиқыры", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildModernField(_titleController, lang == 'ru' ? "Заголовок заявки" : "Тақырып", LucideIcons.type, useCard: true),
                const SizedBox(height: 25),

                // ПРИОРИТЕТЫ
                Text(lang == 'ru' ? "Срочность:" : "Шұғылдык:", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _priorityTile('low', lang == 'ru' ? "Низкая" : "Төмен", Colors.green),
                    const SizedBox(width: 10),
                    _priorityTile('medium', lang == 'ru' ? "Средняя" : "Орташа", Colors.orange),
                    const SizedBox(width: 10),
                    _priorityTile('high', lang == 'ru' ? "Высокая" : "Жоғары", Colors.red),
                  ],
                ),

                const SizedBox(height: 40),

                // КНОПКА СОЗДАНИЯ
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveOrder(lang),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(lang == 'ru' ? "Создать заявку" : "Құру", 
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  // Виджет поля ввода
  Widget _buildModernField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, TextInputType? keyboard, String? prefix, bool useCard = false}) {
    Widget field = TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        prefixIcon: Icon(icon, color: accentBlue.withOpacity(0.5), size: 18),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.white),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );

    if (useCard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
        child: field,
      );
    }
    return field;
  }

  // Виджет выбора приоритета
  Widget _priorityTile(String value, String label, Color color) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.white10, width: 1.5),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? color : Colors.white.withOpacity(0.5), 
              fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}