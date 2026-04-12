import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/models/order_model.dart';
import 'package:fixly_app/screens/order_details_page.dart';

class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;

  // Разбиваем по статусам для удобной работы
  List<OrderModel> _inProgressOrders = [];
  List<OrderModel> _newOrders        = [];
  List<OrderModel> _completedOrders  = [];

  // Статистика
  int    _completedCount = 0;
  double _totalIncome    = 0.0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMyOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── ЗАГРУЗКА ИЗ SUPABASE ───────────────────────────────────
  // ВАЖНО: таблица 'tasks', поле 'master_id'
  Future<void> _fetchMyOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('master_id', user.id)
          .order('created_at', ascending: false);

      final List<OrderModel> loaded = (response as List<dynamic>)
          .map((e) => OrderModel.fromMap(e as Map<String, dynamic>))
          .toList();

      final inProgress = <OrderModel>[];
      final newOrd     = <OrderModel>[];
      final completed  = <OrderModel>[];
      int    doneCount = 0;
      double income    = 0.0;

      for (final order in loaded) {
        if (order.isInProgress) {
          inProgress.add(order);
        } else if (order.isNew) {
          newOrd.add(order);
        } else if (order.isCompleted) {
          completed.add(order);
          doneCount++;
          income += order.finalPrice ?? order.price;
        }
      }

      if (mounted) {
        setState(() {
          _inProgressOrders = inProgress;
          _newOrders        = newOrd;
          _completedOrders  = completed;
          _completedCount   = doneCount;
          _totalIncome      = income;
          _isLoading        = false;
        });
      }
    } catch (e) {
      debugPrint('fetchMyOrders error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ИЗМЕНЕНИЕ СТАТУСА ─────────────────────────────────────
  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', orderId);

      // Лог изменения
      final lang = appLanguage.value;
      await Supabase.instance.client.from('task_logs').insert({
        'task_id'    : orderId,
        'action_text': newStatus == 'in_progress'
            ? (lang == 'ru' ? 'Мастер начал работу' : 'Шебер жұмысты бастады')
            : (lang == 'ru' ? 'Мастер завершил работу' : 'Шебер жұмысты аяқтады'),
        'created_at' : DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'in_progress'
                  ? (appLanguage.value == 'ru' ? 'Работа начата!' : 'Жұмыс басталды!')
                  : (appLanguage.value == 'ru' ? 'Работа завершена!' : 'Жұмыс аяқталды!'),
            ),
            backgroundColor: newStatus == 'in_progress' ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchMyOrders();
      }
    } catch (e) {
      debugPrint('updateStatus error: $e');
    }
  }

  // ── ПЕРЕХОД К ДЕТАЛЯМ ─────────────────────────────────────
  void _openDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsPage(order: order.toMap()),
      ),
    ).then((_) => _fetchMyOrders()); // обновить после возврата
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? 'Моя работа' : 'Менің жұмысым',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: lang == 'ru' ? 'В работе' : 'Жұмыста'),
                Tab(text: lang == 'ru' ? 'Новые' : 'Жаңа'),
                Tab(text: lang == 'ru' ? 'Готово' : 'Дайын'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Статистика сверху
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildStatsRow(lang, isDark),
                    ),
                    // Табы с заказами
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOrderList(_inProgressOrders, lang, isDark, 'in_progress'),
                          _buildOrderList(_newOrders, lang, isDark, 'new'),
                          _buildOrderList(_completedOrders, lang, isDark, 'completed'),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ── СТАТИСТИКА ─────────────────────────────────────────────
  Widget _buildStatsRow(String lang, bool isDark) {
    return Row(
      children: [
        _statCard(
          label: lang == 'ru' ? 'Выполнено' : 'Бітті',
          value: '$_completedCount',
          color: Colors.green,
          icon: LucideIcons.checkCircle,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: lang == 'ru' ? 'В работе' : 'Жұмыста',
          value: '${_inProgressOrders.length}',
          color: Colors.orange,
          icon: LucideIcons.clock,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: lang == 'ru' ? 'Доход ₸' : 'Табыс',
          value: _totalIncome >= 1000
              ? '${(_totalIncome / 1000).toStringAsFixed(1)}к'
              : '${_totalIncome.toInt()}',
          color: Colors.blueAccent,
          icon: LucideIcons.wallet,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  // ── СПИСОК ЗАКАЗОВ ─────────────────────────────────────────
  Widget _buildOrderList(
      List<OrderModel> orders, String lang, bool isDark, String tabStatus) {
    if (orders.isEmpty) {
      return _buildEmptyState(lang, tabStatus);
    }
    return RefreshIndicator(
      onRefresh: _fetchMyOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], lang, isDark);
        },
      ),
    );
  }

  // ── КАРТОЧКА ЗАКАЗА ────────────────────────────────────────
  Widget _buildOrderCard(OrderModel order, String lang, bool isDark) {
    final Color statusColor = order.isInProgress
        ? Colors.orange
        : (order.isCompleted ? Colors.green : Colors.blueAccent);

    return GestureDetector(
      onTap: () => _openDetails(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + цена
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.title.isNotEmpty ? order.title : '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  order.displayPrice,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Описание
            if (order.description.isNotEmpty)
              Text(
                order.description,
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            // Адрес
            if (order.address != null && order.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(LucideIcons.mapPin,
                      size: 13,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.address!,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Кнопка действия (только для не-завершённых)
            if (!order.isCompleted && !order.isCancelled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    order.isInProgress
                        ? LucideIcons.checkCircle
                        : LucideIcons.play,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: Text(
                    order.isInProgress
                        ? (lang == 'ru' ? 'Завершить' : 'Аяқтау')
                        : (lang == 'ru' ? 'Начать работу' : 'Бастау'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        order.isInProgress ? Colors.green : Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final nextStatus =
                        order.isInProgress ? 'completed' : 'in_progress';
                    _updateStatus(order.id, nextStatus);
                  },
                ),
              ),

            // Бейдж завершено
            if (order.isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.checkCircle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      lang == 'ru' ? 'Выполнено' : 'Орындалды',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ПУСТОЙ СТЕЙТ ───────────────────────────────────────────
  Widget _buildEmptyState(String lang, String status) {
    final IconData icon;
    final String text;
    if (status == 'in_progress') {
      icon = LucideIcons.hardHat;
      text = lang == 'ru'
          ? 'Нет заявок в работе'
          : 'Жұмыстағы тапсырыс жоқ';
    } else if (status == 'new') {
      icon = LucideIcons.inbox;
      text = lang == 'ru' ? 'Новых заявок нет' : 'Жаңа тапсырыс жоқ';
    } else {
      icon = LucideIcons.award;
      text = lang == 'ru'
          ? 'Завершённых заявок нет'
          : 'Аяқталған тапсырыс жоқ';
    }
    return RefreshIndicator(
      onRefresh: _fetchMyOrders,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Icon(icon, size: 64, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}