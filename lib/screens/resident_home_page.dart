import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/defect_scanner_screen.dart';
import 'package:fixly_app/screens/announcements_screen.dart';

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final _supabase = Supabase.instance.client;

  String _fullName  = '';
  String _avatarUrl = '';
  int    _apartment = 0;

  int    _mastersCount  = 0;
  int    _activeVotes   = 0;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _myOrders      = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Future.wait([
        _loadProfile(uid),
        _loadAnnouncements(),
        _loadMyOrders(uid),
        _loadStats(),
      ]);
    } catch (e) {
      debugPrint('ResidentHome: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final p = await _supabase
          .from('profiles')
          .select('full_name, avatar_url, apartment_number')
          .eq('id', uid)
          .maybeSingle();
      if (p != null && mounted) {
        setState(() {
          _fullName  = p['full_name']?.toString() ?? '';
          _avatarUrl = p['avatar_url']?.toString() ?? '';
          _apartment = (p['apartment_number'] as int?) ?? 0;
        });
      }
    } catch (e) { debugPrint('loadProfile: $e'); }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final resp = await _supabase
          .from('announcements')
          .select('id, title, content, created_at, is_urgent')
          .order('is_urgent', ascending: false)
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) {
        setState(() => _announcements =
            List<Map<String, dynamic>>.from(resp as List));
      }
    } catch (e) { debugPrint('loadAnn: $e'); }
  }

  Future<void> _loadMyOrders(String uid) async {
    try {
      final resp = await _supabase
          .from('tasks')
          .select('id, title, status, created_at')
          .eq('user_id', uid)
          .inFilter('status', ['new', 'in_progress'])
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() => _myOrders =
            List<Map<String, dynamic>>.from(resp as List));
      }
    } catch (e) { debugPrint('loadOrders: $e'); }
  }

  // ── FIX: убрали FetchOptions(count:) — он не поддерживается в ───
  //         supabase_flutter 2.x так. Считаем через length.
  Future<void> _loadStats() async {
    try {
      final masters = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'master')
          .eq('is_verified', true);
      final votes = await _supabase
          .from('proposals')
          .select('id')
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          _mastersCount = (masters as List).length;
          _activeVotes  = (votes as List).length;
        });
      }
    } catch (e) { debugPrint('loadStats: $e'); }
  }

  String get _greeting {
    final h    = DateTime.now().hour;
    final lang = appLanguage.value;
    if (h < 12) return lang == 'ru' ? 'Доброе утро' : 'Қайырлы таң';
    if (h < 17) return lang == 'ru' ? 'Добрый день' : 'Қайырлы күн';
    return lang == 'ru' ? 'Добрый вечер' : 'Қайырлы кеш';
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg  = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (_, lang, __) => Scaffold(
        backgroundColor: bgColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: _buildHeader(lang, isDark)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 20),
                          _buildQuickActions(lang, isDark),
                          const SizedBox(height: 24),
                          if (_myOrders.isNotEmpty) ...[
                            _sectionHeader(
                              lang == 'ru'
                                  ? 'Мои активные заявки'
                                  : 'Менің белсенді өтінімдерім',
                              LucideIcons.clipboardList,
                              lang == 'ru' ? 'Все' : 'Барлығы',
                              () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const OrdersPage())),
                              isDark,
                            ),
                            const SizedBox(height: 10),
                            ..._myOrders.map((o) =>
                                _buildOrderChip(o, lang, isDark, cardBg)),
                            const SizedBox(height: 24),
                          ],
                          _sectionHeader(
                            lang == 'ru'
                                ? 'Объявления ЖК'
                                : 'ЖК хабарландырулары',
                            LucideIcons.bell,
                            lang == 'ru' ? 'Все' : 'Барлығы',
                            () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AnnouncementsScreen())),
                            isDark,
                          ),
                          const SizedBox(height: 10),
                          _announcements.isEmpty
                              ? _buildNoAnn(lang, isDark, cardBg)
                              : Column(
                                  children: _announcements
                                      .map((a) => _buildAnnCard(
                                          a, isDark, cardBg))
                                      .toList(),
                                ),
                          const SizedBox(height: 24),
                          _buildStatsRow(lang, isDark, cardBg),
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(String lang, bool isDark) {
    final firstName = _fullName.split(' ').firstOrNull ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting,',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
                Text(
                  firstName.isNotEmpty ? firstName : 'Житель',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                if (_apartment > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${lang == 'ru' ? 'Квартира' : 'Пәтер'} #$_apartment',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: _avatarUrl.isNotEmpty
                ? NetworkImage(_avatarUrl) : null,
            child: _avatarUrl.isEmpty
                ? Text(
                    _fullName.isNotEmpty
                        ? _fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(String lang, bool isDark) {
    final actions = [
      (
        icon : LucideIcons.users,
        color: Colors.blueAccent,
        label: lang == 'ru' ? 'Найти\nмастера' : 'Шебер\nтабу',
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const MastersListScreen())),
      ),
      (
        icon : LucideIcons.plusCircle,
        color: Colors.green,
        label: lang == 'ru' ? 'Создать\nзаявку' : 'Өтінім\nжасау',
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const CreateOrderPage())),
      ),
      (
        icon : Icons.remove_red_eye_outlined,
        color: Colors.purple,
        label: lang == 'ru' ? 'Сканер\nнеис.' : 'Ақауды\nсканерлеу',
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const DefectScannerScreen())),
      ),
      (
        icon : LucideIcons.vote,
        color: Colors.orange,
        label: lang == 'ru' ? 'Голосо-\nвание' : 'Дауыс\nберу',
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const OrdersPage())),
      ),
    ];

    return Row(
      children: actions.map((a) => Expanded(
        child: GestureDetector(
          onTap: a.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: (a.color as Color).withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: (a.color as Color).withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Icon(a.icon as IconData,
                    color: a.color as Color, size: 22),
                const SizedBox(height: 7),
                Text(
                  a.label as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: a.color as Color,
                      height: 1.2),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildOrderChip(Map<String, dynamic> order, String lang,
      bool isDark, Color cardBg) {
    final status = order['status']?.toString() ?? 'new';
    final title  = order['title']?.toString() ?? '—';
    final isIP   = status == 'in_progress';
    final color  = isIP ? Colors.orange : Colors.blueAccent;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const OrdersPage())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                isIP
                    ? (lang == 'ru' ? 'В работе' : 'Жұмыста')
                    : (lang == 'ru' ? 'Новая' : 'Жаңа'),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnCard(
      Map<String, dynamic> ann, bool isDark, Color cardBg) {
    final title    = ann['title']?.toString() ?? '';
    final content  = ann['content']?.toString() ?? '';
    final isUrgent = ann['is_urgent'] as bool? ?? false;
    final date     =
        DateTime.tryParse(ann['created_at']?.toString() ?? '') ??
            DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? Colors.red.withOpacity(0.3)
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
        ),
      ),
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
                  child: const Text('СРОЧНО',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(DateFormat('dd.MM').format(date),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(content,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _buildNoAnn(String lang, bool isDark, Color cardBg) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.bellOff,
                color: Colors.grey.withOpacity(0.5), size: 18),
            const SizedBox(width: 12),
            Text(
              lang == 'ru' ? 'Объявлений пока нет' : 'Хабарландырулар жоқ',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _buildStatsRow(String lang, bool isDark, Color cardBg) =>
      Row(
        children: [
          _statCard(
            '$_mastersCount',
            lang == 'ru' ? 'Мастеров в базе' : 'Базадағы шебер',
            LucideIcons.hardHat,
            Colors.blueAccent,
            isDark, cardBg,
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MastersListScreen())),
          ),
          const SizedBox(width: 12),
          _statCard(
            '$_activeVotes',
            lang == 'ru' ? 'Голосований' : 'Дауыс беру',
            LucideIcons.vote,
            Colors.orange,
            isDark, cardBg,
            null,
          ),
        ],
      );

  Widget _statCard(String value, String label, IconData icon,
      Color color, bool isDark, Color cardBg, VoidCallback? onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionHeader(String title, IconData icon, String action,
      VoidCallback onTap, bool isDark) =>
      Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87)),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(action,
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
}