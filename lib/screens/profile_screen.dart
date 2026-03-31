import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
// Импортируем твой актуальный нотифайер темы
import 'package:fixly_app/theme_notifier.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  
  // Состояние загрузки и данные профиля
  bool _isLoading = true;
  String _userName = 'Загрузка...';
  String _userBin = 'Не указан';
  String _userRole = 'resident'; // Роль по умолчанию
  int _completedOrders = 0;
  int _activeOrders = 0;
  double _rating = 0.0;
  String _address = 'Адрес не указан';

  // Список доступных ролей для маппинга отображения
  final Map<String, String> _rolesMap = {
    'resident': 'Житель',
    'chairman': 'Председатель',
    'master': 'Мастер',
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Загрузка данных профиля напрямую из Supabase
  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _userName = data['name'] ?? data['full_name'] ?? 'Имя не указано';
            _userBin = data['bin']?.toString() ?? 'Не указан';
            
            // Проверка корректности роли из БД
            final String rawRole = data['role']?.toString() ?? 'resident';
            _userRole = _rolesMap.containsKey(rawRole) ? rawRole : 'resident';
            
            _completedOrders = data['completed_count'] ?? 0;
            _activeOrders = data['active_count'] ?? 0;
            _rating = (data['avg_rating'] as num?)?.toDouble() ?? 0.0;
            _address = data['address'] ?? 'мкр. Центральный, 2';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка при получении профиля: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Функция смены роли пользователя
  Future<void> _updateRole(String? newRole) async {
    if (newRole == null || newRole == _userRole) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase
            .from('profiles')
            .update({'role': newRole})
            .eq('id', user.id);
        
        setState(() {
          _userRole = newRole;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Роль успешно изменена на: ${_rolesMap[newRole]}"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Ошибка обновления роли: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Не удалось изменить роль"), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get userEmail => supabase.auth.currentUser?.email ?? 'Гость';

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем изменения темы через Provider
    final themeNotifier = context.watch<ThemeNotifier>();
    final bool isDark = themeNotifier.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('Мой Профиль', 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 20, color: textColor.withOpacity(0.6)),
            onPressed: _loadUserProfile,
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              color: Colors.blueAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  children: [
                    _buildHeader(isDark, textColor),
                    const SizedBox(height: 25),
                    _buildStatsGrid(isDark),
                    const SizedBox(height: 25),
                    _buildDetailedInfoSection(isDark, textColor),
                    const SizedBox(height: 20),
                    _buildThemeCard(isDark, textColor, themeNotifier),
                    const SizedBox(height: 30),
                    _buildLogoutButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent.withOpacity(0.1), width: 2),
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                child: const Icon(LucideIcons.user, size: 50, color: Colors.blueAccent),
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF0F0F10) : Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(_userName, 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)
        ),
        const SizedBox(height: 4),
        Text(userEmail, 
          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14)
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        _statItem("В работе", _activeOrders.toString(), LucideIcons.clock, Colors.orange),
        const SizedBox(width: 12),
        _statItem("Завершено", _completedOrders.toString(), LucideIcons.checkCircle2, Colors.green),
        const SizedBox(width: 12),
        _statItem("Рейтинг", _rating.toString(), LucideIcons.star, Colors.amber),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedInfoSection(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ВЫБОР РОЛИ
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 20, color: Colors.blueAccent),
              const SizedBox(width: 15),
              const Text("Ваша роль", style: TextStyle(color: Colors.grey, fontSize: 15)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _userRole,
                  icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textColor.withOpacity(0.5)),
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14),
                  borderRadius: BorderRadius.circular(15),
                  onChanged: _updateRole,
                  items: _rolesMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const Divider(height: 30, thickness: 0.5),
          _infoRow(LucideIcons.fileDigit, "ИИН / БИН", _userBin, Colors.purpleAccent, textColor),
          const Divider(height: 30, thickness: 0.5),
          _infoRow(LucideIcons.mapPin, "Адрес", _address, Colors.redAccent, textColor),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value, Color iconColor, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 15),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const Spacer(),
        Text(value, 
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)
        ),
      ],
    );
  }

  Widget _buildThemeCard(bool isDark, Color textColor, ThemeNotifier themeNotifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? LucideIcons.moon : LucideIcons.sun, 
            color: Colors.blueAccent,
            size: 18,
          ),
        ),
        title: Text('Темная тема', 
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)
        ),
        trailing: Switch.adaptive(
          activeColor: Colors.blueAccent,
          value: isDark, 
          onChanged: (bool value) async {
            await themeNotifier.toggleTheme(value);
          },
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _signOut,
        icon: const Icon(LucideIcons.logOut, size: 18),
        label: const Text("Выйти из аккаунта", 
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          backgroundColor: Colors.redAccent.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}