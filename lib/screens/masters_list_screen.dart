import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/rating_stars.dart'; 
import 'package:fixly_app/screens/Master_Detail_Page.dart'; // Путь верный

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
  
  // Убрал "Ремонт ПК" по твоей просьбе
  final List<String> _categories = [
    "Все", "Дворник", "Сантехник", "Электрик", 
    "Юрист (ОСИ)", "Клининг", "Маляр"
  ];

Future<List<Map<String, dynamic>>> _getMasters() async {
  try {
    // Меняем eq('role', 'master') на eq('user_type', 'resident'), 
    // чтобы увидеть Ивана Ивановича и Андрея Гудко из твоей таблицы
    var query = supabase
        .from('profiles')
        .select('*') 
        .eq('user_type', 'resident');

      if (_selectedCategory != "Все") {
        query = query.eq('specialization', _selectedCategory);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('full_name', '%$_searchQuery%');
      }

  final response = await query.order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Специалисты", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // 1. Поисковая строка
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Найти мастера...",
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: Colors.blueAccent),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
              ),
            ),
          ),

          // 2. Категории
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
                    selectedColor: Colors.blueAccent,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // 3. Список мастеров
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getMasters(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final masters = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: masters.length,
                    itemBuilder: (context, index) {
                      final master = masters[index];
                      return _buildMasterCard(master, isDark);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterCard(Map<String, dynamic> master, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Аватар
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.blueAccent, Colors.tealAccent]),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: isDark ? Colors.black : Colors.white,
                backgroundImage: (master['avatar_url'] != null && master['avatar_url'].isNotEmpty)
                    ? NetworkImage(master['avatar_url']) 
                    : null,
                child: (master['avatar_url'] == null || master['avatar_url'].isEmpty)
                    ? Icon(LucideIcons.user, size: 28, color: Colors.grey.shade400) 
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    master['full_name'] ?? "Мастер",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      master['specialization'] ?? 'Универсал',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RatingStars(
                    rating: (master['avg_rating'] ?? 0.0).toDouble(),
                    size: 14,
                  ),
                ],
              ),
            ),

            // Кнопки
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Здесь будет логика вызова (создание заявки)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Вызвать", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                TextButton(
                  onPressed: () {
                    // ПЕРЕХОД НА СТРАНИЦУ ДЕТАЛЕЙ
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MasterDetailPage(masterData: master),
                      ),
                    );
                  }, 
                  child: const Text("Детали", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.userX, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("Специалисты не найдены", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}