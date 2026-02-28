import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'orders_page.dart';
import 'chat_list_screen.dart';
import 'profile_page.dart';
import 'create_order_page.dart';
import 'my_work_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      OrdersPage(),
      ChatListScreen(),
      MyWorkScreen(),
      ProfilePage(),
    ];

    return Scaffold(
      // ExtendBody позволяет контенту прокручиваться под BottomAppBar, 
      // но мы добавили SizedBox(120) в профиле, так что всё будет ок.
      extendBody: true, 
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Если кнопка не работает, убедись, что CreateOrderPage не пустой файл
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateOrderPage()),
          );
        },
        backgroundColor: Colors.blueAccent,
        shape: const CircleBorder(),
        elevation: 8, // Чуть больше тени для объема
        child: const Icon(LucideIcons.plus, color: Colors.white, size: 35),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0, // Увеличил зазор, чтобы кнопка не "залипала"
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: LucideIcons.briefcase, label: 'Заявки', index: 0),
              _buildNavItem(icon: LucideIcons.messageCircle, label: 'Чаты', index: 1),
              const SizedBox(width: 48), // Место для "+"
              _buildNavItem(icon: LucideIcons.layoutGrid, label: 'Мои дела', index: 2),
              _buildNavItem(icon: LucideIcons.user, label: 'Профиль', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blueAccent : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.grey,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}