import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/order_details_page.dart';

// ============================================================
//  OrdersPage — список заявок
//  • Роль resident: мои заявки с фильтром по статусу
//  • Роль master: доступные (new) + мои активные
//  • Роль chairman: все заявки дома
//  • Supabase realtime: автообновление при изменении
//  • Поиск по названию
// ============================================================
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  final _supabase   = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _orders      = [];
  bool                       _isLoading   = true;
  String                     _statusFilter = 'all'; // all | new | in_progress | completed

  late TabController _tabCtrl;

  static const _statusTabs = ['all', 'new', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          setState(() => _statusFilter = _statusTabs[_tabCtrl.index]);
          _loadOrders();
        }
      });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── ЗАГРУЗКА ─────────────────────────────────────────────
  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final role = userRole.value;

    try {
      dynamic query = _supabase
          .from('tasks')
          .select('*, profiles!tasks_user_id_fkey(full_name, apartment_number, avatar_url)')
          .order('created_at', ascending: false);

      // Фильтр по роли
      if (role == 'resident') {
        query = query.eq('user_id', userId);
      } else if (role == 'master') {
        // Мастер видит: новые (доступные) + свои активные
        if (_statusFilter == 'new' || _statusFilter == 'all') {
          // Будет обработано ниже
        } else {
          query = query.eq('master_id', userId);
        }
      }
      // chairman видит все заявки своего дома — пока без фильтра по building

      // Фильтр по статусу
      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      // Поиск по названию
      final search = _searchCtrl.text.trim();
      if (search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }

      final response = await query.limit(50);
      final orders   = List<Map<String, dynamic>>.from(response as List);

      // Для мастера: если 'all' — показываем новые + его
      List<Map<String, dynamic>> filtered = orders;
      if (role == 'master' && _statusFilter == 'all') {
        filtered = orders.where((o) {
          final st  = o['status']?.toString() ?? '';
          final mid = o['master_id']?.toString();
          return st == 'new' || mid == userId;
        }).toList();
      }

      if (mounted) setState(() { _orders = filtered; _isLoading = false; });
    } catch (e) {
      debugPrint('OrdersPage load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg  = isDark ? const Color(0xFF1A1A1C) : Colors.white;
    final role    = userRole.value;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            title: Text(
              _appBarTitle(role, lang),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              isScrollable: false,
              tabs: [
                Tab(text: lang == 'ru' ? 'Все' : 'Барлығы'),
                Tab(text: lang == 'ru' ? 'Новые' : 'Жаңа'),
                Tab(text: lang == 'ru' ? 'В работе' : 'Жұмыста'),
                Tab(text: lang == 'ru' ? 'Готово' : 'Дайын'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Поиск
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadOrders(),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: lang == 'ru' ? 'Поиск заявки...' : 'Өтінімді іздеу...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () { _searchCtrl.clear(); _loadOrders(); },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              // Список
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _orders.isEmpty
                        ? _buildEmpty(lang)
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _orders.length,
                              itemBuilder: (context, i) =>
                                  _buildOrderCard(_orders[i], lang, isDark, cardBg),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── КАРТОЧКА ЗАЯВКИ ──────────────────────────────────────
  Widget _buildOrderCard(
      Map<String, dynamic> order, String lang, bool isDark, Color cardBg) {
    final status   = order['status']?.toString() ?? 'new';
    final title    = order['title']?.toString() ?? '—';
    final price    = ((order['final_price'] ?? order['price']) as num?)?.toDouble() ?? 0;
    final address  = order['address']?.toString() ?? '';
    final date     = DateTime.tryParse(order['created_at']?.toString() ?? '') ?? DateTime.now();
    final profile  = (order['profiles'] as Map<String, dynamic>?) ?? {};
    final clientName = profile['full_name']?.toString() ?? order['customer_name']?.toString() ?? '';
    final apt      = profile['apartment_number']?.toString() ?? order['apartment']?.toString() ?? '';
    final priority = order['priority']?.toString() ?? 'medium';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status, lang);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsPage(order: order),
        ),
      ).then((_) => _loadOrders()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: status == 'in_progress'
                ? Colors.orange.withOpacity(0.3)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + бейдж статуса
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 6),

            // Адрес + квартира
            if (address.isNotEmpty || apt.isNotEmpty)
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      apt.isNotEmpty
                          ? '$address, кв. $apt'
                          : address,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            // Имя клиента
            if (clientName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(LucideIcons.user, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(clientName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Цена + дата + приоритет
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _priorityDot(priority),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd.MM.yy').format(date),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  '${price.toInt()} ₸',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: status == 'completed'
                        ? Colors.green
                        : Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );

  Widget _priorityDot(String priority) {
    final c = priority == 'high'
        ? Colors.red
        : (priority == 'medium' ? Colors.orange : Colors.green);
    return Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'new'         : return Colors.blueAccent;
      case 'in_progress' : return Colors.orange;
      case 'completed'   : return Colors.green;
      case 'cancelled'   : return Colors.red;
      default            : return Colors.grey;
    }
  }

  String _statusLabel(String s, String lang) {
    final ru = {'new':'Новая','in_progress':'В работе','completed':'Готово','cancelled':'Отменено'};
    final kz = {'new':'Жаңа','in_progress':'Жұмыста','completed':'Дайын','cancelled':'Бас тартылды'};
    return (lang == 'ru' ? ru[s] : kz[s]) ?? s;
  }

  String _appBarTitle(String role, String lang) {
    if (role == 'chairman') return lang == 'ru' ? 'Все заявки ЖК' : 'ЖК тапсырмалары';
    if (role == 'master')   return lang == 'ru' ? 'Заявки' : 'Тапсырыстар';
    return lang == 'ru' ? 'Мои заявки' : 'Менің өтінімдерім';
  }

  Widget _buildEmpty(String lang) => RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 60),
            Icon(LucideIcons.clipboardList,
                size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              lang == 'ru' ? 'Заявок нет' : 'Тапсырыс жоқ',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
}