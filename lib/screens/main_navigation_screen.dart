import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; // Доступ к appLanguage
import 'package:fixly_app/utils/app_texts.dart'; // Доступ к AppTexts
import 'orders_page.dart';
import 'chat_list_screen.dart';
import 'profile_page.dart';
import 'create_order_page.dart';
import 'my_work_screen.dart';
import 'documents_screen.dart';
import 'resident_home_page.dart'; // Новый импорт для жителя
import 'package:fixly_app/core/sheber_ata_helper.dart'; 

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _userRole = 'resident'; // По умолчанию ставим resident
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userRole = data['role'] ?? 'resident'; 
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка при получении роли: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ЛОГИКА СТРАНИЦ В ЗАВИСИМОСТИ ОТ РОЛИ
    final List<Widget> pages = [
      // 0: Главная / Заявки
      _userRole == 'resident' ? const ResidentHomePage() : const OrdersPage(),
      
      // 1: Чаты
      const ChatListScreen(),
      
      // 2: Документы / Работа / Мой дом
      _userRole == 'osi' 
          ? const DocumentsScreen() 
          : (_userRole == 'resident' ? const DocumentsScreen() : const MyWorkScreen()), // Для жителя пока оставим документы или спец. экран
          
      // 3: Профиль
      const ProfilePage(),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          extendBody: true,
          body: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: pages,
                  ),
                ),
                Positioned(
                  bottom: 110, 
                  right: 20,
                  child: SheberAtaHelper(
                    messages: const {
                      'kk': 'Сәлеметсіз бе! Тұрғын ретінде көмек керек пе?',
                      'ru': 'Привет! Нужна помощь как жителю?',
                    },
                    onTap: () => debugPrint("Шебер-Ата на связи с жителем!"), 
                  ),
                ),
              ],
            ),
          ),

          // Кнопка "+" только для ОСИ и Жителя (Житель может подать заявку)
          floatingActionButton: (_userRole == 'osi' || _userRole == 'resident')
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateOrderPage(initialCategory: '', masterId: null, masterName: null, prefillDescription: '',)),
                  );
                },
                backgroundColor: Colors.blueAccent,
                shape: const CircleBorder(),
                elevation: 8,
                child: const Icon(LucideIcons.plus, color: Colors.white, size: 35),
              )
            : null,

          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

          bottomNavigationBar: BottomAppBar(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            // Вырез под кнопку, если роль позволяет
            shape: (_userRole == 'osi' || _userRole == 'resident') ? const CircularNotchedRectangle() : null,
            notchMargin: 10.0,
            child: SizedBox(
              height: 65,
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavItem(
                      icon: _userRole == 'resident' ? LucideIcons.home : (_userRole == 'osi' ? LucideIcons.clipboardList : LucideIcons.briefcase), 
                      label: _userRole == 'resident' ? (lang == 'ru' ? 'Главная' : 'Басты бет') : (_userRole == 'osi' ? AppTexts.get('orders', lang) : AppTexts.get('exchange', lang)), 
                      index: 0
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: LucideIcons.messageCircle, 
                      label: AppTexts.get('chats', lang), 
                      index: 1
                    ),
                  ),
                  
                  // Отступ под кнопку "+"
                  (_userRole == 'osi' || _userRole == 'resident')
                    ? const SizedBox(width: 48) 
                    : const SizedBox(width: 10), 

                  Expanded(
                    child: _buildNavItem(
                      icon: _userRole == 'resident' ? LucideIcons.building : (_userRole == 'osi' ? LucideIcons.fileText : LucideIcons.layoutGrid), 
                      label: _userRole == 'resident' ? (lang == 'ru' ? 'Мой дом' : 'Менің үйім') : (_userRole == 'osi' ? AppTexts.get('documents', lang) : (lang == 'ru' ? 'Мои дела' : 'Менің істерім')), 
                      index: 2
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: LucideIcons.user, 
                      label: AppTexts.get('profile', lang), 
                      index: 3
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
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