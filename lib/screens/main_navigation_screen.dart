// lib/screens/main_navigation_screen.dart
//
// Главный навигационный каркас приложения после редизайна.
// • Bottom navigation: 4 таба, зависят от роли
// • Центральный FAB — создание заявки (resident / chairman)
// • Председатель (chairman/manager/admin) дополнительно получает
//   выезжающий Drawer с градиентом: Голосование, Документы,
//   Аналитика, База знаний
//
// Роль определяется через BuildingContextService (тот же источник
// правды, что и в main_wrapper.dart), чтобы не плодить рассинхрон
// между двумя навигационными обёртками.

import 'package:fixly_app/screens/profile/chairman_Analytics_Screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fixly_app/main.dart';
import 'package:fixly_app/theme/app_theme.dart';
import 'package:fixly_app/services/building_context_service.dart';

import 'package:fixly_app/screens/chairman_home_screen.dart';
import 'package:fixly_app/screens/resident_home_page.dart';
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/income_screen.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/chat_list_screen.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/voting_list_screen.dart';
import 'package:fixly_app/screens/documents_screen.dart';
import 'package:fixly_app/screens/library_screen.dart';
import 'package:fixly_app/screens/announcements_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/my_work_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  BuildingContext? _context;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isHouseManager =>
      _context?.role == FixlyRole.chairman ||
      _context?.role == FixlyRole.manager ||
      _context?.role == FixlyRole.admin;

  bool get _isMaster => _context?.role == FixlyRole.master;
  bool get _isResident => !_isHouseManager && !_isMaster;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final context = await BuildingContextService.loadCurrent();
      if (mounted) {
        setState(() {
          _context = context;
          userRole.value = context?.roleKey ?? 'resident';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MainNavigationScreen role load: $e');
      if (mounted) {
        setState(() {
          userRole.value = 'resident';
          _isLoading = false;
        });
      }
    }
  }

  // ── СТРАНИЦЫ ПО РОЛЯМ ────────────────────────────────────
  List<Widget> get _pages {
    if (_isHouseManager) {
      return const [
        ChairmanHomeScreen(),
        OrdersPage(),
        ChatListScreen(),
        ProfilePage(),
      ];
    }
    if (_isMaster) {
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

  List<_NavItem> get _navItems {
    final lang = appLanguage.value;
    if (_isHouseManager) {
      return [
        _NavItem(LucideIcons.home, lang == 'ru' ? 'Дом' : 'Үй'),
        _NavItem(LucideIcons.clipboardList, lang == 'ru' ? 'Заявки' : 'Өтінімдер'),
        _NavItem(LucideIcons.messageCircle, lang == 'ru' ? 'Чаты' : 'Чаттар'),
        _NavItem(LucideIcons.user, lang == 'ru' ? 'Профиль' : 'Профиль'),
      ];
    }
    if (_isMaster) {
      return [
        _NavItem(LucideIcons.clipboardList, lang == 'ru' ? 'Заявки' : 'Тапсырыстар'),
        _NavItem(LucideIcons.wallet, lang == 'ru' ? 'Доход' : 'Табыс'),
        _NavItem(LucideIcons.messageCircle, lang == 'ru' ? 'Чаты' : 'Чаттар'),
        _NavItem(LucideIcons.user, lang == 'ru' ? 'Профиль' : 'Профиль'),
      ];
    }
    return [
      _NavItem(LucideIcons.home, lang == 'ru' ? 'Главная' : 'Басты бет'),
      _NavItem(LucideIcons.hardHat, lang == 'ru' ? 'Мастера' : 'Шеберлер'),
      _NavItem(LucideIcons.messageCircle, lang == 'ru' ? 'Чаты' : 'Чаттар'),
      _NavItem(LucideIcons.user, lang == 'ru' ? 'Профиль' : 'Профиль'),
    ];
  }

  // ── FAB: создание заявки доступно жителю и председателю ─
  bool get _showFab => _isResident || _isHouseManager;

  void _openCreateOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateOrderPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    final pages = _pages;
    final items = _navItems;
    final index = _currentIndex.clamp(0, pages.length - 1);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: c.background,
          extendBody: true,
          drawer: _isHouseManager ? _ChairmanDrawer(colors: c, lang: lang) : null,
          appBar: _isHouseManager
              ? AppBar(
                  backgroundColor: c.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(LucideIcons.menu, color: c.textPrimary),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  title: Text(
                    'Fixly',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
          body: IndexedStack(index: index, children: pages),
          floatingActionButton: _showFab
              ? FloatingActionButton(
                  onPressed: _openCreateOrder,
                  backgroundColor: c.primary,
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: const Icon(LucideIcons.plus, color: Colors.white, size: 30),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomBar(c, items, index),
        );
      },
    );
  }

  /// Bottom bar с вырезом под центральный FAB.
  /// Пункты делятся поровну: первая половина слева от выреза,
  /// вторая — справа. При нечётном количестве лишний пункт уходит влево.
  Widget _buildBottomBar(AppColors c, List<_NavItem> items, int index) {
    final leftCount = _showFab ? (items.length / 2).ceil() : items.length;
    final leftItems = items.sublist(0, leftCount);
    final rightItems = items.sublist(leftCount);

    Widget tileFor(_NavItem item) {
      final i = items.indexOf(item);
      return Expanded(child: _navTile(c, item, i, index));
    }

    return BottomAppBar(
      color: c.surface,
      shape: _showFab ? const CircularNotchedRectangle() : null,
      notchMargin: 10,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            ...leftItems.map(tileFor),
            if (_showFab) const SizedBox(width: 48),
            ...rightItems.map(tileFor),
          ],
        ),
      ),
    );
  }

  Widget _navTile(AppColors c, _NavItem item, int i, int currentIndex) {
    final selected = currentIndex == i;
    final color = selected ? c.primary : c.textTertiary;
    return InkWell(
      onTap: () => setState(() => _currentIndex = i),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 23),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

// ============================================================
//  DRAWER ПРЕДСЕДАТЕЛЯ — синий градиент, доп. разделы управления
// ============================================================
class _ChairmanDrawer extends StatelessWidget {
  const _ChairmanDrawer({required this.colors, required this.lang});

  final AppColors colors;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _drawerTile(
              context,
              icon: LucideIcons.vote,
              label: lang == 'ru' ? 'Голосование' : 'Дауыс беру',
              color: colors.success,
              onTap: () => _push(context, const VotingListScreen()),
            ),
            _drawerTile(
              context,
              icon: LucideIcons.fileText,
              label: lang == 'ru' ? 'Документы' : 'Құжаттар',
              color: colors.info,
              onTap: () => _push(context, const DocumentsScreen()),
            ),
            _drawerTile(
              context,
              icon: LucideIcons.barChart3,
              label: lang == 'ru' ? 'Аналитика' : 'Аналитика',
              color: colors.secondary,
              onTap: () => _push(context, const ChairmanAnalyticsScreen()),
            ),
            _drawerTile(
              context,
              icon: LucideIcons.library,
              label: lang == 'ru' ? 'База знаний' : 'Білім қоры',
              color: colors.warning,
              onTap: () => _push(context, const LibraryScreen()),
            ),
            const Divider(height: 24),
            _drawerTile(
              context,
              icon: LucideIcons.megaphone,
              label: lang == 'ru' ? 'Объявления' : 'Хабарландырулар',
              color: colors.danger,
              onTap: () => _push(context, const AnnouncementsScreen()),
            ),
            _drawerTile(
              context,
              icon: LucideIcons.briefcase,
              label: lang == 'ru' ? 'Мои дела' : 'Менің істерім',
              color: colors.textSecondary,
              onTap: () => _push(context, const MyWorkScreen()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Fixly · ОСИ/НСУ',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.gradientStart, colors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.building2, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            lang == 'ru' ? 'Панель председателя' : 'Төраға панелі',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang == 'ru' ? 'Управление домом и ОСИ' : 'Үй және МТБ басқару',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // закрыть drawer
        onTap();
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}