import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/announcements_screen.dart';
import 'package:fixly_app/screens/chairman_home_screen.dart';
import 'package:fixly_app/screens/chairman_more_screen.dart';
import 'package:fixly_app/screens/chat_list_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/documents_screen.dart';
import 'package:fixly_app/screens/income_screen.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/resident_home_page.dart';
import 'package:fixly_app/screens/voting_list_screen.dart';
import 'package:fixly_app/screens/voting_page.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  String _userRole = 'resident';
  bool _isLoading = true;
  BuildingContext? _buildingContext;

  bool get _isHouseManager =>
      _userRole == 'chairman' || _userRole == 'manager' || _userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final context = await BuildingContextService.loadCurrent();
      final role = context?.roleKey ?? 'resident';
      userRole.value = role;
      if (mounted) {
        setState(() {
          _buildingContext = context;
          _userRole = role;
          _selectedIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MainWrapper role load: $e');
      if (mounted) {
        setState(() {
          _userRole = 'resident';
          userRole.value = 'resident';
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

    final pages = _pages();
    final items = _navItems();
    final currentIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: items,
      ),
      floatingActionButton: _buildFab(),
    );
  }

  List<Widget> _pages() {
    if (_isHouseManager) {
      return const [
        ChairmanHomeScreen(),
        OrdersPage(),
        VotingListScreen(),
        DocumentsScreen(),
        ChairmanMoreScreen(),
      ];
    }

    if (_userRole == 'master') {
      return const [
        OrdersPage(),
        IncomeScreen(),
        ChatListScreen(),
        ProfilePage(),
      ];
    }

    return const [
      ResidentHomePage(),
      MastersListScreen(),
      ChatListScreen(),
      ProfilePage(),
    ];
  }

  List<NavigationDestination> _navItems() {
    if (_isHouseManager) {
      return const [
        NavigationDestination(icon: Icon(LucideIcons.home), label: 'Дом'),
        NavigationDestination(
            icon: Icon(LucideIcons.clipboardList), label: 'Заявки'),
        NavigationDestination(
            icon: Icon(LucideIcons.vote), label: 'Голосования'),
        NavigationDestination(
            icon: Icon(LucideIcons.fileText), label: 'Документы'),
        NavigationDestination(
            icon: Icon(LucideIcons.moreHorizontal), label: 'Еще'),
      ];
    }

    if (_userRole == 'master') {
      return const [
        NavigationDestination(
            icon: Icon(LucideIcons.clipboardList), label: 'Заявки'),
        NavigationDestination(icon: Icon(LucideIcons.wallet), label: 'Доход'),
        NavigationDestination(
            icon: Icon(LucideIcons.messageSquare), label: 'Чаты'),
        NavigationDestination(icon: Icon(LucideIcons.user), label: 'Профиль'),
      ];
    }

    return const [
      NavigationDestination(icon: Icon(LucideIcons.home), label: 'Главная'),
      NavigationDestination(icon: Icon(LucideIcons.hardHat), label: 'Мастера'),
      NavigationDestination(
          icon: Icon(LucideIcons.messageSquare), label: 'Чаты'),
      NavigationDestination(icon: Icon(LucideIcons.user), label: 'Профиль'),
    ];
  }

  Widget? _buildFab() {
    if (_isHouseManager) {
      return FloatingActionButton(
        onPressed: _showChairmanCreateSheet,
        backgroundColor: Colors.blueAccent,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      );
    }

    if (_userRole == 'resident') {
      return FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateOrderPage()),
        ),
        backgroundColor: Colors.blueAccent,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      );
    }

    return null;
  }

  void _showChairmanCreateSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B1F24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _sheetAction(
                ctx,
                LucideIcons.wrench,
                Colors.blueAccent,
                'Заявка',
                'Создать заявку по дому',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateOrderPage()),
                ),
              ),
              _sheetAction(
                ctx,
                LucideIcons.megaphone,
                Colors.orange,
                'Объявление',
                'Открыть публикацию объявлений',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AnnouncementsScreen(),
                  ),
                ),
              ),
              _sheetAction(
                ctx,
                LucideIcons.vote,
                Colors.green,
                'Голосование',
                'Запустить вопрос для жильцов',
                _showProposalDialog,
              ),
              _sheetAction(
                ctx,
                LucideIcons.fileText,
                Colors.indigo,
                'Документ',
                'Открыть шаблоны и архив',
                () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction(
    BuildContext sheetContext,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: () {
        Navigator.pop(sheetContext);
        onTap();
      },
    );
  }

  Future<void> _showProposalDialog() async {
    if (_buildingContext?.canManageHouse != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужно подтверждение прав по дому')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое голосование'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Вопрос'),
              autofocus: true,
            ),
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                final row = await VotingService.createProposal(
                  title: titleCtrl.text,
                  description: descriptionCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx, row);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    descriptionCtrl.dispose();

    if (created != null && mounted) {
      setState(() => _selectedIndex = 2);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VotingPage(
            proposalId: created['id'].toString(),
            proposalTitle: created['title']?.toString() ?? '',
          ),
        ),
      );
    }
  }

  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
