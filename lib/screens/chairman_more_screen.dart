import 'package:fixly_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixly_app/screens/announcements_screen.dart';
import 'package:fixly_app/screens/library_screen.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/profile/chairman_Analytics_Screen.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/voting_list_screen.dart';
import 'package:fixly_app/screens/chairman_building_selection_screen.dart';

// Относительный импорт (работает, если billing_feature.dart лежит в той же папке screens)
import 'billing_feature.dart'; 

class ChairmanMoreScreen extends StatefulWidget {
  const ChairmanMoreScreen({super.key});

  @override
  State<ChairmanMoreScreen> createState() => _ChairmanMoreScreenState();
}

class _ChairmanMoreScreenState extends State<ChairmanMoreScreen> {
  
  void _openInvoiceCreation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF8A9A5B))),
    );

    try {
      final userData = await Supabase.instance.client
          .from('profiles')
          .select('building_id')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      Navigator.pop(context); // Закрываем лоадер

      final String? myBuildingId = userData?['building_id']?.toString();

      if (myBuildingId == null || myBuildingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ошибка: К вашему профилю не привязан дом."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Открываем форму
      CreateInvoiceSheet.show(context, myBuildingId);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка получения данных: $e"), backgroundColor: Colors.red),
      );
    }
  }

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
            LucideIcons.building2,
           AppColors.of(context).primary,            
           'Мой дом',
            'Выбор, привязка и смена дома',
            const ChairmanBuildingSelectionScreen(),
          ),
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
          
          // Твоя новая фича без лишних проверок языка
          _actionTile(
            context,
            card,
            isDark,
            LucideIcons.creditCard,
            const Color(0xFF8A9A5B), 
            'Выставление счетов',
            'Целевые сборы, квитанции и платежи ОСИ',
            _openInvoiceCreation,
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
            AppColors.of(context).primary,
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
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    Color card,
    bool isDark,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
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
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}