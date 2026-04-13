import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';

// ============================================================
//  PortfolioScreen — портфолио мастера
//  • Просмотр собственных работ (для мастера)
//  • Загрузка фото в Supabase Storage
//  • Добавление описания к каждой работе
//  • Удаление работ
//  • Просмотр чужого портфолио (передаётся masterId)
// ============================================================
class PortfolioScreen extends StatefulWidget {
  final String? masterId; // null = текущий пользователь

  const PortfolioScreen({super.key, this.masterId});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _supabase = Supabase.instance.client;

  bool   _isLoading  = true;
  bool   _isUploading = false;
  List<Map<String, dynamic>> _items = [];
  String _targetId   = '';
  bool   _isOwner    = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = _supabase.auth.currentUser?.id ?? '';
    _targetId = widget.masterId ?? uid;
    _isOwner  = widget.masterId == null || widget.masterId == uid;
    await _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _supabase
          .from('portfolio')
          .select('id, image_url, title, description, created_at')
          .eq('master_id', _targetId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _items     = List<Map<String, dynamic>>.from(resp as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PortfolioScreen load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ДОБАВИТЬ РАБОТУ ───────────────────────────────────────
  Future<void> _addWork() async {
    final lang  = appLanguage.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Выбираем фото
    final source = await showModalBottomSheet<ImageSource>(
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
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: Colors.blueAccent),
              title: Text(lang == 'ru' ? 'Из галереи' : 'Галереядан'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final xf = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1400);
    if (xf == null) return;
    final file = File(xf.path);

    // 2. Описание
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang == 'ru' ? 'Описание работы' : 'Жұмыс сипаттамасы',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Превью фото
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(file, height: 140, width: double.infinity,
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: lang == 'ru' ? 'Название (напр. Замена труб)' : 'Атауы',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: lang == 'ru' ? 'Краткое описание...' : 'Қысқаша сипаттама...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'ru' ? 'Отмена' : 'Бас тарту',
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang == 'ru' ? 'Добавить' : 'Қосу',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 3. Загружаем в Storage
    setState(() => _isUploading = true);
    try {
      final ext  = file.path.split('.').last;
      final path = 'portfolio/$_targetId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await file.readAsBytes();
      await _supabase.storage.from('documents').uploadBinary(path, bytes);
      final url = _supabase.storage.from('documents').getPublicUrl(path);

      await _supabase.from('portfolio').insert({
        'master_id'  : _targetId,
        'image_url'  : url,
        'title'      : titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'created_at' : DateTime.now().toIso8601String(),
      });

      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'ru' ? 'Работа добавлена!' : 'Жұмыс қосылды!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── УДАЛИТЬ РАБОТУ ────────────────────────────────────────
  Future<void> _deleteItem(String id, String imageUrl) async {
    final lang = appLanguage.value;
    final ok   = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == 'ru' ? 'Удалить?' : 'Өшіру?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang == 'ru' ? 'Нет' : 'Жоқ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang == 'ru' ? 'Удалить' : 'Өшіру',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _supabase.from('portfolio').delete().eq('id', id);
      // Также удаляем из Storage (извлекаем путь из URL)
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final storagePath = pathSegments.skip(
          pathSegments.indexWhere((s) => s == 'documents') + 1).join('/');
      if (storagePath.isNotEmpty) {
        try {
          await _supabase.storage.from('documents').remove([storagePath]);
        } catch (_) {}
      }
      _loadItems();
    } catch (e) {
      debugPrint('deleteItem: $e');
    }
  }

  // ── ПОЛНОЭКРАННЫЙ ПРОСМОТР ────────────────────────────────
  void _openFullscreen(int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullscreenGallery(items: _items, initialIndex: index),
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
              lang == 'ru' ? 'Портфолио' : 'Портфолио',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
          ),
          floatingActionButton: _isOwner
              ? FloatingActionButton(
                  onPressed: _isUploading ? null : _addWork,
                  backgroundColor: Colors.blueAccent,
                  child: _isUploading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(LucideIcons.plus, color: Colors.white),
                )
              : null,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _buildEmpty(lang, isDark)
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing  : 10,
                          childAspectRatio : 0.85,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, i) =>
                            _buildItem(_items[i], i, isDark, cardBg),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildItem(Map<String, dynamic> item, int index,
      bool isDark, Color cardBg) {
    final url   = item['image_url']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final id    = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openFullscreen(index),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Фото
            if (url.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: const Icon(LucideIcons.imageOff,
                        color: Colors.grey, size: 32),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: const Icon(LucideIcons.image,
                      color: Colors.grey, size: 32),
                ),
              ),

            // Градиент + название
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Кнопка удалить (только для владельца)
            if (_isOwner)
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => _deleteItem(id, url),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(LucideIcons.trash2,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.image,
              size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            lang == 'ru' ? 'Портфолио пустое' : 'Портфолио бос',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          if (_isOwner) ...[
            const SizedBox(height: 8),
            Text(
              lang == 'ru'
                  ? 'Нажмите + чтобы добавить работу'
                  : 'Жұмыс қосу үшін + басыңыз',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Полноэкранная галерея ─────────────────────────────────
class _FullscreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;
  const _FullscreenGallery({required this.items, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current  = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          item['title']?.toString() ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final url = widget.items[i]['image_url']?.toString() ?? '';
                return InteractiveViewer(
                  child: Center(
                    child: url.isNotEmpty
                        ? Image.network(url, fit: BoxFit.contain)
                        : const Icon(LucideIcons.imageOff,
                            color: Colors.grey, size: 48),
                  ),
                );
              },
            ),
          ),
          // Описание
          if ((item['description']?.toString() ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Text(
                item['description'].toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          // Индикатор страниц
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) => Container(
                width: 6, height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _current ? Colors.white : Colors.white30,
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}