import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixly_app/main.dart';
import '../models/task_model.dart';
import 'task_details_page.dart';

// ============================================================
// HomePage — Главный экран приложения Fixly
// Поддерживает две роли:
// 1. Председатель (Chairman): создает заявки, видит общую статистику.
// 2. Мастер (Master): видит список доступных заявок для работы.
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  String? role;
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  // --- ПРОВЕРКА РОЛИ ПОЛЬЗОВАТЕЛЯ ---
  Future<void> _checkRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          role = (data != null) ? data['role'] : 'master';
          userRole.value = role!;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка получения роли: $e");
      if (mounted) {
        setState(() {
          role = 'master';
          _isLoading = false;
        });
      }
    }
  }

  // --- ЛОГИКА ЗАГРУЗКИ ИЗОБРАЖЕНИЯ (ИСПРАВЛЕННАЯ) ---
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final Uint8List bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = 'tasks/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Используем uploadBinary для передачи Uint8List (работает на всех платформах)
      await supabase.storage.from('task_images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return supabase.storage.from('task_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Ошибка загрузки в Storage: $e");
      return null;
    }
  }

  // --- ВЫХОД ИЗ АККАУНТА ---
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // --- ЦВЕТА СТАТУСОВ ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'new': return const Color(0xFF3B82F6); // Blue
      case 'in_progress': return const Color(0xFFF59E0B); // Amber
      case 'completed': return const Color(0xFF10B981); // Emerald
      default: return Colors.grey;
    }
  }

  // --- UI: КАРТОЧКА СТАТИСТИКИ ---
  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // --- ДИАЛОГ СОЗДАНИЯ ЗАЯВКИ ---
  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final aptController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSaving = false;
    _selectedImage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(
              appLanguage.value == 'ru' ? "Новая заявка" : "Жаңа тапсырма",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Выбор фото
                  GestureDetector(
                    onTap: () => _showImagePickerOptions(context, setDialogState),
                    child: Container(
                      height: _selectedImage == null ? 110 : 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: kIsWeb 
                                  ? NetworkImage(_selectedImage!.path) 
                                  : FileImage(File(_selectedImage!.path)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.imagePlus, color: Colors.blue[400], size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  appLanguage.value == 'ru' ? "Прикрепить фото" : "Суреттіแนบ",
                                  style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                  icon: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 18, color: Colors.white),
                                  ),
                                  onPressed: () => setDialogState(() => _selectedImage = null),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(titleController, LucideIcons.type, appLanguage.value == 'ru' ? "Заголовок" : "Тақырып"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(aptController, LucideIcons.home, "Кв.", numeric: true)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildTextField(phoneController, LucideIcons.phone, "Телефон", numeric: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(descController, LucideIcons.alignLeft, appLanguage.value == 'ru' ? "Описание" : "Сипаттама", lines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(appLanguage.value == 'ru' ? "Отмена" : "Бас тарту", style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: isSaving ? null : () async {
                  if (titleController.text.isEmpty) return;
                  setDialogState(() => isSaving = true);
                  
                  try {
                    final imageUrl = await _uploadImage();
                    final user = supabase.auth.currentUser;

                    await supabase.from('tasks').insert({
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'apartment': aptController.text.trim(),
                      'resident_phone': phoneController.text.trim(),
                      'status': 'new',
                      'chairman_id': user?.id,
                      'image_url': imageUrl,
                    });
                    
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(appLanguage.value == 'ru' ? "Создать" : "Құру", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ ПОЛЕЙ ВВОДА ---
  Widget _buildTextField(TextEditingController ctrl, IconData icon, String label, {bool numeric = false, int lines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  // --- ВЫБОР ИСТОЧНИКА ФОТО ---
  void _showImagePickerOptions(BuildContext context, StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: Colors.blue),
              title: Text(appLanguage.value == 'ru' ? "Сделать снимок" : "Суретке түсіру"),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (img != null) setDialogState(() => _selectedImage = img);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: Colors.purple),
              title: Text(appLanguage.value == 'ru' ? "Выбрать из галереи" : "Галереядан таңдау"),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (img != null) setDialogState(() => _selectedImage = img);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))));

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Text(
              role == 'chairman' 
                ? (lang == 'ru' ? "Панель ОСИ" : "МТБ Панелі") 
                : (lang == 'ru' ? "Заказы" : "Тапсырыстар"),
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 24),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20)
                ), 
                onPressed: _signOut
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('tasks').stream(primaryKey: ['id']).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Expanded(child: Center(child: CircularProgressIndicator()));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Expanded(child: _buildEmptyState(lang));
                  }

                  // Строго типизируем список, отфильтровываем возможные null
                  final List<TaskModel> allTasks = snapshot.data!
                      .map((d) => TaskModel.fromJson(d))
                      .whereType<TaskModel>()
                      .toList();
                  
                  int newCount = allTasks.where((t) => t.status == 'new').length;
                  int progressCount = allTasks.where((t) => t.status == 'in_progress').length;
                  int doneCount = allTasks.where((t) => t.status == 'completed').length;

                  final List<TaskModel> displayedTasks = _selectedFilter == 'all' 
                      ? allTasks 
                      : allTasks.where((t) => t.status == _selectedFilter).toList();

                  return Expanded(
                    child: Column(
                      children: [
                        // Секция статистики
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              _buildStatCard(lang == 'ru' ? "Новые" : "Жаңа", newCount, const Color(0xFF3B82F6), LucideIcons.bell),
                              _buildStatCard(lang == 'ru' ? "В работе" : "Жұмыста", progressCount, const Color(0xFFF59E0B), LucideIcons.wrench),
                              _buildStatCard(lang == 'ru' ? "Готово" : "Дайын", doneCount, const Color(0xFF10B981), LucideIcons.checkCircle),
                            ],
                          ),
                        ),

                        // Чипы фильтрации
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildFilterChip('all', lang == 'ru' ? "Все" : "Барлығы"),
                              _buildFilterChip('new', lang == 'ru' ? "Новые" : "Жаңа"),
                              _buildFilterChip('in_progress', lang == 'ru' ? "В процессе" : "Жұмыста"),
                              _buildFilterChip('completed', lang == 'ru' ? "Завершенные" : "Біткен"),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Список задач
                        Expanded(
                          child: displayedTasks.isEmpty
                              ? _buildEmptyState(lang)
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 4, bottom: 100),
                                  itemCount: displayedTasks.length,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) => _buildTaskCard(displayedTasks[index]),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: role == 'chairman'
              ? FloatingActionButton.extended(
                  onPressed: _showCreateTaskDialog,
                  label: Text(lang == 'ru' ? "Создать" : "Құру", style: const TextStyle(fontWeight: FontWeight.bold)),
                  icon: const Icon(LucideIcons.plus, size: 20),
                  backgroundColor: const Color(0xFF3B82F6),
                  elevation: 4,
                )
              : null,
        );
      },
    );
  }

  // --- ЧИП ФИЛЬТРАЦИИ ---
  Widget _buildFilterChip(String filter, String label) {
    bool isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600], 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF3B82F6),
        backgroundColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), 
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
        ),
      ),
    );
  }

  // --- КАРТОЧКА ЗАДАЧИ ---
  Widget _buildTaskCard(TaskModel task) {
    Color statusColor = _getStatusColor(task.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6)
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withOpacity(0.2))
          ),
          child: Center(
            child: Text(
              task.apartment != null && task.apartment!.isNotEmpty ? task.apartment! : "?", 
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 18)
            )
          ),
        ),
        title: Text(
          task.title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
            children: [
              Icon(LucideIcons.clock, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                task.description, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(color: Colors.grey[600], fontSize: 13)
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), shape: BoxShape.circle),
          child: const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 18)
        ),
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => TaskDetailsPage(task: task, role: role ?? 'master'))
        ),
      ),
    );
  }

  // --- ЭКРАН "ПУСТО" ---
  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(LucideIcons.inbox, size: 64, color: Colors.blue[200]),
          ),
          const SizedBox(height: 20),
          Text(
            lang == 'ru' ? "Заявок пока нет" : "Тапсырыстар жоқ", 
            style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ru' ? "Все обращения появятся здесь" : "Барлық өтінімдер осында болады", 
            style: TextStyle(color: Colors.grey[400], fontSize: 14)
          ),
        ],
      ),
    );
  }
}

// Расширение для безопасности
extension SafeTask on TaskModel {
  String get displayApartment => (apartment != null && apartment!.isNotEmpty) ? apartment! : "?";
}