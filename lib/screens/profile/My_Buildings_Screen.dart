import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart'; // Для звонков

class MyBuildingsScreen extends StatelessWidget {
  const MyBuildingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Мои объекты", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildBuildingCard(
            context,
            address: "ул. Абая, 30",
            tasksCount: 4,
            isUrgent: true,
            chairmanName: "Иван Иванович (ОСИ)",
            phone: "77071234567",
          ),
          _buildBuildingCard(
            context,
            address: "ул. Мира, 12",
            tasksCount: 1,
            isUrgent: false,
            chairmanName: "Андрей Владимирович (НСУ)",
            phone: "77077654321",
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(BuildContext context, {
    required String address, 
    required int tasksCount, 
    required bool isUrgent,
    required String chairmanName,
    required String phone
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isUrgent ? Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                    color: isUrgent ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(LucideIcons.building2, color: isUrgent ? Colors.redAccent : Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(chairmanName, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tasksCount > 0 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("$tasksCount", style: TextStyle(fontWeight: FontWeight.bold, color: tasksCount > 0 ? Colors.orange : Colors.green)),
                ),
              ],
            ),
          ),
          // Нижняя панель действий
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                _buildActionButton(LucideIcons.messageCircle, "Чат", () {
                  // Здесь навигация в чат
                }),
                VerticalDivider(width: 1, color: Colors.grey.withOpacity(0.2)),
                _buildActionButton(LucideIcons.phone, "Звонок", () async {
                  final Uri url = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }),
                VerticalDivider(width: 1, color: Colors.grey.withOpacity(0.2)),
                _buildActionButton(LucideIcons.history, "История", () {
                  // Здесь навигация в историю дома
                }),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }
}