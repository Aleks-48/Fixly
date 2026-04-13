import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/main.dart';

// ============================================================
//  LibraryScreen — библиотека нормативных документов ЖК
//  • Загрузка документов из Supabase (таблица library_docs)
//  • Категории: законы, уставы, протоколы, инструкции
//  • Поиск по названию
//  • Открытие PDF/файлов через браузер
//  • Председатель: добавить документ по URL
// ============================================================
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _supabase   = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _isLoading  = true;
  bool   _isChairman = false;
  String _category   = 'all';

  static const _categories = {
    'all'      : 'Все',
    'law'      : 'Законы',
    'charter'  : 'Уставы',
    'protocol' : 'Протоколы',
    'guide'    : 'Инструкции',
    'other'    : 'Прочее',
  };
  static const _categoriesKz = {
    'all'      : 'Барлығы',
    'law'      : 'Заңдар',
    'charter'  : 'Жарғылар',
    'protocol' : 'Хаттамалар',
    'guide'    : 'Нұсқаулықтар',
    'other'    : 'Басқа',
  };

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadDocs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await _supabase
          .from('profiles').select('role').eq('id', uid).maybeSingle();
      if (mounted) setState(() => _isChairman = p?['role'] == 'chairman');
    } catch (_) {}
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('library_docs')
          .select('id, title, description, category, file_url, created_at')
          .order('category')
          .order('title');
      final resp = await query;
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(resp as List);
        setState(() { _all = list; _isLoading = false; });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('LibraryScreen: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((d) {
        final catOk = _category == 'all' ||
            d['category']?.toString() == _category;
        final searchOk = q.isEmpty ||
            (d['title']?.toString().toLowerCase() ?? '').contains(q) ||
            (d['description']?.toString().toLowerCase() ?? '').contains(q);
        return catOk && searchOk;
      }).toList();
    });
  }

  Future<void> _openDoc(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось открыть файл: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _addDoc() async {
    final lang   = appLanguage.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final urlCtrl   = TextEditingController();
    String selCat   = 'law';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(lang == 'ru' ? 'Добавить документ' : 'Құжат қосу',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 14),
              _tf(titleCtrl, lang == 'ru' ? 'Название *' : 'Атауы *',
                  LucideIcons.fileText, isDark),
              const SizedBox(height: 10),
              _tf(descCtrl, lang == 'ru' ? 'Описание' : 'Сипаттама',
                  LucideIcons.alignLeft, isDark, maxLines: 2),
              const SizedBox(height: 10),
              _tf(urlCtrl, 'URL файла (PDF, DOCX...) *',
                  LucideIcons.link, isDark,
                  keyboard: TextInputType.url),
              const SizedBox(height: 12),
              // Категория
              DropdownButtonFormField<String>(
                value: selCat,
                decoration: InputDecoration(
                  labelText: lang == 'ru' ? 'Категория' : 'Санат',
                  prefixIcon: const Icon(LucideIcons.folder,
                      color: Colors.blueAccent, size: 18),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                dropdownColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87),
                items: _categories.entries
                    .where((e) => e.key != 'all')
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setM(() => selCat = v ?? 'other'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty ||
                        urlCtrl.text.trim().isEmpty) return;
                    try {
                      await _supabase.from('library_docs').insert({
                        'title'      : titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'file_url'   : urlCtrl.text.trim(),
                        'category'   : selCat,
                        'created_at' : DateTime.now().toIso8601String(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadDocs();
                    } catch (e) { debugPrint('addDoc: $e'); }
                  },
                  child: Text(lang == 'ru' ? 'Добавить' : 'Қосу',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg  = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (_, lang, __) {
        final cats = lang == 'ru' ? _categories : _categoriesKz;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            title: Text(
              lang == 'ru' ? 'Библиотека' : 'Кітапхана',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            centerTitle: true,
            iconTheme:
                IconThemeData(color: isDark ? Colors.white : Colors.black87),
          ),
          floatingActionButton: _isChairman
              ? FloatingActionButton(
                  onPressed: _addDoc,
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(LucideIcons.plus, color: Colors.white),
                )
              : null,
          body: Column(
            children: [
              // Поиск
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilters(),
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: lang == 'ru' ? 'Поиск...' : 'Іздеу...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon:
                        const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              // Категории
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  children: cats.entries.map((e) {
                    final sel = _category == e.key;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _category = e.key);
                        _applyFilters();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.blueAccent
                              : (isDark
                                  ? const Color(0xFF1A1A1C)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? Colors.blueAccent
                                : Colors.grey.withOpacity(0.25),
                          ),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black87))),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Список
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? _buildEmpty(lang)
                        : RefreshIndicator(
                            onRefresh: _loadDocs,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 80),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _buildDocCard(
                                  _filtered[i], lang, isDark, cardBg),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc, String lang,
      bool isDark, Color cardBg) {
    final title   = doc['title']?.toString() ?? '';
    final desc    = doc['description']?.toString() ?? '';
    final cat     = doc['category']?.toString() ?? 'other';
    final url     = doc['file_url']?.toString();
    final date    =
        DateTime.tryParse(doc['created_at']?.toString() ?? '') ??
            DateTime.now();
    final catLabel = (lang == 'ru' ? _categories : _categoriesKz)[cat] ?? cat;
    final ext     = url?.split('.').last.toLowerCase() ?? '';
    final iconData = ext == 'pdf'
        ? LucideIcons.fileText
        : (ext == 'doc' || ext == 'docx'
            ? LucideIcons.fileType
            : LucideIcons.file);

    return GestureDetector(
      onTap: () => _openDoc(url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData,
                  color: Colors.blueAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(catLabel,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blueAccent)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd.MM.yy').format(date),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.externalLink,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang) => RefreshIndicator(
        onRefresh: _loadDocs,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 60),
            Icon(LucideIcons.bookOpen,
                size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              lang == 'ru' ? 'Документов нет' : 'Құжаттар жоқ',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );

  Widget _tf(TextEditingController ctrl, String hint, IconData icon,
      bool isDark,
      {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 18),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 12 : 14),
      ),
    );
  }
}