import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/main.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  bool   _isLoading   = true;
  String _period      = 'month'; // week | month | year

  double _totalIncome    = 0;
  double _avgCheck       = 0;
  int    _completedCount = 0;
  double _bestMonthIncome = 0;
  String _bestMonthLabel  = '';
  List<_MonthBar>            _chartData    = [];
  List<Map<String, dynamic>> _recentOrders = [];

  late TabController _tabCtrl;
  bool _tabListenerActive = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _tabListenerActive = true;
    _loadData();
  }

  // ── FIX: слушатель срабатывает дважды — проверяем indexIsChanging ─
  void _onTabChanged() {
    if (!_tabListenerActive || _tabCtrl.indexIsChanging) return;
    final periods = ['week', 'month', 'year'];
    if (_period != periods[_tabCtrl.index]) {
      _period = periods[_tabCtrl.index];
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabListenerActive = false;
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      DateTime from;
      switch (_period) {
        case 'week' : from = now.subtract(const Duration(days: 7));  break;
        case 'year' : from = DateTime(now.year - 1, now.month, 1);   break;
        default     : from = DateTime(now.year, now.month - 5, 1);
      }

      final response = await _supabase
          .from('tasks')
          .select('id, title, final_price, price, created_at, customer_name')
          .eq('master_id', userId)
          .eq('status', 'completed')
          .gte('created_at', from.toIso8601String())
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(response as List);
      double total = 0;
      final Map<String, double> byMonth = {};

      for (final o in orders) {
        final amount =
            ((o['final_price'] ?? o['price']) as num?)?.toDouble() ?? 0;
        total += amount;
        final date = DateTime.tryParse(o['created_at']?.toString() ?? '') ??
            now;
        // FIX: не используем locale — избегаем initializeDateFormatting
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        byMonth[key] = (byMonth[key] ?? 0) + amount;
      }

      // График — 6 месяцев
      final chartData = <_MonthBar>[];
      final monthNames = ['Янв','Фев','Мар','Апр','Май','Июн',
                          'Июл','Авг','Сен','Окт','Ноя','Дек'];
      for (int i = 5; i >= 0; i--) {
        final m   = DateTime(now.year, now.month - i, 1);
        final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
        chartData.add(_MonthBar(
          label : monthNames[m.month - 1],
          amount: byMonth[key] ?? 0,
        ));
      }

      // Лучший месяц
      double bestVal   = 0;
      String bestLabel = '';
      byMonth.forEach((k, v) {
        if (v > bestVal) {
          bestVal   = v;
          // Форматируем ключ yyyy-MM → читаемое
          final parts = k.split('-');
          if (parts.length == 2) {
            final mIdx = (int.tryParse(parts[1]) ?? 1) - 1;
            bestLabel = '${monthNames[mIdx]} ${parts[0]}';
          }
        }
      });

      if (mounted) {
        setState(() {
          _totalIncome    = total;
          _completedCount = orders.length;
          _avgCheck       = orders.isEmpty ? 0 : total / orders.length;
          _chartData      = chartData;
          _bestMonthIncome = bestVal;
          _bestMonthLabel  = bestLabel;
          _recentOrders   = orders.take(10).toList();
          _isLoading      = false;
        });
      }
    } catch (e) {
      debugPrint('IncomeScreen: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          title: Text(
            lang == 'ru' ? 'Мои доходы' : 'Менің табысым',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
          ),
          centerTitle: true,
          iconTheme:
              IconThemeData(color: isDark ? Colors.white : Colors.black87),
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: lang == 'ru' ? 'Неделя' : 'Апта'),
              Tab(text: lang == 'ru' ? '6 месяцев' : '6 ай'),
              Tab(text: lang == 'ru' ? 'Год' : 'Жыл'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalCard(lang, isDark),
                      const SizedBox(height: 16),
                      _buildMetrics(lang, isDark, cardBg),
                      const SizedBox(height: 20),
                      Text(
                        lang == 'ru' ? 'Доход по месяцам' : 'Айлық табыс',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      _buildChart(isDark, cardBg),
                      const SizedBox(height: 24),
                      Text(
                        lang == 'ru' ? 'Последние заказы' : 'Соңғы тапсырыстар',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      _recentOrders.isEmpty
                          ? _buildEmpty(lang)
                          : Column(
                              children: _recentOrders
                                  .map((o) => _buildOrderRow(o, isDark, cardBg))
                                  .toList(),
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTotalCard(String lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wallet,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                lang == 'ru' ? 'Общий доход' : 'Жалпы табыс',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmt(_totalIncome)} ₸',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1),
          ),
          if (_bestMonthLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${lang == 'ru' ? 'Лучший' : 'Үздік'}: $_bestMonthLabel — ${_fmt(_bestMonthIncome)} ₸',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetrics(String lang, bool isDark, Color cardBg) {
    return Row(
      children: [
        _metricCard(
          lang == 'ru' ? 'Заказов' : 'Тапсырыс',
          '$_completedCount',
          LucideIcons.checkCircle,
          Colors.green, isDark, cardBg,
        ),
        const SizedBox(width: 12),
        _metricCard(
          lang == 'ru' ? 'Средний чек' : 'Орт. төлем',
          '${_fmt(_avgCheck)} ₸',
          LucideIcons.trendingUp,
          Colors.orange, isDark, cardBg,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon,
      Color color, bool isDark, Color cardBg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(bool isDark, Color cardBg) {
    if (_chartData.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18)),
        child: const Center(
            child: Text('Нет данных',
                style: TextStyle(color: Colors.grey))),
      );
    }
    final maxVal = _chartData.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _chartData.map((d) {
                final pct   = maxVal > 0 ? d.amount / maxVal : 0.0;
                final isMax = d.amount == maxVal && maxVal > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.amount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              _shortNum(d.amount),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isMax
                                      ? Colors.blueAccent
                                      : Colors.grey),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: pct * 90,
                          decoration: BoxDecoration(
                            color: isMax
                                ? Colors.blueAccent
                                : Colors.blueAccent.withOpacity(0.35),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _chartData
                .map((d) => Expanded(
                      child: Text(d.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
      Map<String, dynamic> order, bool isDark, Color cardBg) {
    final amount =
        ((order['final_price'] ?? order['price']) as num?)?.toDouble() ?? 0;
    final date  = DateTime.tryParse(order['created_at']?.toString() ?? '') ??
        DateTime.now();
    final title = order['title']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(LucideIcons.checkCircle,
                color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('dd.MM.yy').format(date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text('+${_fmt(amount)} ₸',
              style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmpty(String lang) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.wallet, // Вместо walletMinimal
     size: 52, 
     color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                lang == 'ru'
                    ? 'Завершённых заказов нет'
                    : 'Аяқталған тапсырыс жоқ',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}М';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}К';
    return v.toInt().toString();
  }

  String _shortNum(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}к' : v.toInt().toString();
}

class _MonthBar {
  final String label;
  final double amount;
  const _MonthBar({required this.label, required this.amount});
}