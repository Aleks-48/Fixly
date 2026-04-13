import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/main.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _supabase   = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading  = true;
  bool _isChairman = false;

  // Отдельные каналы для insert/delete (нет .all в 2.x)
  RealtimeChannel? _insertChannel;
  RealtimeChannel? _deleteChannel;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadAnnouncements();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _insertChannel?.unsubscribe();
    _deleteChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) setState(() => _isChairman = p?['role'] == 'chairman');
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _supabase
          .from('announcements')
          .select('id, title, content, author_id, is_urgent, created_at')
          .order('is_urgent', ascending: false)
          .order('created_at', ascending: false);
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(resp as List);
        setState(() {
          _all      = list;
          _filtered = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Announcements load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── REALTIME (supabase_flutter 2.x) ──────────────────────
  void _subscribeRealtime() {
    // INSERT
    _insertChannel = _supabase
        .channel('ann_insert')
        .onPostgresChanges(
          event   : PostgresChangeEvent.insert,
          schema  : 'public',
          table   : 'announcements',
          callback: (_) => _loadAnnouncements(),
        )
        .subscribe();

    // DELETE
    _deleteChannel = _supabase
        .channel('ann_delete')
        .onPostgresChanges(
          event   : PostgresChangeEvent.delete,
          schema  : 'public',
          table   : 'announcements',
          callback: (_) => _loadAnnouncements(),
        )
        .subscribe();
  }

  void _applySearch(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all.where((a) {
              final t = a['title']?.toString().toLowerCase() ?? '';
              final c = a['content']?.toString().toLowerCase() ?? '';
              return t.contains(query) || c.contains(query);
            }).toList();
    });
  }

  // ── СОЗДАТЬ ───────────────────────────────────────────────
  Future<void> _create() async {
    final lang   = appLanguage.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl   = TextEditingController();
    final contentCtrl = TextEditingController();
    bool  isUrgent    = false;

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
              Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Text(
                lang == 'ru' ? 'Новое объявление' : 'Жаңа хабарландыру',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),
              _field(titleCtrl, lang == 'ru' ? 'Заголовок *' : 'Тақырып *',
                  LucideIcons.type, isDark),
              const SizedBox(height: 12),
              _field(contentCtrl,
                  lang == 'ru' ? 'Текст...' : 'Мәтін...',
                  LucideIcons.alignLeft, isDark,
                  maxLines: 5),
              const SizedBox(height: 10),
              Row(
                children: [
                  Switch(
                    value    : isUrgent,
                    onChanged: (v) => setM(() => isUrgent = v),
                    activeColor: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang == 'ru' ? 'Срочное' : 'Шұғыл',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
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
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      await _supabase.from('announcements').insert({
                        'title'    : titleCtrl.text.trim(),
                        'content'  : contentCtrl.text.trim(),
                        'author_id': _supabase.auth.currentUser?.id,
                        'is_urgent': isUrgent,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      debugPrint('create ann: $e');
                    }
                  },
                  child: Text(
                    lang == 'ru' ? 'Опубликовать' : 'Жариялау',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final lang = appLanguage.value;
    final ok = await showDialog<bool>(
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
    if (ok == true) {
      try {
        await _supabase.from('announcements').delete().eq('id', id);
      } catch (e) {
        debugPrint('delete ann: $e');
      }
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
      builder: (_, lang, __) => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          title: Text(
            lang == 'ru' ? 'Объявления' : 'Хабарландырулар',
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
                onPressed: _create,
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
                onChanged: _applySearch,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText:
                      lang == 'ru' ? 'Поиск...' : 'Іздеу...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applySearch('');
                          })
                      : null,
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

            // Список
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? _buildEmpty(lang)
                      : RefreshIndicator(
                          onRefresh: _loadAnnouncements,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 80),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _buildCard(
                                _filtered[i], lang, isDark, cardBg),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ann, String lang,
      bool isDark, Color cardBg) {
    final id       = ann['id']?.toString() ?? '';
    final title    = ann['title']?.toString() ?? '';
    final content  = ann['content']?.toString() ?? '';
    final isUrgent = ann['is_urgent'] as bool? ?? false;
    final date     =
        DateTime.tryParse(ann['created_at']?.toString() ?? '') ??
            DateTime.now();

    return GestureDetector(
      onTap: () => _showDetail(ann, lang, isDark, cardBg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUrgent
                ? Colors.red.withOpacity(0.35)
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isUrgent ? Colors.red : Colors.blueAccent)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUrgent
                        ? LucideIcons.alertTriangle
                        : LucideIcons.bell,
                    color: isUrgent ? Colors.red : Colors.blueAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isUrgent) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lang == 'ru' ? 'СРОЧНО' : 'ШҰҒЫЛ',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                          ),
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(content,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (_isChairman)
                  IconButton(
                    icon: const Icon(LucideIcons.trash2,
                        color: Colors.red, size: 18),
                    onPressed: () => _delete(id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                const Icon(LucideIcons.clock,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM, HH:mm').format(date.toLocal()),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> ann, String lang,
      bool isDark, Color cardBg) {
    final title   = ann['title']?.toString() ?? '';
    final content = ann['content']?.toString() ?? '';
    final date    =
        DateTime.tryParse(ann['created_at']?.toString() ?? '') ??
            DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMMM yyyy, HH:mm', 'ru')
                    .format(date.toLocal()),
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12),
              ),
              const Divider(height: 24),
              Text(content,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang) => RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 60),
            Icon(LucideIcons.bellOff,
                size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              lang == 'ru'
                  ? 'Объявлений нет'
                  : 'Хабарландырулар жоқ',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController ctrl, String hint,
      IconData icon, bool isDark,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 18),
        filled: true,
        fillColor:
            isDark ? Colors.white10 : Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 12 : 14),
      ),
    );
  }
}