import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/services/ai_service.dart';

/// Страница создания новой заявки (задачи)
/// Поддерживает интеграцию с ИИ для генерации плана работ и загрузку фото
class CreateOrderPage extends StatefulWidget {
  final String initialCategory;

  const CreateOrderPage({
    super.key, 
    required this.initialCategory,
  });

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  // Контроллеры текстовых полей
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController(text: "г. Кокшетау, ");
  
  XFile? _selectedImage; 
  String _selectedPriority = 'medium'; 
  late String _currentCategory;
  
  bool _isSaving = false;
  bool _isAILoading = false;

  // Константы стиля
  final Color bgColor = const Color(0xFF0F0F0F);
  final Color cardColor = const Color(0xFF1C1C1E);
  final Color accentBlue = const Color(0xFF3383FF);

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategory;
    _loadUserDefaultData();
  }

  /// Автоматическая подгрузка данных пользователя для удобства
  Future<void> _loadUserDefaultData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('phone, apartment_number')
            .eq('id', user.id)
            .single();
        
        setState(() {
          if (data['phone'] != null) _phoneController.text = data['phone'].toString().replaceFirst('+7 ', '');
          if (data['apartment_number'] != null) _apartmentController.text = data['apartment_number'].toString();
        });
      }
    } catch (e) {
      debugPrint("Ошибка предзагрузки данных: $e");
    }
  }

  // --- ИНТЕГРАЦИЯ AI SERVICE ---
  Future<void> _analyzeWithAI(String lang) async {
    final text = _descController.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ru' ? "Опишите проблему подробнее для ИИ" : "ЖИ үшін мәселені толығырақ сипаттаңыз"))
      );
      return;
    }

    setState(() => _isAILoading = true);

    try {
      final result = await AIService.generateActionPlan(
        _titleController.text.isEmpty ? "Заявка" : _titleController.text,
        text,
        lang,
      );

      if (result.startsWith("ERROR")) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Ошибка ИИ: ${result.replaceAll('ERROR_', '')}"),
              backgroundColor: Colors.redAccent,
            )
          );
        }
      } else {
        setState(() {
          _descController.text = "$text\n\n--- AI ACTION PLAN ---\n$result";
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text("✨ ИИ сформировал план решения"),
                ],
              ),
              backgroundColor: Colors.purpleAccent,
            )
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isAILoading = false);
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
        fileOptions: FileOptions(contentType: 'image/$fileExt'),
      );

      return supabase.storage.from('task_images').getPublicUrl(filePath);
    } catch (e) {
      debugPrint("Ошибка загрузки фото: $e");
      return null;
    }
  }

  // --- СОХРАНЕНИЕ ЗАЯВКИ ---
  Future<void> _saveOrder(String lang) async {
    // Валидация
    if (_titleController.text.isEmpty || _apartmentController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'ru' ? "Заполните все обязательные поля!" : "Барлық міндетті өрістерді толтырыңыз!"),
          backgroundColor: Colors.orangeAccent,
        )
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? imageUrl = await _uploadImage();
      final user = supabase.auth.currentUser;

      // Получаем building_id пользователя для связки с ОСИ
      final userData = await supabase.from('profiles').select('building_id').eq('id', user!.id).single();

      await supabase.from('tasks').insert({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'apartment': _apartmentController.text.trim(),
        'address': _addressController.text.trim(),
        'resident_phone': "+7 ${_phoneController.text.trim()}",
        'priority': _selectedPriority,
        'category': _currentCategory,
        'status': 'new',
        'user_id': user.id,
        'building_id': userData['building_id'],
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSuccessDialog(lang);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка БД: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(LucideIcons.checkCircle, color: Colors.green, size: 50),
        content: Text(
          lang == 'ru' ? "Заявка успешно создана!" : "Өтінім сәтті қабылданды!",
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // закрыть диалог
              Navigator.pop(context, true); // вернуться на главный экран
            },
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
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
            title: Text(
              lang == 'ru' ? "Новая заявка" : "Жаңа өтінім", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
            ),
            centerTitle: true,
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // БЛОК ВЫБОРА ФОТО
                  _buildImagePickerSection(lang),
                  
                  const SizedBox(height: 24),

                  // СЕКЦИЯ: ИНФОРМАЦИЯ О МЕСТЕ
                  _buildSectionTitle(lang == 'ru' ? "Где произошло?" : "Қай жерде болды?"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        _buildModernField(_addressController, lang == 'ru' ? "Адрес" : "Мекен-жай", LucideIcons.mapPin),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white10, height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildModernField(_apartmentController, "Кв. №", LucideIcons.home, keyboard: TextInputType.number)),
                            Container(width: 1, height: 30, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 10)),
                            Expanded(flex: 2, child: _buildModernField(_phoneController, "Телефон", LucideIcons.phone, keyboard: TextInputType.phone, prefix: "+7 ")),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // СЕКЦИЯ: ОПИСАНИЕ
                  _buildSectionTitle(lang == 'ru' ? "Суть проблемы" : "Мәселе сипаты"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModernField(_titleController, lang == 'ru' ? "Краткий заголовок" : "Қысқаша тақырып", LucideIcons.type),
                        const Divider(color: Colors.white10, height: 20),
                        _buildModernField(_descController, lang == 'ru' ? "Подробное описание..." : "Толық сипаттама...", LucideIcons.pencil, maxLines: 5),
                        const SizedBox(height: 15),
                        
                        // КНОПКА ИИ МАГИИ
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildAIButton(lang),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // СЕКЦИЯ: ПРИОРИТЕТ
                  _buildSectionTitle(lang == 'ru' ? "Срочность выполнения" : "Орындау мерзімділігі"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _priorityTile('low', lang == 'ru' ? "Не к спеху" : "Асығыс емес", Colors.blueGrey),
                      const SizedBox(width: 10),
                      _priorityTile('medium', lang == 'ru' ? "Обычная" : "Қалыпты", Colors.orange),
                      const SizedBox(width: 10),
                      _priorityTile('high', lang == 'ru' ? "Срочно!" : "Шұғыл!", Colors.redAccent),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ФИНАЛЬНАЯ КНОПКА
                  _buildSubmitButton(lang),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    );
  }

  Widget _buildImagePickerSection(String lang) {
    return GestureDetector(
      onTap: () async {
        final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
        if (img != null) setState(() => _selectedImage = img);
      },
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accentBlue.withOpacity(0.2), width: 1),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(LucideIcons.camera, color: accentBlue, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(lang == 'ru' ? "Добавить фото поломки" : "Бұзылу суретін қосу", 
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _selectedImage = null),
                ),
              ),
      ),
    );
  }

  Widget _buildAIButton(String lang) {
    return InkWell(
      onTap: _isAILoading ? null : () => _analyzeWithAI(lang),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAILoading ? [Colors.grey, Colors.grey] : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: _isAILoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  lang == 'ru' ? "Помощь ИИ" : "ЖИ көмегі", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, TextInputType? keyboard, String? prefix}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
        prefixIcon: Icon(icon, color: accentBlue.withOpacity(0.6), size: 20),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _priorityTile(String value, String label, Color color) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? color : Colors.white10, width: 2),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? color : Colors.white38, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
              fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String lang) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [accentBlue, const Color(0xFF1A56BE)]),
        boxShadow: [
          BoxShadow(color: accentBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveOrder(lang),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white) 
          : Text(
              lang == 'ru' ? "Оформить заявку" : "Өтінімді жіберу", 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
      ),
    );
  }
}