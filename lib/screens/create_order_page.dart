import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/orders_page.dart';

// ============================================================
//  CreateOrderPage — создание заявки
//  • Полная валидация всех полей
//  • Загрузка фото в Supabase Storage
//  • Prefill из YOLO (описание + категория)
//  • Prefill из профиля мастера (masterId + masterName)
//  • Выбор специализации через chips
//  • Выбор приоритета
// ============================================================
class CreateOrderPage extends StatefulWidget {
  final String  masterId;
  final String  masterName;
  final String  initialCategory;
  final String  prefillDescription; // из YOLO-сканера

  const CreateOrderPage({
    super.key,
    this.masterId          = '',
    this.masterName        = '',
    this.initialCategory   = '',
    this.prefillDescription = '',
  });

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _supabase   = Supabase.instance.client;
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _addrCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool   _isLoading  = false;
  String _category   = '';
  String _priority   = 'medium';
  File?  _photoFile;
  String? _errorMsg;
  String? _userApartment;
  String? _userAddress;

  // Специализации
  static const _categories = {
    'plumber'    : {'ru': 'Сантехник',   'kz': 'Сантехник',   'icon': LucideIcons.droplets},
    'electrician': {'ru': 'Электрик',    'kz': 'Электрик',    'icon': LucideIcons.zap},
    'painter'    : {'ru': 'Отделочник',  'kz': 'Жөндеуші',    'icon': LucideIcons.paintbrush},
    'carpenter'  : {'ru': 'Плотник',     'kz': 'Ұста',        'icon': LucideIcons.hammer},
    'welder'     : {'ru': 'Сварщик',     'kz': 'Дәнекерші',   'icon': LucideIcons.flame},
    'locksmith'  : {'ru': 'Слесарь',     'kz': 'Слесарь',     'icon': LucideIcons.keyRound},
    'cleaner'    : {'ru': 'Уборщик',     'kz': 'Тазалаушы',   'icon': LucideIcons.sparkles},
    'general'    : {'ru': 'Другое',      'kz': 'Басқа',       'icon': LucideIcons.wrench},
  };

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory.isNotEmpty
        ? widget.initialCategory
        : 'general';
    if (widget.prefillDescription.isNotEmpty) {
      _descCtrl.text = widget.prefillDescription;
    }
    _loadUserProfile();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addrCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('apartment_number, building_id, buildings(address)')
          .eq('id', uid)
          .maybeSingle();
      if (profile != null && mounted) {
        final apt     = profile['apartment_number']?.toString() ?? '';
        final building = (profile['buildings'] as Map?)??{};
        final addr    = building['address']?.toString() ?? '';
        setState(() {
          _userApartment = apt;
          _userAddress   = addr;
          if (_addrCtrl.text.isEmpty && addr.isNotEmpty) {
            _addrCtrl.text = addr;
          }
        });
      }
    } catch (e) { debugPrint('loadUserProfile: $e'); }
  }

  // ── ВЫБОР ФОТО ────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final lang = appLanguage.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: Colors.blueAccent),
              title: Text(lang == 'ru' ? 'Сделать фото' : 'Суретке түсіру'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 80);
                if (f != null) setState(() => _photoFile = File(f.path));
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: Colors.blueAccent),
              title: Text(lang == 'ru' ? 'Выбрать из галереи' : 'Галереядан таңдау'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (f != null) setState(() => _photoFile = File(f.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── СОЗДАТЬ ЗАЯВКУ ────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category.isEmpty) {
      setState(() => _errorMsg = appLanguage.value == 'ru'
          ? 'Выберите тип услуги'
          : 'Қызмет түрін таңдаңыз');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      String? imageUrl;

      // Загружаем фото в Storage
      if (_photoFile != null) {
        final ext   = _photoFile!.path.split('.').last;
        final path  = 'orders/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final bytes = await _photoFile!.readAsBytes();
        await _supabase.storage.from('documents').uploadBinary(path, bytes);
        imageUrl = _supabase.storage.from('documents').getPublicUrl(path);
      }

      // Формируем данные заявки
      final data = <String, dynamic>{
        'title'        : _titleCtrl.text.trim(),
        'description'  : _descCtrl.text.trim(),
        'status'       : 'new',
        'priority'     : _priority,
        'user_id'      : userId,
        'category'     : _category,
        'address'      : _addrCtrl.text.trim(),
        'created_at'   : DateTime.now().toIso8601String(),
      };

      // Цена (опционально)
      final priceText = _priceCtrl.text.trim();
      if (priceText.isNotEmpty) {
        data['price'] = double.tryParse(priceText) ?? 0;
      }

      // Прикрепляем мастера, если пришли со страницы мастера
      if (widget.masterId.isNotEmpty) {
        data['master_id'] = widget.masterId;
        data['status']    = 'in_progress'; // сразу принял
      }

      // Квартира из профиля
      if (_userApartment != null && _userApartment!.isNotEmpty) {
        data['apartment'] = _userApartment;
      }

      if (imageUrl != null) data['image_url'] = imageUrl;

      await _supabase.from('tasks').insert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(appLanguage.value == 'ru'
              ? 'Заявка создана!'
              : 'Өтінім жасалды!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
          (r) => r.isFirst,
        );
      }
    } catch (e) {
      setState(() => _errorMsg = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg  = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            title: Text(
              lang == 'ru' ? 'Новая заявка' : 'Жаңа өтінім',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Мастер (если пришли с его страницы)
                  if (widget.masterName.isNotEmpty)
                    _buildMasterBanner(lang, isDark, cardBg),

                  // YOLO-заметка (если пришли из сканера)
                  if (widget.prefillDescription.isNotEmpty)
                    _buildYoloBanner(lang, isDark),

                  const SizedBox(height: 4),

                  // Тип услуги
                  _sectionLabel(lang == 'ru' ? 'Тип услуги *' : 'Қызмет түрі *', isDark),
                  const SizedBox(height: 8),
                  _buildCategoryGrid(lang, isDark, cardBg),

                  const SizedBox(height: 18),

                  // Название
                  _sectionLabel(lang == 'ru' ? 'Название *' : 'Атауы *', isDark),
                  const SizedBox(height: 8),
                  _buildField(
                    ctrl     : _titleCtrl,
                    hint     : lang == 'ru' ? 'Кратко опишите проблему' : 'Мәселені қысқаша сипаттаңыз',
                    icon     : LucideIcons.fileText,
                    isDark   : isDark,
                    validator: (v) => (v?.isEmpty ?? true)
                        ? (lang == 'ru' ? 'Введите название' : 'Атауды енгізіңіз')
                        : null,
                  ),

                  const SizedBox(height: 14),

                  // Описание
                  _sectionLabel(lang == 'ru' ? 'Подробное описание *' : 'Толық сипаттама *', isDark),
                  const SizedBox(height: 8),
                  _buildField(
                    ctrl     : _descCtrl,
                    hint     : lang == 'ru'
                        ? 'Что случилось? Где? Когда?'
                        : 'Не болды? Қайда? Қашан?',
                    icon     : LucideIcons.alignLeft,
                    isDark   : isDark,
                    maxLines : 4,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? (lang == 'ru'
                            ? 'Минимум 10 символов'
                            : 'Кем дегенде 10 таңба')
                        : null,
                  ),

                  const SizedBox(height: 14),

                  // Адрес
                  _sectionLabel(lang == 'ru' ? 'Адрес' : 'Мекенжай', isDark),
                  const SizedBox(height: 8),
                  _buildField(
                    ctrl    : _addrCtrl,
                    hint    : lang == 'ru' ? 'Улица, дом' : 'Көше, үй',
                    icon    : LucideIcons.mapPin,
                    isDark  : isDark,
                  ),

                  const SizedBox(height: 14),

                  // Ожидаемая цена (необязательно)
                  _sectionLabel(
                      lang == 'ru' ? 'Ожидаемая стоимость (₸)' : 'Күтілетін құн (₸)',
                      isDark),
                  const SizedBox(height: 8),
                  _buildField(
                    ctrl    : _priceCtrl,
                    hint    : lang == 'ru' ? 'Необязательно' : 'Міндетті емес',
                    icon    : LucideIcons.wallet,
                    isDark  : isDark,
                    keyboard: TextInputType.number,
                  ),

                  const SizedBox(height: 18),

                  // Приоритет
                  _sectionLabel(lang == 'ru' ? 'Срочность' : 'Шұғылдық', isDark),
                  const SizedBox(height: 8),
                  _buildPriorityRow(lang, isDark),

                  const SizedBox(height: 18),

                  // Фото
                  _sectionLabel(lang == 'ru' ? 'Фото неисправности' : 'Ақаулықтың фотосы', isDark),
                  const SizedBox(height: 8),
                  _buildPhotoArea(lang, isDark, cardBg),

                  // Ошибка
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Кнопка отправки
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.send,
                          color: Colors.white, size: 18),
                      label: Text(
                        lang == 'ru' ? 'Отправить заявку' : 'Өтінімді жіберу',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _submit,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── ВИДЖЕТЫ ──────────────────────────────────────────────

  Widget _buildMasterBanner(String lang, bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.userCheck,
              color: Colors.blueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${lang == 'ru' ? 'Мастер' : 'Шебер'}: ${widget.masterName}',
              style: const TextStyle(
                  color: Colors.blueAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYoloBanner(String lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.remove_red_eye_outlined,
              color: Colors.purple, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang == 'ru'
                  ? 'Данные заполнены автоматически из сканера'
                  : 'Деректер сканерден автоматты толтырылды',
              style: const TextStyle(color: Colors.purple, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(String lang, bool isDark, Color cardBg) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.entries.map((e) {
        final isSelected = _category == e.key;
        final label = lang == 'ru'
            ? e.value['ru'] as String
            : e.value['kz'] as String;
        final icon = e.value['icon'] as IconData;
        return GestureDetector(
          onTap: () => setState(() => _category = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blueAccent
                  : (isDark ? const Color(0xFF1A1A1C) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: isSelected ? Colors.white : Colors.blueAccent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityRow(String lang, bool isDark) {
    final priorities = {
      'low'   : {'ru': 'Низкая', 'kz': 'Төмен', 'color': Colors.green},
      'medium': {'ru': 'Средняя','kz': 'Орташа', 'color': Colors.orange},
      'high'  : {'ru': 'Высокая','kz': 'Жоғары', 'color': Colors.red},
    };
    return Row(
      children: priorities.entries.map((e) {
        final isSelected = _priority == e.key;
        final label = lang == 'ru'
            ? e.value['ru'] as String
            : e.value['kz'] as String;
        final color = e.value['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : (isDark ? const Color(0xFF1A1A1C) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.withOpacity(0.2),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? color
                              : (isDark ? Colors.white54 : Colors.black45))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoArea(String lang, bool isDark, Color cardBg) {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: _photoFile != null ? 180 : 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
            style: BorderStyle.solid,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _photoFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_photoFile!, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _photoFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(LucideIcons.x,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.camera,
                      size: 28,
                      color: isDark ? Colors.white38 : Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    lang == 'ru'
                        ? 'Нажмите чтобы добавить фото'
                        : 'Фото қосу үшін басыңыз',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: Colors.blueAccent, size: 18)
            : Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: Icon(icon, color: Colors.blueAccent, size: 18),
              ),
        prefixIconConstraints: maxLines > 1
            ? const BoxConstraints(minWidth: 40)
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle:
            const TextStyle(color: Colors.redAccent, fontSize: 11),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 12 : 14,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      );
}