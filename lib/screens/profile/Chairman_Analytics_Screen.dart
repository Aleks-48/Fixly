import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ChairmanAnalyticsScreen extends StatelessWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final supabase = Supabase.instance.client;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Аналитика дома" : "Үй аналитикасы"),
            centerTitle: true,
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('tasks').stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = snapshot.data ?? [];
              
              double totalSpent = 0;
              int completedCount = 0;
              int activeCount = 0;
              
              for (var task in tasks) {
                final status = task['status'];
                if (status == 'completed') {
                  completedCount++;
                  final price = double.tryParse(task['final_price']?.toString() ?? '0') ?? 0;
                  totalSpent += price;
                } else if (['new', 'in_progress', 'pending'].contains(status)) {
                  activeCount++;
                }
              }

              double health = (completedCount + activeCount) > 0 
                  ? completedCount / (completedCount + activeCount) 
                  : 1.0;

              final data = {
                'totalSpent': totalSpent,
                'completedCount': completedCount,
                'activeCount': activeCount,
                'health': health,
              };

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainCard(data, lang),
                    const SizedBox(height: 30),
                    
                    _buildSectionHeader(lang == 'ru' ? "Здоровье дома" : "Үй жағдайы"),
                    _buildHealthIndicator(health, lang),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader(lang == 'ru' ? "Рекомендации ИИ" : "ИИ ұсыныстары"),
                    _buildAIAdviceCard(data, lang, isDark),
                    
                    const SizedBox(height: 30),
                    _buildRecentTasksList(tasks, lang),
                    
                    const SizedBox(height: 30),
                    _buildReportButton(tasks, lang),
                    
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildMainCard(Map<String, dynamic> data, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF0081CB)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang == 'ru' ? "Потрачено на ремонт" : "Жөндеуге жұмсалды", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text("${(data['totalSpent'] as double).toInt()} ₸", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(LucideIcons.checkCircle, lang == 'ru' ? "Готово" : "Дайын", "${data['completedCount']}"),
              _buildMiniStat(LucideIcons.clock, lang == 'ru' ? "В работе" : "Жұмыста", "${data['activeCount']}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(double health, String lang) {
    Color healthColor = health > 0.8 ? Colors.green : (health > 0.5 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: healthColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(health * 100).toInt()}%", style: TextStyle(color: healthColor, fontWeight: FontWeight.bold, fontSize: 20)),
              Icon(health > 0.7 ? LucideIcons.smile : LucideIcons.frown, color: healthColor),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: health,
            backgroundColor: healthColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(healthColor),
            minHeight: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksList(List<Map<String, dynamic>> tasks, String lang) {
    final completedTasks = tasks.where((t) => t['status'] == 'completed').toList().reversed.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(lang == 'ru' ? "Последние работы" : "Соңғы жұмыстар"),
        ...completedTasks.map((task) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(LucideIcons.wrench, size: 18, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(child: Text(task['category'] ?? "Ремонт")),
              Text("${(double.tryParse(task['final_price']?.toString() ?? '0') ?? 0).toInt()} ₸", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildReportButton(List<Map<String, dynamic>> tasks, String lang) {
    return ElevatedButton.icon(
      onPressed: () {
        // Здесь вызов логики генерации (PDF/Excel)
      },
      icon: const Icon(LucideIcons.fileDown),
      label: Text(lang == 'ru' ? "Скачать отчет для жильцов" : "Тұрғындар үшін есепті жүктеу"),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAIAdviceCard(Map<String, dynamic> data, String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Colors.orange),
          const SizedBox(width: 15),
          Expanded(child: Text(lang == 'ru' ? "Внимание! Затраты на сантехнику выросли. Рекомендуем плановый осмотр труб." : "Назар аударыңыз! Сантехника шығындары өсті.")),
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
}