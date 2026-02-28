import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixly_app/main.dart';
import '../models/task_model.dart';
import 'task_details_page.dart';

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

  // --- ЛОГИКА ЗАГРУЗКИ (ИСПРАВЛЕННАЯ) ---
  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final Uint8List bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Исправлено: передаем bytes напрямую, без 'as File'
      await supabase.storage.from('task_images').upload(
            fileName,
            bytes as File,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return supabase.storage.from('task_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Ошибка загрузки в Storage: $e");
      return null;
    }
  }

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

  // --- МЕНЮ ВЫБОРА ФОТО (КАМЕРА/ГАЛЕРЕЯ) ---
  void _showImagePickerOptions(BuildContext context, StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: Text(appLanguage.value == 'ru' ? "Сделать снимок" : "Суретке түсіру"),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (img != null) setDialogState(() => _selectedImage = img);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: Text(appLanguage.value == 'ru' ? "Выбрать из галереи" : "Галереядан таңдау"),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (img != null) setDialogState(() => _selectedImage = img);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new': return const Color(0xFF3B82F6);
      case 'in_progress': return const Color(0xFFF59E0B);
      case 'completed': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

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
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              appLanguage.value == 'ru' ? "Новая заявка" : "Жаңа тапсырма",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showImagePickerOptions(context, setDialogState),
                    child: Container(
                      height: _selectedImage == null ? 100 : 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : (Colors.grey[300] ?? Colors.grey)),
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
                                Icon(LucideIcons.camera, color: Colors.blue[400], size: 30),
                                const SizedBox(height: 8),
                                Text(
                                  appLanguage.value == 'ru' ? "Добавить фото" : "Сурет қосу",
                                  style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                                onPressed: () => setDialogState(() => _selectedImage = null),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: appLanguage.value == 'ru' ? "Что случилось?" : "Не болды?",
                      prefixIcon: const Icon(LucideIcons.alertCircle, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: aptController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: appLanguage.value == 'ru' ? "Кв. №" : "Пәтер №",
                            prefixIcon: const Icon(LucideIcons.home, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: appLanguage.value == 'ru' ? "Телефон" : "Телефон",
                            prefixIcon: const Icon(LucideIcons.phone, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: appLanguage.value == 'ru' ? "Описание" : "Сипаттамасы",
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(appLanguage.value == 'ru' ? "Отмена" : "Бас тарту"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(appLanguage.value == 'ru' ? "Создать" : "Құру"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            title: Text(role == 'chairman' ? (lang == 'ru' ? "Панель ОСИ" : "МТБ Панелі") : (lang == 'ru' ? "Заказы" : "Тапсырыстар")),
            actions: [
              IconButton(icon: const Icon(LucideIcons.logOut, color: Colors.redAccent), onPressed: _signOut),
            ],
          ),
          body: Column(
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('tasks').stream(primaryKey: ['id']).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Expanded(child: _buildEmptyState(lang));

                  final allTasks = snapshot.data!.map((d) => TaskModel.fromJson(d)).toList();
                  
                  int newCount = allTasks.where((t) => t.status == 'new').length;
                  int progressCount = allTasks.where((t) => t.status == 'in_progress').length;
                  int doneCount = allTasks.where((t) => t.status == 'completed').length;

                  final displayedTasks = _selectedFilter == 'all' 
                      ? allTasks 
                      : allTasks.where((t) => t.status == _selectedFilter).toList();

                  return Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              _buildStatCard(lang == 'ru' ? "Новые" : "Жаңа", newCount, Colors.blue, LucideIcons.bell),
                              _buildStatCard(lang == 'ru' ? "В работе" : "Жұмыста", progressCount, Colors.orange, LucideIcons.wrench),
                              _buildStatCard(lang == 'ru' ? "Готово" : "Дайын", doneCount, Colors.green, LucideIcons.checkCircle),
                            ],
                          ),
                        ),

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

                        Expanded(
                          child: displayedTasks.isEmpty
                              ? _buildEmptyState(lang)
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 10, bottom: 80),
                                  itemCount: displayedTasks.length,
                                  itemBuilder: (context, index) {
                                    final task = displayedTasks[index];
                                    return _buildTaskCard(task, lang);
                                  },
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
                  label: Text(lang == 'ru' ? "Создать" : "Құру"),
                  icon: const Icon(Icons.add),
                  backgroundColor: const Color(0xFF3B82F6),
                )
              : null,
        );
      },
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    bool isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF3B82F6),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), 
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task, String lang) {
    Color statusColor = _getStatusColor(task.status);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Center(
            child: Text(
              task.apartment.isNotEmpty ? task.apartment : "?", 
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)
            )
          ),
        ),
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
        ),
        trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailsPage(task: task, role: role ?? 'master'))),
      ),
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.inbox, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(lang == 'ru' ? "Заявок пока нет" : "Тапсырыстар жоқ", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}