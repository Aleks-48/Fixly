import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Импорты страниц
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/profile/My_Buildings_Screen.dart';
import 'package:fixly_app/screens/chat_list_screen.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/income_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/profile/Chairman_Analytics_Screen.dart';
import 'package:fixly_app/screens/documents_screen.dart';
import 'package:fixly_app/screens/library_screen.dart';
import 'package:fixly_app/screens/resident_home_page.dart'; 
import 'package:fixly_app/screens/market_screen.dart';
import 'package:fixly_app/screens/voting_page.dart'; 

// Ядро и утилиты
import 'package:fixly_app/core/sheber_ata_helper.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/utils/app_texts.dart'; 

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  String _userRole = 'resident'; 
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isTutorialActive = false;
  int _tutorialStep = 0;
  Map<String, String> _helperMessage = {}; 

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getCleanLang(String lang) {
    String clean = lang.split('-')[0].split('_')[0].toLowerCase();
    if (clean == 'kz') return 'kk'; 
    return clean;
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && data != null) {
          setState(() {
            final String role = (data['role'] ?? '').toString().toLowerCase();
            if (role == 'chairman' || role == 'osi') {
              _userRole = 'chairman';
            } else if (role == 'resident') {
              _userRole = 'resident';
            } else {
              _userRole = 'master';
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Ошибка загрузки роли: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playStepVoice(int step, String lang) async {
    String cleanLang = _getCleanLang(lang);
    String fileName = "${cleanLang}_step$step.mp3"; 
    
    try {
      await _audioPlayer.stop(); 
      await _audioPlayer.play(AssetSource("sounds/tutorial/$fileName"));
    } catch (e) {
      debugPrint("Файл озвучки не найден: $fileName");
    }
  }

  void _nextTutorialStep() {
    final lang = appLanguage.value; 
    
    setState(() {
      _tutorialStep++;
      
      switch (_tutorialStep) {
        case 1:
          _selectedIndex = 0; 
          _helperMessage = {
            'ru': 'Это ваша главная страница с важными уведомлениями.',
            'kk': 'Бұл маңызды хабарландырулары бар басты бетіңіз.',
          };
          break;
        case 2:
          _selectedIndex = 1; 
          _helperMessage = {
            'ru': _userRole == 'master' ? 'Тут ваш доход.' : 'Тут список мастеров дома.',
            'kk': _userRole == 'master' ? 'Мұнда сіздің табысыңыз.' : 'Мұнда үй шеберлерінің тізімі.',
          };
          break;
        case 3:
          // ШАГ: ОТКРЫВАЕМ БУРГЕР ДЛЯ ОБЪЯСНЕНИЯ
          _scaffoldKey.currentState?.openDrawer();
          _helperMessage = {
            'ru': 'В этом меню находятся документы, голосования и аналитика.',
            'kk': 'Бұл мәзірде құжаттар, дауыс беру және аналитика орналасқан.',
          };
          break;
        case 4:
          _selectedIndex = 3; // Переходим в профиль
          _helperMessage = {
            'ru': 'Ваш профиль. Для председателя мы убрали лишнюю статистику.',
            'kk': 'Сіздің профиліңіз. Төраға үшін артық статистиканы алып тастадық.',
          };
          break;
        case 5: 
          _helperMessage = {
            'ru': 'Обучение завершено! Я всегда рядом в углу экрана.',
            'kk': 'Оқу аяқталды! Мен әрқашан экран бұрышындамын.',
          };
          break;
        default:
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
          _isTutorialActive = false;
          _tutorialStep = 0;
          _helperMessage = {}; 
          _audioPlayer.stop();
          return;
      }
      
      _playStepVoice(_tutorialStep, lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      _userRole == 'resident' ? const ResidentHomePage() : const OrdersPage(), 
      _userRole == 'chairman' ? const MastersListScreen() : (_userRole == 'resident' ? const MastersListScreen() : const IncomeScreen()),
      const ChatListScreen(), 
      const ProfilePage(), 
    ];

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final String cleanLang = _getCleanLang(lang);

        return Scaffold(
          key: _scaffoldKey,
          extendBody: true,
          backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
          
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.menu, color: Colors.blueAccent),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Text(
              _userRole == 'chairman' ? "Fixly ОСИ" : "Fixly", 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            centerTitle: true,
          ),

          drawer: _buildDrawer(cleanLang, isDark),

          body: Stack(
            children: [
              IndexedStack(index: _selectedIndex, children: pages),
              
              Positioned(
                bottom: 110, 
                right: 16,
                child: SheberAtaHelper(
                  languageCode: cleanLang,
                  messages: _helperMessage.isNotEmpty 
                      ? { cleanLang: _helperMessage[cleanLang] ?? _helperMessage['ru'] ?? '' } 
                      : {}, 
                  actions: _isTutorialActive ? [
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _nextTutorialStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(cleanLang == 'kk' ? 'Келесі' : 'Далее', style: const TextStyle(color: Colors.white)),
                    )
                  ] : null,
                  onTap: () {
                    if (!_isTutorialActive) _showHelperMenu(context, lang);
                  }, 
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(isDark, cleanLang),
          floatingActionButton: (_userRole == 'chairman' || _userRole == 'resident') ? _buildFAB() : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildDrawer(String lang, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueAccent),
            accountName: Text(_userRole.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(Supabase.instance.client.auth.currentUser?.email ?? ""),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(LucideIcons.user, color: Colors.blueAccent, size: 40),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.vote, color: Colors.orangeAccent),
            title: Text(lang == 'kk' ? "Дауыс беру" : "Голосование"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const VotingPage()));
            },
          ),
          if (_userRole == 'resident')
            ListTile(
              leading: const Icon(LucideIcons.shoppingBag, color: Colors.green),
              title: Text(lang == 'kk' ? "Маркет" : "Маркет"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const MarketScreen()));
              },
            ),
          if (_userRole == 'chairman') ...[
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: Colors.blue),
              title: Text(lang == 'kk' ? "Құжаттар" : "Документы"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DocumentsScreen())),
            ),
            ListTile(
              leading: const Icon(LucideIcons.barChart3, color: Colors.purple),
              title: Text(lang == 'kk' ? "Аналитика" : "Аналитика"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ChairmanAnalyticsScreen())),
            ),
          ],
          ListTile(
            leading: const Icon(LucideIcons.library, color: Colors.teal),
            title: Text(lang == 'kk' ? "Білім базасы" : "База знаний"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LibraryScreen())),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
            title: Text(lang == 'kk' ? "Шығу" : "Выйти"),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, String cleanLang) {
    bool hasNotch = (_userRole == 'chairman' || _userRole == 'resident');
    return BottomAppBar(
      shape: hasNotch ? const CircularNotchedRectangle() : null,
      notchMargin: 8.0,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, LucideIcons.home, cleanLang == 'kk' ? 'Басты' : 'Главная'),
            _buildNavItem(1, _userRole == 'master' ? LucideIcons.dollarSign : LucideIcons.wrench, 
                _userRole == 'master' ? 'Доход' : 'Мастера'),
            if (hasNotch) const SizedBox(width: 48),
            _buildNavItem(2, LucideIcons.messageSquare, 'Чаты'),
            _buildNavItem(3, LucideIcons.user, 'Профиль'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey, size: 24),
          Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.blueAccent : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderPage(initialCategory: '',))),
      backgroundColor: Colors.blueAccent,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }

  void _showHelperMenu(BuildContext context, String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String cleanLang = _getCleanLang(lang);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blueAccent),
              title: Text(AppTexts.get('instruction', cleanLang)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isTutorialActive = true;
                  _tutorialStep = 0;
                  _nextTutorialStep(); 
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.orangeAccent),
              title: Text(AppTexts.get('support', cleanLang)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}