import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/utils/app_texts.dart';
import '../widgets/rating_stars.dart'; 
import 'package:fixly_app/screens/Master_Detail_Page.dart';

class MastersListScreen extends StatefulWidget {
  const MastersListScreen({super.key});

  @override
  State<MastersListScreen> createState() => _MastersListScreenState();
}

class _MastersListScreenState extends State<MastersListScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "Все";
  
  final List<String> _categories = [
    "Все", "Дворник", "Сантехник", "Электрик", 
    "Юрист (ОСИ)", "Клининг", "Маляр"
  ];

  Future<List<Map<String, dynamic>>> _getMasters() async {
    try {
      // Запрашиваем только тех, у кого роль именно 'master'
      final response = await supabase
          .from('profiles')
          .select('*') 
          .eq('role', 'master')
          .order('name', ascending: true);
      
      List<Map<String, dynamic>> masters = List<Map<String, dynamic>>.from(response);

      // ФИЛЬТРАЦИЯ: Убираем Андрея и проверяем категории
      masters = masters.where((m) {
        final name = (m['name'] ?? m['full_name'] ?? "").toString();
        final email = (m['email'] ?? "").toString();
        final spec = (m['specialization'] ?? "").toString().toLowerCase();

        // 1. Убираем Андрея (по имени или по его email, который виден на скриншоте)
        if (name.contains("Андрей") || email == "anovokresenov129@gamil.com") {
          return false; 
        }

        // 2. Фильтр по поиску
        bool matchesSearch = name.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // 3. Фильтр по категориям
        bool matchesCategory = _selectedCategory == "Все" || spec == _selectedCategory.toLowerCase();
        
        return matchesSearch && matchesCategory && name.isNotEmpty;
      }).toList();

      return masters;
    } catch (e) {
      debugPrint("Ошибка БД: $e");
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              AppTexts.get('masters', lang), 
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor)
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: lang == 'ru' ? "Найти мастера..." : "Шеберді іздеу...",
                    prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF3B82F6)),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), 
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedCategory = category),
                        selectedColor: const Color(0xFF3B82F6),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: const Color(0xFF3B82F6),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getMasters(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState(lang, isDark);
                      }

                      final masters = snapshot.data!;

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: masters.length,
                        itemBuilder: (context, index) {
                          final master = masters[index];
                          return _buildMasterCard(master, isDark, lang);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasterCard(Map<String, dynamic> master, bool isDark, String lang) {
    String displayName = master['name'] ?? master['full_name'] ?? "Мастер";
    String orgName = master['company_name'] ?? (lang == 'ru' ? "Частный мастер" : "Жеке шебер");
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
              child: const Icon(LucideIcons.user, size: 28, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  Text(orgName, style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      master['specialization'] ?? (lang == 'ru' ? 'Универсал' : 'Әмбебап'),
                      style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(lang == 'ru' ? "Вызвать" : "Шақыру", style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MasterDetailPage(masterData: master)));
                  }, 
                  child: Text(lang == 'ru' ? "Детали" : "Толығырақ", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String lang, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.userX, size: 64, color: isDark ? Colors.white10 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(lang == 'ru' ? "Специалисты не найдены" : "Мамандар табылмады", style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}