import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/utils/app_texts.dart';
import 'package:fixly_app/screens/master_Detail_Page.dart';

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
  
  // Категории для фильтрации (соответствуют специализациям в БД)
  final List<String> _categories = [
    "Все", "Дворник", "Сантехник", "Электрик", 
    "Юрист (ОСИ)", "Клининг", "Маляр"
  ];

  /// Получение списка мастеров с фильтрацией на стороне клиента
  Future<List<Map<String, dynamic>>> _getMasters() async {
    try {
      // Запрашиваем только тех, у кого роль именно 'master'
      final response = await supabase
          .from('profiles')
          .select('*') 
          .eq('role', 'master')
          .order('name', ascending: true);
      
      List<Map<String, dynamic>> masters = List<Map<String, dynamic>>.from(response);

      // Применяем фильтры
      masters = masters.where((m) {
        final name = (m['name'] ?? m['full_name'] ?? "").toString();
        final email = (m['email'] ?? "").toString();
        final spec = (m['specialization'] ?? "").toString().toLowerCase();

        // 1. Исключаем тестовые аккаунты (например, Андрей)
        if (name.contains("Андрей") || email == "anovokresenov129@gamil.com") {
          return false; 
        }

        // 2. Фильтр по поисковой строке
        bool matchesSearch = name.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // 3. Фильтр по выбранной категории (чипам)
        bool matchesCategory = _selectedCategory == "Все" || 
                               spec.contains(_selectedCategory.toLowerCase());
        
        return matchesSearch && matchesCategory && name.isNotEmpty;
      }).toList();

      return masters;
    } catch (e) {
      debugPrint("Ошибка получения списка мастеров: $e");
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              AppTexts.get('masters', lang), 
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 20)
            ),
          ),
          body: Column(
            children: [
              // Поле поиска
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: lang == 'ru' ? "Найти специалиста..." : "Маманды іздеу...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF3B82F6)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), 
                      borderSide: BorderSide.none
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), 
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
                    ),
                  ),
                ),
              ),

              // Горизонтальный список категорий (Чипы)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedCategory = category),
                        selectedColor: const Color(0xFF3B82F6),
                        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)
                          )
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Список мастеров
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: const Color(0xFF3B82F6),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getMasters(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
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

  /// Виджет карточки мастера
  Widget _buildMasterCard(Map<String, dynamic> master, bool isDark, String lang) {
    final String displayName = master['name'] ?? master['full_name'] ?? "Мастер";
    final String orgName = master['company_name'] ?? (lang == 'ru' ? "Частный мастер" : "Жеке шебер");
    final String specialization = master['specialization'] ?? (lang == 'ru' ? 'Универсал' : 'Әмбебап');
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => MasterDetailPage(masterData: master))
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Аватарка
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.user, size: 30, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 16),
              
              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orgName, 
                      style: const TextStyle(color: Colors.grey, fontSize: 13)
                    ),
                    const SizedBox(height: 8),
                    // Тег специализации
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                        specialization,
                        style: const TextStyle(
                          color: Color(0xFF3B82F6), 
                          fontSize: 11, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Кнопка действия
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle
                    ),
                    child: const Icon(LucideIcons.phone, size: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'ru' ? "Вызвать" : "Шақыру",
                    style: const TextStyle(fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Заглушка при отсутствии результатов
  Widget _buildEmptyState(String lang, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.userX, 
            size: 64, 
            color: isDark ? Colors.white10 : Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            lang == 'ru' ? "Специалисты не найдены" : "Мамандар табылмады", 
            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)
          ),
          const SizedBox(height: 4),
          Text(
            lang == 'ru' ? "Попробуйте изменить запрос" : "Сұранысты өзгертіп көріңіз", 
            style: const TextStyle(color: Colors.grey, fontSize: 13)
          ),
        ],
      ),
    );
  }
}