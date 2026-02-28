import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ChairmanAnalyticsScreen extends StatelessWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Аналитика дома", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Главная карточка расходов
            _buildTotalSpentCard(),
            
            const SizedBox(height: 20),
            
            // 2. Блок здоровья дома
            const Text("Состояние дома", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildHealthCard(),

            const SizedBox(height: 20),

            // 3. Блок AI рекомендаций
            const Text("Рекомендации ИИ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildRecommendationItem(
              title: "Плановый осмотр",
              subtitle: "Затраты на сантехнику выросли. Рекомендуем осмотр труб.",
              icon: LucideIcons.alertTriangle,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSpentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Потрачено на ремонт", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          const Text("125 450 ₸", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat("12", "Заявок"),
              const SizedBox(width: 20),
              _miniStat("2", "В работе"),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );

  Widget _buildHealthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Общий индекс", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("78%", style: TextStyle(color: Colors.greenAccent.shade400, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0.78,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }
}