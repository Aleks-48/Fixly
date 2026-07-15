// lib/screens/my_buildings_screen.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:fixly_app/main.dart'; // Для работы с appLanguage
import 'package:fixly_app/theme/app_theme.dart'; // Единая дизайн-система Fixly

class MyBuildingsScreen extends StatelessWidget {
  const MyBuildingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? "Мои объекты" : "Менің нысандарым", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: c.textPrimary),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: c.textPrimary),
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _StaggeredEntrance(
                index: 0,
                child: _buildBuildingCard(
                  context,
                  address: "ул. Абая, 30",
                  tasksCount: 4,
                  isUrgent: true,
                  chairmanName: lang == 'ru' ? "Иван Иванович (ОСИ)" : "Иван Иванович (МТБ)",
                  phone: "77071234567",
                  lang: lang,
                ),
              ),
              _StaggeredEntrance(
                index: 1,
                child: _buildBuildingCard(
                  context,
                  address: "ул. Мира, 12",
                  tasksCount: 1,
                  isUrgent: false,
                  chairmanName: lang == 'ru' ? "Андрей Владимирович (НСУ)" : "Андрей Владимирович (ЖПБ)",
                  phone: "77077654321",
                  lang: lang,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuildingCard(
    BuildContext context, {
    required String address, 
    required int tasksCount, 
    required bool isUrgent,
    required String chairmanName,
    required String phone,
    required String lang,
  }) {
    final c = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: isUrgent 
            ? Border.all(color: c.danger.withOpacity(0.3), width: 1.5) 
            : Border.all(color: c.textTertiary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUrgent ? c.danger.withOpacity(0.1) : c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    LucideIcons.building2, 
                    color: isUrgent ? c.danger : c.primary, 
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address, 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: c.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chairmanName, 
                        style: TextStyle(color: c.textTertiary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tasksCount > 0 ? c.warning.withOpacity(0.12) : c.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$tasksCount", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: tasksCount > 0 ? c.warning : c.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Нижняя панель действий
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: c.textTertiary.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: c.textTertiary.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                _buildActionButton(context, LucideIcons.messageCircle, lang == 'ru' ? "Чат" : "Чат", () {
                  // Здесь навигация в чат
                }),
                VerticalDivider(width: 1, color: c.textTertiary.withOpacity(0.12)),
                _buildActionButton(context, LucideIcons.phone, lang == 'ru' ? "Звонок" : "Қоңырау", () async {
                  final Uri url = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }),
                VerticalDivider(width: 1, color: c.textTertiary.withOpacity(0.12)),
                _buildActionButton(context, LucideIcons.history, lang == 'ru' ? "История" : "Тарих", () {
                  // Здесь навигация в историю дома
                }),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final c = AppColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(
              label, 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация появления элементов
// ============================================================
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}