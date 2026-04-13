import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// Импорты страниц
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/masters_list_screen.dart';
import 'package:fixly_app/screens/profile/my_Buildings_Screen.dart';
import 'package:fixly_app/screens/chat_list_screen.dart';
import 'package:fixly_app/screens/profile_page.dart';
import 'package:fixly_app/screens/income_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/profile/chairman_Analytics_Screen.dart';
import 'package:fixly_app/screens/documents_screen.dart';
import 'package:fixly_app/screens/library_screen.dart';
import 'package:fixly_app/screens/resident_home_page.dart'; 
import 'package:fixly_app/screens/market_screen.dart';
import 'package:fixly_app/screens/voting_page.dart'; 
import 'package:fixly_app/screens/my_work_screen.dart';
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

  // --- ЛОГИКА ЦЕНТРАЛЬНОЙ КНОПКИ "+" ---
  void _onPlusButtonPressed() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_userRole == 'resident') {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => const CreateOrderPage(initialCategory: '', masterId:'', masterName:'', prefillDescription: '',))
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appLanguage.value == 'ru' ? "Что создать?" : "Не жасау керек?",
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white : Colors.black
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuOption(
                  icon: LucideIcons.wrench,
                  title: appLanguage.value == 'ru' ? "Заявка (Service)" : "Өтінім",
                  color: Colors.blueAccent,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderPage(initialCategory: '', masterId:'', masterName:'', prefillDescription: '',)));
                  },
                ),
                _buildMenuOption(
                  icon: LucideIcons.megaphone,
                  title: appLanguage.value == 'ru' ? "Объявление (News)" : "Хабарландыру",
                  color: Colors.orangeAccent,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _showAddAnnouncementDialog();
                  },
                ),
                _buildMenuOption(
                  icon: LucideIcons.checkSquare,
                  title: appLanguage.value == 'ru' ? "Голосование (Voting)" : "Дауыс беру",
                  color: Colors.greenAccent,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _showAddProposalDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon, 
    required String title, 
    required Color color, 
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  // --- ДИАЛОГ СОЗДАНИЯ ОБЪЯВЛЕНИЯ ---
  void _showAddAnnouncementDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Сначала получаем данные о доме председателя
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userData = await Supabase.instance.client
        .from('profiles')
        .select('building_id')
        .eq('id', user.id)
        .maybeSingle();
    
    final String? myBuildingId = userData?['building_id']?.toString();

    // Если ID дома нет в базе - выводим ошибку
    if (myBuildingId == null || myBuildingId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appLanguage.value == 'ru' 
            ? "Ошибка: Дом не привязан к профилю. Выберите дом в настройках." 
            : "Қате: Үй профильге тіркелмеген."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(appLanguage.value == 'ru' ? "Новое объявление" : "Жаңа хабарландыру"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController, 
              decoration: InputDecoration(hintText: appLanguage.value == 'ru' ? "Заголовок" : "Тақырып")
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController, 
              maxLines: 3, 
              decoration: InputDecoration(hintText: appLanguage.value == 'ru' ? "Текст объявления" : "Мәтін")
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(appLanguage.value == 'ru' ? "Отмена" : "Бас тарту")),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  await Supabase.instance.client.from('announcements').insert({
                    'title': titleController.text,
                    'content': contentController.text,
                    'author_id': user.id,
                    'building_id': myBuildingId,
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("Ошибка сохранения объявления: $e");
                }
              }
            },
            child: Text(appLanguage.value == 'ru' ? "Создать" : "Жариялау"),
          ),
        ],
      ),
    );
  }

  // --- ДИАЛОГ СОЗДАНИЯ ГОЛОСОВАНИЯ ---
  void _showAddProposalDialog() async {
    final TextEditingController titleController = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Получаем building_id, чтобы голосование было видно жильцам именно этого дома
    final userData = await Supabase.instance.client
        .from('profiles')
        .select('building_id')
        .eq('id', user.id)
        .maybeSingle();
    
    final String? myBuildingId = userData?['building_id']?.toString();

    if (myBuildingId == null || myBuildingId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ошибка: Невозможно запустить голосование без привязки к дому.")),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          appLanguage.value == 'ru' ? "Тема голосования" : "Дауыс беру тақырыбы",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: titleController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "Например: Ремонт крыши",
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  await Supabase.instance.client.from('proposals').insert({
                    'title': titleController.text,
                    'author_id': user.id,
                    'building_id': myBuildingId, // ДОБАВЛЕНО: теперь голосование привязано к дому
                    'is_active': true,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Голосование запущено!")));
                  }
                } catch (e) {
                  debugPrint("Ошибка создания голосования: $e");
                }
              }
            },
            child: const Text("Запустить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ТЬЮТОРИАЛ ЛОГИКА ---
  void _playStepVoice(int step, String lang) async {
    String cleanLang = _getCleanLang(lang);
    String fileName = "${cleanLang}_step$step.mp3"; 
    try {
      await _audioPlayer.stop(); 
      await _audioPlayer.play(AssetSource("sounds/tutorial/$fileName"));
    } catch (e) { debugPrint("Файл озвучки не найден: $fileName"); }
  }

  void _nextTutorialStep() {
    final lang = appLanguage.value; 
    setState(() {
      _tutorialStep++;
      switch (_tutorialStep) {
        case 1:
          _selectedIndex = 0; 
          _helperMessage = {'ru': 'Это ваша главная страница.', 'kk': 'Бұл басты бетіңіз.'};
          break;
        case 2:
          _selectedIndex = 1; 
          _helperMessage = {'ru': 'Тут список мастеров.', 'kk': 'Мұнда шеберлер тізімі.'};
          break;
        case 3:
          _scaffoldKey.currentState?.openDrawer();
          _helperMessage = {'ru': 'Боковое меню с инструментами.', 'kk': 'Құралдары бар бүйірлік мәзір.'};
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
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: Text(cleanLang == 'kk' ? 'Келесі' : 'Далее', style: const TextStyle(color: Colors.white)),
                    )
                  ] : null,
                  onTap: () { if (!_isTutorialActive) _showHelperMenu(context, lang); }, 
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(isDark, cleanLang),
          floatingActionButton: (_userRole == 'chairman' || _userRole == 'resident') 
              ? FloatingActionButton(
                  onPressed: _onPlusButtonPressed, 
                  backgroundColor: Colors.blueAccent,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ) 
              : null,
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
              Navigator.push(context, MaterialPageRoute(builder: (c) => const VotingPage(proposalId: '', proposalTitle: '',)));
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