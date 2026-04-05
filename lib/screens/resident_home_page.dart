import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/screens/create_order_page.dart';

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _buildingId;
  String? _buildingName;

  @override
  void initState() {
    super.initState();
    _getResidentBuilding();
  }

  /// Получаем ID дома и его название из профиля жителя
  Future<void> _getResidentBuilding() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Запрос профиля с подгрузкой данных о доме
        final data = await supabase
            .from('profiles')
            .select('building_id, buildings(name)')
            .eq('id', user.id)
            .maybeSingle();
        
        if (mounted && data != null) {
          setState(() {
            _buildingId = data['building_id']?.toString();
            _buildingName = data['buildings']?['name']?.toString();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка получения данных дома: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'ru' ? "Мой Дом" : "Менің Үйім",
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 22,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (_buildingName != null)
                  Text(
                    _buildingName!,
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(LucideIcons.bell, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : RefreshIndicator(
                  onRefresh: _getResidentBuilding,
                  color: Colors.blueAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Блок быстрой подачи заявки
                        _buildQuickAction(isDark, lang),
                        
                        const SizedBox(height: 32),

                        // 2. Заголовок ленты объявлений
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang == 'ru' ? "Объявления ОСИ" : "ОСИ хабарландырулары",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {}, 
                              child: Text(lang == 'ru' ? "Все" : "Барлығы", style: const TextStyle(color: Colors.blueAccent))
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 3. Список объявлений (Работает через Stream)
                        _buildAnnouncementsList(isDark, lang),
                        
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildQuickAction(bool isDark, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.home, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            lang == 'ru' ? "Что-то сломалось?" : "Бірдеңе бұзылды ма?",
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ru' 
                ? "Создайте заявку, и мастера ОСИ придут на помощь" 
                : "Өтінім жасаңыз, ОСИ шеберлері көмекке келеді",
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateOrderPage(initialCategory: '')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                lang == 'ru' ? "Подать заявку" : "Өтінім беру",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsList(bool isDark, String lang) {
    // Если у пользователя нет привязанного дома в профиле
    if (_buildingId == null) {
      return _buildEmptyState(lang, isDark, true);
    }

    // Стрим для получения объявлений в реальном времени
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .eq('building_id', _buildingId!) // Фильтр по дому
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(lang, isDark, false);
        }

        final items = snapshot.data!;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length > 5 ? 5 : items.length, // Показываем последние 5
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final DateTime date = DateTime.parse(item['created_at'] ?? DateTime.now().toString());
            final String formattedDate = "${date.day}.${date.month}.${date.year}";

            return InkWell(
              onTap: () => _showAnnouncementDetails(context, item, isDark, lang),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        const Icon(LucideIcons.megaphone, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.black54,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAnnouncementDetails(BuildContext context, Map<String, dynamic> item, bool isDark, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(LucideIcons.megaphone, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['title'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              item['content'] ?? '',
              style: TextStyle(
                fontSize: 16, 
                height: 1.6, 
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  lang == 'ru' ? "Закрыть" : "Жабу", 
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String lang, bool isDark, bool noBuilding) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.layoutList, color: Colors.grey.withOpacity(0.2), size: 64),
          const SizedBox(height: 20),
          Text(
            noBuilding 
                ? (lang == 'ru' ? "Адрес не привязан" : "Мекен-жай тіркелмеген")
                : (lang == 'ru' ? "Объявлений пока нет" : "Хабарландырулар жоқ"),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ru' 
                ? "Здесь появится важная информация от вашего ОСИ" 
                : "Мұнда сіздің ОСИ-ден маңызды ақпарат пайда болады",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}