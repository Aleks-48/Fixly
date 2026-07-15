// lib/screens/verification_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fixly_app/theme/app_theme.dart'; // Подключение единой дизайн-системы Fixly

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

  final Set<String> _missingColumns = {};

  String? _extractMissingColumn(Object error) {
    final match = RegExp(r'column [\w.]*\.([\w]+) does not exist')
        .firstMatch(error.toString());
    return match?.group(1);
  }

  Future<void> _loadCurrentStatus() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    Map<String, dynamic>? profile;
    for (var attempt = 0; attempt < 6; attempt++) {
      final cols = ['role', 'user_type', 'is_verified', 'specialty', 'description', 'experience_years']
          .where((c) => !_missingColumns.contains(c))
          .join(', ');
      try {
        profile = await _supabase
            .from('profiles')
            .select(cols)
            .eq('id', uid)
            .maybeSingle();
        break;
      } catch (e) {
        final missing = _extractMissingColumn(e);
        if (missing != null && !_missingColumns.contains(missing)) {
          _missingColumns.add(missing);
          continue;
        }
        debugPrint('VerificationScreen profile load: $e');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    final isChairman = BuildingContextService.normalizeRoleKey(
          profile?['role']?.toString(),
          profile?['user_type']?.toString(),
        ) ==
        'chairman';

    Map<String, dynamic>? verif;
    try {
      verif = await _supabase
          .from('verifications')
          .select('status')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('VerificationScreen verif status load: $e');
    }

    String status = 'none';
    if (profile?['is_verified'] == true) {
      status = 'verified';
    } else if (verif != null) {
      status = verif['status']?.toString() ?? 'pending';
    }

    List<Map<String, dynamic>> pending = [];
    if (isChairman) {
      for (var attempt = 0; attempt < 6; attempt++) {
        final joinCols = ['full_name', 'specialty', 'avatar_url', 'phone']
            .where((c) => !_missingColumns.contains(c))
            .join(', ');
        try {
          final resp = await _supabase
              .from('verifications')
              .select('*, profiles!verifications_user_id_fkey($joinCols)')
              .eq('status', 'pending')
              .order('created_at');
          pending = List<Map<String, dynamic>>.from(resp as List);
          break;
        } catch (e) {
          final missing = _extractMissingColumn(e);
          if (missing != null && !_missingColumns.contains(missing)) {
            _missingColumns.add(missing);
            continue;
          }
          debugPrint('VerificationScreen pending load: $e');
          break;
        }
      }
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
    final c = AppColors.of(context);
    if (_idPhoto == null) {
      _showSnack(appLanguage.value == 'ru'
          ? 'Загрузите фото удостоверения личности'
          : 'Жеке куәлік суретін жүктеңіз', c.warning);
      return;
    }

    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final idUrl      = await _uploadFile(_idPhoto!, 'verification/id');
      final selfieUrl  = _selfiePhoto != null
          ? await _uploadFile(_selfiePhoto!, 'verification/selfie')
          : null;

      await _supabase.from('profiles').update({
        'specialty'       : _selectedSpec,
        'description'     : _description.trim(),
        if (_experience.isNotEmpty)
          'experience_years': int.tryParse(_experience) ?? 0,
      }).eq('id', uid);

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
          c.success,
        );
      }
    } catch (e) {
      _showSnack('Ошибка: $e', c.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ПРЕДСЕДАТЕЛЬ: ОДОБРИТЬ / ОТКЛОНИТЬ ───────────────────
  Future<void> _reviewMaster(String verifId, String userId, bool approve) async {
    final lang = appLanguage.value;
    final c = AppColors.of(context);
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

      if (mounted) {
        _showSnack(
          approve
              ? (lang == 'ru' ? 'Мастер верифицирован ✓' : 'Шебер расталды ✓')
              : (lang == 'ru' ? 'Заявка отклонена' : 'Өтінім қабылданбады'),
          approve ? c.success : c.danger,
        );
      }

      _loadCurrentStatus();
    } catch (e) {
      _showSnack('Ошибка: $e', c.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: c.card,
            elevation: 0,
            title: Text(
              lang == 'ru' ? 'Верификация' : 'Верификация',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: c.textPrimary),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _isChairman
                  ? _buildChairmanView(context, lang)
                  : _buildMasterView(context, lang),
        );
      },
    );
  }

  // ── ВИД МАСТЕРА ──────────────────────────────────────────
  Widget _buildMasterView(BuildContext context, String lang) {
    final c = AppColors.of(context);

    if (_verifyStatus == 'verified') {
      return _buildStatusBanner(
        icon   : LucideIcons.badgeCheck,
        color  : c.success,
        title  : lang == 'ru' ? 'Аккаунт верифицирован' : 'Аккаунт расталды',
        subtitle: lang == 'ru'
            ? 'Ваш профиль подтверждён. Жители могут вас найти.'
            : 'Профиліңіз расталды. Тұрғындар сізді таба алады.',
      );
    }

    if (_verifyStatus == 'pending') {
      return _buildStatusBanner(
        icon    : LucideIcons.clock,
        color   : c.warning,
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
              color   : c.danger,
              title   : lang == 'ru' ? 'Заявка отклонена' : 'Өтінім қабылданбады',
              subtitle: lang == 'ru'
                  ? 'Попробуйте ещё раз с правильными документами.'
                  : 'Дұрыс құжаттармен қайталап көріңіз.',
            ),
            const SizedBox(height: 20),
            ..._buildForm(context, lang),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildForm(context, lang),
      ),
    );
  }

  List<Widget> _buildForm(BuildContext context, String lang) {
    final c = AppColors.of(context);

    return [
      // Инфо-баннер
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.primary.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info, color: c.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang == 'ru'
                    ? 'Верификация позволяет жителям доверять вам. Загрузите документы — председатель дома проверит их.'
                    : 'Верификация тұрғындардың сізге сенуіне мүмкіндік береді. Құжаттарды жүктеңіз.',
                style: TextStyle(fontSize: 13, color: c.primary),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Специализация
      _sectionLabel(context, lang == 'ru' ? 'Специализация' : 'Мамандық'),
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
                color: sel ? c.primary : c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? c.primary : c.textTertiary.withOpacity(0.3),
                ),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : c.textPrimary.withOpacity(0.8),
                  )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),

      // Опыт работы
      _sectionLabel(context, lang == 'ru' ? 'Лет опыта' : 'Тәжірибе (жыл)'),
      const SizedBox(height: 8),
      _buildTextField(
        context,
        value    : _experience,
        hint     : '5',
        icon     : LucideIcons.award,
        keyboard : TextInputType.number,
        onChanged: (v) => _experience = v,
      ),
      const SizedBox(height: 16),

      // Описание
      _sectionLabel(context, lang == 'ru' ? 'О себе' : 'Өзіңіз туралы'),
      const SizedBox(height: 8),
      _buildTextField(
        context,
        value    : _description,
        hint     : lang == 'ru' ? 'Опишите ваши навыки и опыт...' : 'Дағдыларыңызды сипаттаңыз...',
        icon     : LucideIcons.alignLeft,
        maxLines : 3,
        onChanged: (v) => _description = v,
      ),
      const SizedBox(height: 20),

      // Удостоверение личности
      _sectionLabel(
          context,
          '${lang == 'ru' ? 'Удостоверение личности' : 'Жеке куәлік'} *'),
      const SizedBox(height: 8),
      _buildPhotoCard(
        context,
        file    : _idPhoto,
        label   : lang == 'ru' ? 'Фото удостоверения' : 'Куәлік фотосы',
        icon    : LucideIcons.creditCard,
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
          context,
          '${lang == 'ru' ? 'Селфи с документом' : 'Құжатпен селфи'} (${lang == 'ru' ? 'необязательно' : 'міндетті емес'})'),
      const SizedBox(height: 8),
      _buildPhotoCard(
        context,
        file    : _selfiePhoto,
        label   : lang == 'ru' ? 'Фото лица с документом' : 'Жүзіңіздің фотосы',
        icon    : LucideIcons.user,
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
            backgroundColor: c.primary,
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
  Widget _buildChairmanView(BuildContext context, String lang) {
    final c = AppColors.of(context);

    if (_pendingMasters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 60, color: c.success.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              lang == 'ru' ? 'Нет заявок на верификацию' : 'Верификация өтінімдері жоқ',
              style: TextStyle(color: c.textTertiary, fontSize: 15),
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

        return _StaggeredEntrance(
          index: i,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.warning.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: c.primary.withOpacity(0.15),
                      backgroundImage: (avatar?.isNotEmpty == true)
                          ? NetworkImage(avatar!) : null,
                      child: (avatar?.isEmpty ?? true)
                          ? Text(name.isNotEmpty ? name[0] : '?',
                              style: TextStyle(
                                  color: c.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15, color: c.textPrimary)),
                          Text(
                            _specs[spec] ?? spec,
                            style: TextStyle(color: c.textTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang == 'ru' ? 'Ожидает' : 'Күтуде',
                        style: TextStyle(
                            color: c.warning, fontSize: 14, fontWeight: FontWeight.bold),
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
                        icon : Icon(LucideIcons.x, size: 16, color: c.danger),
                        label: Text(lang == 'ru' ? 'Отклонить' : 'Бас тарту',
                            style: TextStyle(color: c.danger)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.danger),
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
                          backgroundColor: c.success,
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
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(
    BuildContext context, {
    required File?    file,
    required String   label,
    required IconData icon,
    required VoidCallback  onTap,
    required VoidCallback  onGallery,
    required VoidCallback  onRemove,
  }) {
    final c = AppColors.of(context);

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
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.textTertiary.withOpacity(0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.camera, color: c.primary, size: 24),
                  const SizedBox(height: 6),
                  Text(appLanguage.value == 'ru' ? 'Камера' : 'Камера',
                      style: TextStyle(fontSize: 14, color: c.textTertiary)),
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
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.textTertiary.withOpacity(0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.image, color: c.primary, size: 24),
                  const SizedBox(height: 6),
                  Text(appLanguage.value == 'ru' ? 'Галерея' : 'Галерея',
                      style: TextStyle(fontSize: 14, color: c.textTertiary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String   value,
    required String   hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    final c = AppColors.of(context);

    return TextFormField(
      initialValue : value,
      maxLines     : maxLines,
      keyboardType : keyboard,
      onChanged    : onChanged,
      style: TextStyle(
          color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText  : hint,
        hintStyle : TextStyle(color: c.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, color: c.primary, size: 18),
        filled    : true,
        fillColor : c.surfaceVariant,
        border    : OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: c.textTertiary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 12 : 14),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final c = AppColors.of(context);
    return Text(text,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: c.textTertiary,
        ));
  }
}

// ============================================================
//  _StaggeredEntrance — та же лёгкая каскадная анимация появления
//  карточек, что и в masters_list_screen.dart: fade-in + сдвиг снизу
//  вверх, со ступенчатой задержкой по индексу элемента списка.
// ============================================================
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}