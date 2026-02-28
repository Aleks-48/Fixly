import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/masters_list_screen.dart'; // Экран для председателя
import 'package:fixly_app/screens/profile/My_Buildings_Screen.dart'; // НОВЫЙ экран для мастера
import 'package:fixly_app/screens/chat_list_screen.dart';
import 'package:fixly_app/screens/profile_page.dart' hide SettingsPage;
import 'package:fixly_app/screens/income_screen.dart';
import 'package:fixly_app/settings/settings_page.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/profile/Chairman_Analytics_Screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  String _userRole = 'master'; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, user_type')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          final role = (data['role'] ?? '').toString();
          final type = (data['user_type'] ?? '').toString();
          _userRole = (role.contains('osi') || type.contains('osi')) ? 'chairman' : 'master';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Динамический список страниц
    final List<Widget> pages = [
      const OrdersPage(),
      _userRole == 'chairman' ? const ChairmanAnalyticsScreen() : const IncomeScreen(),
      // Мастер видит список домов, Председатель видит список своих мастеров
      _userRole == 'chairman' ? const MastersListScreen() : const MyBuildingsScreen(),
      ChatListScreen(),
      const ProfilePage(),
      const SettingsPage(currentName: "Пользователь", currentBin: "0000"),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderPage())),
        backgroundColor: Colors.blueAccent,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        padding: EdgeInsets.zero,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, LucideIcons.layoutGrid, 'Заявки'),
                  _buildNavItem(1, _userRole == 'chairman' ? LucideIcons.barChart3 : LucideIcons.dollarSign, 
                                   _userRole == 'chairman' ? 'Аналитика' : 'Доходы'),
                  // Динамическая иконка для 3-го пункта
                  _buildNavItem(2, _userRole == 'chairman' ? LucideIcons.wrench : LucideIcons.home, 
                                   _userRole == 'chairman' ? 'Мастера' : 'Мои дома'),
                ],
              ),
            ),
            const SizedBox(width: 60),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(3, LucideIcons.messageSquare, 'Чаты'),
                  _buildNavItem(4, LucideIcons.user, 'Профиль'),
                  _buildNavItem(5, LucideIcons.settings, 'Опции'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.grey), size: 19),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.grey),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}