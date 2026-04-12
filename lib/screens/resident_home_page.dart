import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/announcements_screen.dart'; // Не забудь создать этот файл

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _buildingId; 
  String? _buildingAddress;

  @override
  void initState() {
    super.initState();
    _getResidentBuilding();
  }

  Future<void> _getResidentBuilding() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('building_id, buildings(address)')
            .eq('id', user.id)
            .maybeSingle();
        
        if (mounted) {
          if (data != null && data['building_id'] != null) {
            setState(() {
              _buildingId = data['building_id']?.toString();
              _buildingAddress = data['buildings']?['address']?.toString();
              _isLoading = false;
            });
          } else {
            setState(() {
              _buildingId = null;
              _isLoading = false;
            });
          }
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
                if (_buildingAddress != null)
                  Text(
                    _buildingAddress!,
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  if (_buildingId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AnnouncementsScreen(buildingId: _buildingId!)),
                    );
                  }
                },
                icon: Icon(LucideIcons.megaphone, color: isDark ? Colors.white : Colors.black87),
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
                        _buildQuickAction(isDark, lang),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang == 'ru' ? "Последние новости" : "Соңғы жаңалықтар",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_buildingId != null)
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => AnnouncementsScreen(buildingId: _buildingId!)),
                                  );
                                }, 
                                child: Text(
                                  lang == 'ru' ? "Все" : "Барлығы", 
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                                )
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                  MaterialPageRoute(builder: (context) => const CreateOrderPage(initialCategory: '', masterId: null, masterName: null, prefillDescription: '',)),
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
        if (snapshot.hasError) return const SizedBox();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState(lang, isDark, false);

        // Ограничиваем только 2 объявлениями на главном экране
        final displayItems = items.take(2).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return _buildAnnouncementCard(item, isDark, lang);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item, bool isDark, String lang) {
    DateTime date = DateTime.parse(item['created_at'] ?? DateTime.now().toString());
    final String formattedDate = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

    return InkWell(
      onTap: () => _showAnnouncementDetails(context, item, isDark, lang),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
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
                const Icon(LucideIcons.megaphone, size: 16, color: Colors.blueAccent),
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
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
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
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 28),
            Text(item['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text(item['content'] ?? '', style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(lang == 'ru' ? "Понятно" : "Түсінікті"),
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
          Icon(noBuilding ? LucideIcons.mapPin : LucideIcons.layoutList, color: Colors.blueAccent.withOpacity(0.2), size: 64),
          const SizedBox(height: 20),
          Text(noBuilding ? (lang == 'ru' ? "Адрес не привязан" : "Мекен-жай тіркелмеген") : (lang == 'ru' ? "Объявлений пока нет" : "Хабарландырулар жоқ"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}