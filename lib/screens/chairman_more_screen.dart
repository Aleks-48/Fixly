import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fixly_app/screens/announcements_screen.dart';
import 'package:fixly_app/screens/library_screen.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
// Раньше путь был screens/profile/chairman_Analytics_Screen.dart — папки
// profile/ не существует, файл не компилировался.
import 'package:fixly_app/screens/profile/chairman_Analytics_Screen.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/voting_list_screen.dart';

class ChairmanMoreScreen extends StatelessWidget {
  const ChairmanMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101214) : const Color(0xFFF6F7F9);
    final card = isDark ? const Color(0xFF1B1F24) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Еще',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
body: ListView(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
  children: [
    _tile(
      context,
      card,
      isDark,
      LucideIcons.barChart3,
      Colors.indigo,
      'Аналитика дома',
      'Финансы, расходы, рекомендации',
      const ChairmanAnalyticsScreen(),
    ),
    _tile(
      context,
      card,
      isDark,
      LucideIcons.megaphone,
      Colors.orange,
      'Объявления',
      'Новости и срочные уведомления дома',
      const AnnouncementsScreen(),
    ),
    // Новая плитка: Управление голосованиями дома
    _tile(
      context,
      card,
      isDark,
      LucideIcons.vote,
      Colors.green,
      'Голосования',
      'Создание опросов, протоколы и архивы',
      const VotingListScreen(),
    ),
    _tile(
      context,
      card,
      isDark,
      LucideIcons.hardHat,
      Colors.blueAccent,
      'Мастера',
      'Исполнители для заявок дома',
      const MastersListScreen(),
    ),
    _tile(
      context,
      card,
      isDark,
      LucideIcons.library,
      Colors.teal,
      'База знаний',
      'Материалы для ОСИ/НСУ и жителей',
      const LibraryScreen(),
    ),
    _tile(
      context,
      card,
      isDark,
      LucideIcons.user,
      Colors.green,
      'Профиль',
      'Аккаунт, данные и выход',
      const ProfilePage(),
    ),
  ],
),
    );
  }

  Widget _tile(
    BuildContext context,
    Color card,
    bool isDark,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    Widget page,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE6E8EC),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
                    color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}