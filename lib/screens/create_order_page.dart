import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; // Путь к вашему main.dart для доступа к appLanguage
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/services/ai_service.dart';

/// Страница создания новой заявки
/// Особенности: Поддержка темной темы, Интеграция с ИИ, Загрузка фото в Supabase Storage
class CreateOrderPage extends StatefulWidget {
  final String initialCategory;

  const CreateOrderPage({
    super.key, 
    required this.initialCategory, required masterId, required masterName, required String prefillDescription,
  });

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  // Контроллеры для ввода данных
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(text: "г. Кокшетау, ");
  
  XFile? _selectedImage; 
  String _selectedPriority = 'medium'; 
  late String _currentCategory;
  
  bool _isSaving = false;
  bool _isAILoading = false;

  // Цветовая палитра (Dark Premium)
  final Color bgColor = const Color(0xFF0F0F0F);
  final Color cardColor = const Color(0xFF1C1C1E);
  final Color accentBlue = const Color(0xFF3383FF);
  final Color fieldFillColor = const Color(0xFF2C2C2E);

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategory;
    _loadUserDefaultData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _apartmentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Загрузка данных профиля (телефон и квартира) для автозаполнения
  Future<void> _loadUserDefaultData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('phone, apartment_number')
            .eq('id', user.id)
            .maybeSingle();
        
        if (data != null && mounted) {
          setState(() {
            if (data['phone'] != null) {
              // Убираем +7 если оно уже есть, так как префикс вшит в поле
              String phone = data['phone'].toString();
              _phoneController.text = phone.replaceFirst('+7 ', '').replaceFirst('+7', '');
            }
            if (data['apartment_number'] != null) {
              _apartmentController.text = data['apartment_number'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка предзагрузки данных профиля: $e");
    }
  }

  // --- ЛОГИКА AI (Генерация плана работ) ---
  Future<void> _analyzeWithAI(String lang) async {
    final text = _descController.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'ru' ? "Опишите проблему подробнее для ИИ" : "ЖИ үшін мәселені толығырақ сипаттаңыз"),
          backgroundColor: Colors.orange,
        )
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
          // Добавляем результат ИИ к описанию
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

  // --- ЗАГРУЗКА ИЗОБРАЖЕНИЯ В STORAGE ---
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

  // --- СОХРАНЕНИЕ ЗАЯВКИ В БАЗУ ---
  Future<void> _saveOrder(String lang) async {
    // Валидация полей
    if (_titleController.text.isEmpty || _apartmentController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'ru' ? "Заполните заголовок, квартиру и описание!" : "Тақырыпты, пәтерді және сипаттаманы толтырыңыз!"),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final String? imageUrl = await _uploadImage();

      // Получаем building_id пользователя (ОСИ)
      final userData = await supabase.from('profiles').select('building_id').eq('id', user.id).single();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка сохранения: $e"), backgroundColor: Colors.redAccent)
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(LucideIcons.checkCircle, color: Colors.green, size: 64),
            const SizedBox(height: 20),
            Text(
              lang == 'ru' ? "Готово!" : "Дайын!",
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              lang == 'ru' ? "Ваша заявка принята в работу" : "Сіздің өтініміңіз жұмысқа қабылданды",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 15)
                ),
                onPressed: () {
                  Navigator.pop(context); // закрыть диалог
                  Navigator.pop(context, true); // вернуться назад с результатом true
                },
                child: const Text("ОТЛИЧНО", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем изменение языка
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. ЗАГРУЗКА ФОТО
                      _buildImagePickerSection(lang),
                      
                      const SizedBox(height: 25),

                      // 2. АДРЕС И КОНТАКТЫ
                      _buildSectionTitle(lang == 'ru' ? "Местоположение" : "Орналасқан жері"),
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
                            const Divider(color: Colors.white10, height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernField(
                                    _apartmentController, 
                                    "Кв. №", 
                                    LucideIcons.home, 
                                    keyboard: TextInputType.number
                                  )
                                ),
                                Container(width: 1, height: 30, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                Expanded(
                                  flex: 2, 
                                  child: _buildModernField(
                                    _phoneController, 
                                    "Телефон", 
                                    LucideIcons.phone, 
                                    keyboard: TextInputType.phone, 
                                    prefix: "+7 "
                                  )
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // 3. ОПИСАНИЕ ПРОБЛЕМЫ
                      _buildSectionTitle(lang == 'ru' ? "Детали проблемы" : "Мәселе мәліметтері"),
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
                            _buildModernField(_titleController, lang == 'ru' ? "Что случилось?" : "Не болды?", LucideIcons.type),
                            const Divider(color: Colors.white10, height: 20),
                            _buildModernField(
                              _descController, 
                              lang == 'ru' ? "Опишите подробности..." : "Толығырақ сипаттаңыз...", 
                              LucideIcons.pencil, 
                              maxLines: 5
                            ),
                            const SizedBox(height: 15),
                            
                            // Кнопка ИИ
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildAIButton(lang),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // 4. ПРИОРИТЕТ
                      _buildSectionTitle(lang == 'ru' ? "Приоритет" : "Приоритет"),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _priorityTile('low', lang == 'ru' ? "Низкий" : "Төмен", Colors.blueGrey),
                          const SizedBox(width: 10),
                          _priorityTile('medium', lang == 'ru' ? "Средний" : "Орташа", Colors.orange),
                          const SizedBox(width: 10),
                          _priorityTile('high', lang == 'ru' ? "Высокий" : "Жоғары", Colors.redAccent),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // 5. КНОПКА ОТПРАВКИ
                      _buildSubmitButton(lang),
                      
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
              
              // Индикатор общего сохранения
              if (_isSaving)
                Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- ВИДЖЕТЫ-ПОМОЩНИКИ ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildImagePickerSection(String lang) {
    return GestureDetector(
      onTap: () async {
        final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (img != null) setState(() => _selectedImage = img);
      },
      child: Container(
        height: 180,
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
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(LucideIcons.imagePlus, color: accentBlue, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(lang == 'ru' ? "Прикрепить фото" : "Суреттіแนบ", 
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
                ],
              )
            : Stack(
                children: [
                  Positioned(
                    right: 10,
                    top: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAIButton(String lang) {
    return InkWell(
      onTap: _isAILoading ? null : () => _analyzeWithAI(lang),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAILoading 
              ? [Colors.grey, Colors.grey] 
              : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!_isAILoading) BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: _isAILoading 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  "AI ASSISTANT", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
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
      cursorColor: accentBlue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
        prefixIcon: Icon(icon, color: accentBlue.withOpacity(0.7), size: 20),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.05), width: 1.5),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
              fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String lang) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveOrder(lang),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: accentBlue.withOpacity(0.4),
        ),
        child: Text(
          lang == 'ru' ? "ОТПРАВИТЬ ЗАЯВКУ" : "ӨТІНІМДІ ЖІБЕРУ", 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)
        ),
      ),
    );
  }
}