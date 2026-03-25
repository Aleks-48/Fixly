import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/screens/create_order_page.dart'; // Импорт страницы создания заявки

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _buildingId;

  @override
  void initState() {
    super.initState();
    _getResidentBuilding();
  }

  /// Получаем ID дома, к которому привязан житель из его профиля
  Future<void> _getResidentBuilding() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('building_id')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _buildingId = data['building_id']?.toString();
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
            title: Text(
              lang == 'ru' ? "Мой Дом" : "Менің Үйім",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // Здесь можно открыть историю уведомлений
                },
                icon: Icon(LucideIcons.bell, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _getResidentBuilding,
                  color: Colors.blueAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Блок быстрой подачи заявки (Интерактивный)
                        _buildQuickAction(isDark, lang),
                        
                        const SizedBox(height: 30),

                        // 2. Заголовок ленты новостей
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang == 'ru' ? "Объявления ОСИ" : "ОСИ хабарландырулары",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Icon(LucideIcons.megaphone, size: 20, color: Colors.blueAccent.withOpacity(0.7)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Реальный список объявлений из Supabase через Stream
                        _buildAnnouncementsList(isDark, lang),
                        
                        // Отступ снизу для удобства скролла
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  /// Виджет синей карточки для подачи заявки
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
            color: Colors.blueAccent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'ru' ? "Что-то сломалось?" : "Бірдеңе бұзылды ма?",
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ru' 
                ? "Сообщите об инциденте в ОСИ прямо сейчас" 
                : "Оқиға туралы ОСИ-ге дәл қазір хабарлаңыз",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // ПЕРЕХОД НА СТРАНИЦУ СОЗДАНИЯ ЗАЯВКИ
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateOrderPage(initialCategory: 'incident'),
                ),
              );
            },
            icon: const Icon(LucideIcons.alertTriangle, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            label: Text(
              lang == 'ru' ? "Подать заявку" : "Өтінім беру",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Стрит-билдер для получения списка объявлений в реальном времени
  Widget _buildAnnouncementsList(bool isDark, String lang) {
    if (_buildingId == null) {
      return _buildEmptyState(lang, isDark, true);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .eq('building_id', _buildingId!)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(lang, isDark, false);
        }

        final items = snapshot.data!;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () => _showAnnouncementDetails(context, item, isDark, lang),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.info, color: Colors.blueAccent, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? (lang == 'ru' ? 'Объявление' : 'Хабарландыру'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Метод для открытия деталей объявления в BottomSheet
  void _showAnnouncementDetails(BuildContext context, Map<String, dynamic> item, bool isDark, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              item['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              item['content'] ?? '',
              style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang == 'ru' ? "Понятно" : "Түсінікті", style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Состояние "Пусто"
  Widget _buildEmptyState(String lang, bool isDark, bool noBuilding) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.ghost, color: Colors.grey.withOpacity(0.3), size: 50),
          const SizedBox(height: 16),
          Text(
            noBuilding 
                ? (lang == 'ru' ? "Адрес не привязан к профилю" : "Мекен-жай профильге тіркелмеген")
                : (lang == 'ru' ? "Пока новостей нет" : "Әзірге жаңалықтар жоқ"),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}