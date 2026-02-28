import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  Future<Map<String, dynamic>> _getRealStats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return {};

    try {
      final profileData = await supabase
          .from('profiles')
          .select('avg_rating')
          .eq('id', user.id)
          .maybeSingle();

      // Читаем колонку final_price вместо price
      final tasksResponse = await supabase
          .from('tasks')
          .select('final_price, created_at, title')
          .eq('assignee_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      double calculatedSum = 0;
      List recentTransactions = [];
      
      if (tasksResponse != null) {
        recentTransactions = tasksResponse;
        for (var task in tasksResponse) {
          // Используем final_price
          final val = task['final_price'];
          if (val != null) {
            calculatedSum += double.tryParse(val.toString()) ?? 0.0;
          }
        }
      }

      return {
        'earned': calculatedSum,
        'completed': recentTransactions.length,
        'rating': profileData?['avg_rating'] ?? 5.0,
        'recent': recentTransactions,
      };
    } catch (e) {
      debugPrint("Ошибка статистики: $e");
      return {'earned': 0, 'completed': 0, 'rating': 0.0, 'recent': []};
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Мои доходы" : "Менің табысым"),
            centerTitle: true,
          ),
          body: FutureBuilder<Map<String, dynamic>>(
            future: _getRealStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data ?? {};
              final recent = data['recent'] as List? ?? [];
              double earned = (data['earned'] ?? 0).toDouble();
              double goal = 500000;

              return RefreshIndicator(
                onRefresh: () => Future.sync(() => (context as Element).markNeedsBuild()),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBlueCard(data, lang),
                      const SizedBox(height: 30),
                      _buildSectionHeader(lang == 'ru' ? "Цель на месяц" : "Айлық мақсат"),
                      _buildGoalCard(earned, goal, lang),
                      const SizedBox(height: 30),
                      _buildSectionHeader(lang == 'ru' ? "Последние выплаты" : "Соңғы төлемдер"),
                      if (recent.isEmpty)
                        _buildEmptyState(lang)
                      else
                        ...recent.take(10).map((order) => _buildTransactionItem(order, isDark)).toList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- Вспомогательные виджеты (оставляем без изменений, но фиксим вывод цены) ---

  Widget _buildBlueCard(Map<String, dynamic> data, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang == 'ru' ? "Заработано всего" : "Жалпы табыс", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text("${(data['earned'] as double).toInt()} ₸", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(LucideIcons.checkCircle, lang == 'ru' ? "Заказы" : "Тапсырыс", "${data['completed']}"),
              _buildMiniStat(LucideIcons.star, lang == 'ru' ? "Рейтинг" : "Рейтинг", "${data['rating']}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> order, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: const Icon(LucideIcons.arrowDownLeft, color: Colors.green)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order['title'] ?? "Заказ", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(order['created_at'].toString().split('T')[0], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          // ТУТ ТОЖЕ СТАВИМ final_price
          Text("+${(order['final_price'] ?? 0).toInt()} ₸", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ])
    ]);
  }

  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
  Widget _buildEmptyState(String lang) => Center(child: Text(lang == 'ru' ? "Тут пока пусто" : "Әзірге бос", style: const TextStyle(color: Colors.grey)));
  Widget _buildGoalCard(double current, double goal, String lang) {
    double progress = (current / goal).clamp(0.0, 1.0);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        Text("${goal.toInt()} ₸"),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: progress, backgroundColor: Colors.blue.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation(Colors.blue)),
    ]);
  }
}