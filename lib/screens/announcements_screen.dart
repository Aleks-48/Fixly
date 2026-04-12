import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';

class AnnouncementsScreen extends StatefulWidget {
  final String buildingId;
  const AnnouncementsScreen({super.key, required this.buildingId});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final supabase = Supabase.instance.client;
  int _selectedFilter = 0; // 0 - Все, 1 - Свежие, 2 - Старые

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              lang == 'ru' ? "Все объявления" : "Барлық хабарландырулар",
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              // Блок фильтров
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _filterChip(0, lang == 'ru' ? "Все" : "Барлығы"),
                    const SizedBox(width: 8),
                    _filterChip(1, lang == 'ru' ? "Свежие" : "Жаңа"),
                    const SizedBox(width: 8),
                    _filterChip(2, lang == 'ru' ? "Старые" : "Ескі"),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase
                      .from('announcements')
                      .stream(primaryKey: ['id'])
                      .eq('building_id', widget.buildingId)
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    var items = snapshot.data ?? [];
                    
                    // Логика фильтрации
                    if (_selectedFilter == 1) {
                      // Свежие: за последние 7 дней
                      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                      items = items.where((i) => DateTime.parse(i['created_at']).isAfter(weekAgo)).toList();
                    } else if (_selectedFilter == 2) {
                      // Старые: старше 7 дней
                      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                      items = items.where((i) => DateTime.parse(i['created_at']).isBefore(weekAgo)).toList();
                    }

                    if (items.isEmpty) {
                      return Center(child: Text(lang == 'ru' ? "Ничего не найдено" : "Ештеңе табылмады"));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildFullCard(item, isDark, lang);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(int index, String label) {
    bool isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedFilter = index),
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildFullCard(Map<String, dynamic> item, bool isDark, String lang) {
    DateTime date = DateTime.parse(item['created_at'] ?? DateTime.now().toString());
    final String formattedDate = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formattedDate, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(item['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            item['content'] ?? '',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}