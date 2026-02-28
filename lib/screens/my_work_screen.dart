import 'package:flutter/material.dart';
import 'package:fixly_app/main.dart'; 

class MyWorkScreen extends StatelessWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Моя работа" : "Менің жұмысым"),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Блок статистики (Идея 2)
                _buildStatsGrid(lang),
                const SizedBox(height: 30),
                
                // Заголовок списка (Идея 1)
                Text(
                  lang == 'ru' ? "Активные заявки" : "Белсенді тапсырыстар",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                
                // Список (заглушка или ListView)
                _buildEmptyState(lang), 
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(String lang) {
    return Row(
      children: [
        _statCard(lang == 'ru' ? "Выполнено" : "Бітті", "14", Colors.green),
        const SizedBox(width: 15),
        _statCard(lang == 'ru' ? "Доход (₸)" : "Табыс", "85 000", Colors.blue),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.work_history_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            lang == 'ru' ? "У вас пока нет активных заявок" : "Белсенді тапсырыстар жоқ",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}