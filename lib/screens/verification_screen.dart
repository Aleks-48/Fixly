import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ============================================================
//  VerificationScreen — верификация мастера
//  • Загрузка удостоверения личности в Supabase Storage
//  • Загрузка фото с работ (портфолио при верификации)
//  • Выбор специализации
//  • Сохранение статуса в profiles + таблицу verifications
//  • Для председателя: список ожидающих + кнопка одобрить/отклонить
// ============================================================
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _supabase = Supabase.instance.client;

  bool   _isLoading    = false;
  bool   _isChairman   = false;
  String _verifyStatus = 'none'; // none | pending | verified | rejected

  File?  _idPhoto;
  File?  _selfiePhoto;
  String _selectedSpec = 'plumber';
  String _experience   = '';
  String _description  = '';

  // Для председателя — список ожидающих верификации
  List<Map<String, dynamic>> _pendingMasters = [];

  static const _specs = {
    'plumber'    : 'Сантехник',
    'electrician': 'Электрик',
    'painter'    : 'Отделочник',
    'carpenter'  : 'Плотник',
    'welder'     : 'Сварщик',
    'locksmith'  : 'Слесарь',
    'cleaner'    : 'Уборщик',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('role, is_verified, specialty, description, experience_years')
          .eq('id', uid)
          .maybeSingle();

      final isChairman = profile?['role'] == 'chairman';

      // Статус верификации из таблицы
      final verif = await _supabase
          .from('verifications')
          .select('status')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String status = 'none';
      if (profile?['is_verified'] == true) {
        status = 'verified';
      } else if (verif != null) {
        status = verif['status']?.toString() ?? 'pending';
      }

      // Для председателя загружаем список ожидающих
      List<Map<String, dynamic>> pending = [];
      if (isChairman) {
        final resp = await _supabase
            .from('verifications')
            .select('*, profiles!verifications_user_id_fkey(full_name, specialty, avatar_url, phone)')
            .eq('status', 'pending')
            .order('created_at');
        pending = List<Map<String, dynamic>>.from(resp as List);
      }

      if (mounted) {
        setState(() {
          _isChairman   = isChairman;
          _verifyStatus = status;
          _selectedSpec = profile?['specialty']?.toString() ?? 'plumber';
          _description  = profile?['description']?.toString() ?? '';
          _experience   = profile?['experience_years']?.toString() ?? '';
          _pendingMasters = pending;
          _isLoading    = false;
        });
      }
    } catch (e) {
      debugPrint('VerificationScreen load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ВЫБРАТЬ ФОТО ─────────────────────────────────────────
  Future<File?> _pickImage(ImageSource source) async {
    final xf = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1500);
    return xf != null ? File(xf.path) : null;
  }

  // ── ЗАГРУЗИТЬ ФАЙЛ В STORAGE ──────────────────────────────
  Future<String?> _uploadFile(File file, String folder) async {
    final uid  = _supabase.auth.currentUser?.id;
    final ext  = file.path.split('.').last;
    final path = '$folder/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _supabase.storage.from('documents').uploadBinary(path, bytes);
    return _supabase.storage.from('documents').getPublicUrl(path);
  }

  // ── ОТПРАВИТЬ ЗАЯВКУ НА ВЕРИФИКАЦИЮ ──────────────────────
  Future<void> _submitVerification() async {
    if (_idPhoto == null) {
      _showSnack(appLanguage.value == 'ru'
          ? 'Загрузите фото удостоверения личности'
          : 'Жеке куәлік суретін жүктеңіз', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Загружаем документы
      final idUrl      = await _uploadFile(_idPhoto!, 'verification/id');
      final selfieUrl  = _selfiePhoto != null
          ? await _uploadFile(_selfiePhoto!, 'verification/selfie')
          : null;

      // Обновляем профиль
      await _supabase.from('profiles').update({
        'specialty'       : _selectedSpec,
        'description'     : _description.trim(),
        if (_experience.isNotEmpty)
          'experience_years': int.tryParse(_experience) ?? 0,
      }).eq('id', uid);

      // Создаём заявку на верификацию
      await _supabase.from('verifications').upsert({
        'user_id'      : uid,
        'status'       : 'pending',
        'id_photo_url' : idUrl,
        if (selfieUrl != null) 'selfie_url': selfieUrl,
        'created_at'   : DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        setState(() => _verifyStatus = 'pending');
        _showSnack(
          appLanguage.value == 'ru'
              ? 'Заявка отправлена! Председатель проверит её в ближайшее время.'
              : 'Өтінім жіберілді! Төраға жақын арада тексереді.',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ПРЕДСЕДАТЕЛЬ: ОДОБРИТЬ / ОТКЛОНИТЬ ───────────────────
  Future<void> _reviewMaster(String verifId, String userId, bool approve) async {
    final lang = appLanguage.value;
    try {
      final newStatus = approve ? 'verified' : 'rejected';

      await _supabase
          .from('verifications')
          .update({'status': newStatus, 'reviewed_at': DateTime.now().toIso8601String()})
          .eq('id', verifId);

      await _supabase
          .from('profiles')
          .update({'is_verified': approve})
          .eq('id', userId);

      _showSnack(
        approve
            ? (lang == 'ru' ? 'Мастер верифицирован ✓' : 'Шебер расталды ✓')
            : (lang == 'ru' ? 'Заявка отклонена' : 'Өтінім қабылданбады'),
        approve ? Colors.green : Colors.red,
      );

      _loadCurrentStatus();
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
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
              lang == 'ru' ? 'Верификация' : 'Верификация',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isChairman
                  ? _buildChairmanView(lang, isDark, cardBg)
                  : _buildMasterView(lang, isDark, cardBg),
        );
      },
    );
  }

  // ── ВИД МАСТЕРА ──────────────────────────────────────────
  Widget _buildMasterView(String lang, bool isDark, Color cardBg) {
    if (_verifyStatus == 'verified') {
      return _buildStatusBanner(
        icon   : LucideIcons.badgeCheck,
        color  : Colors.green,
        title  : lang == 'ru' ? 'Аккаунт верифицирован' : 'Аккаунт расталды',
        subtitle: lang == 'ru'
            ? 'Ваш профиль подтверждён. Жители могут вас найти.'
            : 'Профиліңіз расталды. Тұрғындар сізді таба алады.',
      );
    }

    if (_verifyStatus == 'pending') {
      return _buildStatusBanner(
        icon    : LucideIcons.clock,
        color   : Colors.orange,
        title   : lang == 'ru' ? 'Заявка на проверке' : 'Өтінім тексерілуде',
        subtitle: lang == 'ru'
            ? 'Председатель дома проверит вашу заявку в ближайшее время.'
            : 'Үй төрағасы өтінімді жақын арада тексереді.',
      );
    }

    if (_verifyStatus == 'rejected') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusBannerInline(
              icon    : LucideIcons.xCircle,
              color   : Colors.red,
              title   : lang == 'ru' ? 'Заявка отклонена' : 'Өтінім қабылданбады',
              subtitle: lang == 'ru'
                  ? 'Попробуйте ещё раз с правильными документами.'
                  : 'Дұрыс құжаттармен қайталап көріңіз.',
            ),
            const SizedBox(height: 20),
            ..._buildForm(lang, isDark, cardBg),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildForm(lang, isDark, cardBg),
      ),
    );
  }

  List<Widget> _buildForm(String lang, bool isDark, Color cardBg) {
    return [
      // Инфо-баннер
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.info, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang == 'ru'
                    ? 'Верификация позволяет жителям доверять вам. Загрузите документы — председатель дома проверит их.'
                    : 'Верификация тұрғындардың сізге сенуіне мүмкіндік береді. Құжаттарды жүктеңіз.',
                style: const TextStyle(fontSize: 13, color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Специализация
      _sectionLabel(lang == 'ru' ? 'Специализация' : 'Мамандық', isDark),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _specs.entries.map((e) {
          final sel = _selectedSpec == e.key;
          return GestureDetector(
            onTap: () => setState(() => _selectedSpec = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? Colors.blueAccent : (isDark ? const Color(0xFF1A1A1C) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? Colors.blueAccent : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),

      // Опыт работы
      _sectionLabel(lang == 'ru' ? 'Лет опыта' : 'Тәжірибе (жыл)', isDark),
      const SizedBox(height: 8),
      _buildTextField(
        value    : _experience,
        hint     : '5',
        icon     : LucideIcons.award,
        keyboard : TextInputType.number,
        isDark   : isDark,
        onChanged: (v) => _experience = v,
      ),
      const SizedBox(height: 16),

      // Описание
      _sectionLabel(lang == 'ru' ? 'О себе' : 'Өзіңіз туралы', isDark),
      const SizedBox(height: 8),
      _buildTextField(
        value    : _description,
        hint     : lang == 'ru' ? 'Опишите ваши навыки и опыт...' : 'Дағдыларыңызды сипаттаңыз...',
        icon     : LucideIcons.alignLeft,
        isDark   : isDark,
        maxLines : 3,
        onChanged: (v) => _description = v,
      ),
      const SizedBox(height: 20),

      // Удостоверение личности
      _sectionLabel(
          '${lang == 'ru' ? 'Удостоверение личности' : 'Жеке куәлік'} *',
          isDark),
      const SizedBox(height: 8),
      _buildPhotoCard(
        file    : _idPhoto,
        label   : lang == 'ru' ? 'Фото удостоверения' : 'Куәлік фотосы',
        icon    : LucideIcons.creditCard,
        isDark  : isDark,
        onTap   : () async {
          final f = await _pickImage(ImageSource.camera);
          if (f != null) setState(() => _idPhoto = f);
        },
        onGallery: () async {
          final f = await _pickImage(ImageSource.gallery);
          if (f != null) setState(() => _idPhoto = f);
        },
        onRemove: () => setState(() => _idPhoto = null),
      ),
      const SizedBox(height: 14),

      // Селфи (опционально)
      _sectionLabel(
          '${lang == 'ru' ? 'Селфи с документом' : 'Құжатпен селфи'} (${lang == 'ru' ? 'необязательно' : 'міндетті емес'})',
          isDark),
      const SizedBox(height: 8),
      _buildPhotoCard(
        file    : _selfiePhoto,
        label   : lang == 'ru' ? 'Фото лица с документом' : 'Жүзіңіздің фотосы',
        icon    : LucideIcons.user,
        isDark  : isDark,
        onTap   : () async {
          final f = await _pickImage(ImageSource.camera);
          if (f != null) setState(() => _selfiePhoto = f);
        },
        onGallery: () async {
          final f = await _pickImage(ImageSource.gallery);
          if (f != null) setState(() => _selfiePhoto = f);
        },
        onRemove: () => setState(() => _selfiePhoto = null),
      ),
      const SizedBox(height: 24),

      // Кнопка отправки
      SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton.icon(
          icon : const Icon(LucideIcons.send, color: Colors.white, size: 18),
          label: Text(
            lang == 'ru' ? 'Отправить на проверку' : 'Тексеруге жіберу',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _submitVerification,
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  // ── ВИД ПРЕДСЕДАТЕЛЯ ─────────────────────────────────────
  Widget _buildChairmanView(String lang, bool isDark, Color cardBg) {
    if (_pendingMasters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 60, color: Colors.green.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              lang == 'ru' ? 'Нет заявок на верификацию' : 'Верификация өтінімдері жоқ',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingMasters.length,
      itemBuilder: (context, i) {
        final item    = _pendingMasters[i];
        final profile = (item['profiles'] as Map<String, dynamic>?) ?? {};
        final name    = profile['full_name']?.toString() ?? '—';
        final spec    = profile['specialty']?.toString() ?? '';
        final avatar  = profile['avatar_url']?.toString();
        final verifId = item['id']?.toString() ?? '';
        final userId  = item['user_id']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blueAccent.withOpacity(0.15),
                    backgroundImage: (avatar?.isNotEmpty == true)
                        ? NetworkImage(avatar!) : null,
                    child: (avatar?.isEmpty ?? true)
                        ? Text(name.isNotEmpty ? name[0] : '?',
                            style: const TextStyle(
                                color: Colors.blueAccent, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          _specs[spec] ?? spec,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      lang == 'ru' ? 'Ожидает' : 'Күтуде',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              // Фото документов
              if (item['id_photo_url'] != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item['id_photo_url'],
                    height: 120, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Кнопки одобрить/отклонить
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon : const Icon(LucideIcons.x, size: 16, color: Colors.red),
                      label: Text(lang == 'ru' ? 'Отклонить' : 'Бас тарту',
                          style: const TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _reviewMaster(verifId, userId, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon : const Icon(LucideIcons.check, size: 16, color: Colors.white),
                      label: Text(lang == 'ru' ? 'Одобрить' : 'Мақұлдау',
                          style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _reviewMaster(verifId, userId, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ───────────────────────────────
  Widget _buildStatusBanner({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBannerInline({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard({
    required File?    file,
    required String   label,
    required IconData icon,
    required bool     isDark,
    required VoidCallback  onTap,
    required VoidCallback  onGallery,
    required VoidCallback  onRemove,
  }) {
    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file,
                height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.camera, color: Colors.blueAccent, size: 24),
                  const SizedBox(height: 6),
                  const Text('Камера',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onGallery,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.image, color: Colors.blueAccent, size: 24),
                  const SizedBox(height: 6),
                  const Text('Галерея',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String   value,
    required String   hint,
    required IconData icon,
    required bool     isDark,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      initialValue : value,
      maxLines     : maxLines,
      keyboardType : keyboard,
      onChanged    : onChanged,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText  : hint,
        hintStyle : const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 18),
        filled    : true,
        fillColor : isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        border    : OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 12 : 14),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(text,
      style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: isDark ? Colors.white60 : Colors.black54,
      ));
}