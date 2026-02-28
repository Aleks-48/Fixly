import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixly_app/main.dart';

class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialBin;
  final String? initialAvatarUrl;

  const EditProfilePage({
    super.key, 
    required this.initialName, 
    required this.initialBin,
    this.initialAvatarUrl,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _binController;
  String? _avatarUrl;
  bool _isSaving = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _binController = TextEditingController(text: widget.initialBin);
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      debugPrint("Ошибка выбора фото: $e");
      _showMsg("Не удалось выбрать фото", isError: true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      String? uploadedUrl = _avatarUrl;

      // Загрузка аватарки
      if (_imageFile != null) {
        final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('avatars').uploadBinary(
          fileName,
          await _imageFile!.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );
        uploadedUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      await supabase.from('profiles').update({
        'name': _nameController.text.trim(), 
        'bin': _binController.text.trim(),
        'avatar_url': uploadedUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'bin': _binController.text.trim(),
          'avatar_url': uploadedUrl,
        }); 
        _showMsg("Данные успешно сохранены");
      }
    } catch (e) {
      debugPrint("❌ Ошибка: $e");
      if (mounted) _showMsg("Ошибка сохранения: проверьте доступ к Storage", isError: true);
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
                // Визуальная область для аватарки
                Center(
                  child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(50),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null 
                              ? FileImage(_imageFile!) as ImageProvider
                              : (_avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null),
                          child: _imageFile == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) 
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 18, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
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
                    if (v != null && v.isNotEmpty && v.length != 12) return "БИН должен содержать 12 цифр";
                    return null;
                  },
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
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blueAccent),
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}