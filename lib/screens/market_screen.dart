import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? 'Маркет услуг' : 'Қызметтер маркеті',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPromoBanner(lang),
                const SizedBox(height: 24),
                Text(
                  lang == 'ru' ? 'Категории' : 'Санаттар',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildCategoryCard(
                      context,
                      icon: LucideIcons.wrench,
                      title: lang == 'ru' ? 'Сантехник' : 'Сантехник',
                      color: Colors.blue,
                    ),
                    _buildCategoryCard(
                      context,
                      icon: LucideIcons.zap,
                      title: lang == 'ru' ? 'Электрик' : 'Электрик',
                      color: Colors.orange,
                    ),
                    _buildCategoryCard(
                      context,
                      icon: LucideIcons.brush,
                      title: lang == 'ru' ? 'Уборка' : 'Тазалау',
                      color: Colors.green,
                    ),
                    _buildCategoryCard(
                      context,
                      icon: LucideIcons.truck,
                      title: lang == 'ru' ? 'Грузчики' : 'Жүк тасушылар',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromoBanner(String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'ru' ? 'Скидка 10% на первый заказ!' : 'Алғашқы тапсырысқа 10% жеңілдік!',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lang == 'ru' ? 'Получить' : 'Алу'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, {required IconData icon, required String title, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}