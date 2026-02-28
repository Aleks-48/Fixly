import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
// Импортируем твой актуальный нотифайер
import 'package:fixly_app/theme_notifier.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  
  // Данные профиля
  String _userName = 'Загрузка...';
  String _userBin = '';
  String _userRole = 'Загрузка...';
  int _completedOrders = 0;
  int _activeOrders = 0;
  double _rating = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Загрузка данных из Supabase
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
            _userName = data['name'] ?? 'Имя не указано';
            _userBin = data['bin']?.toString() ?? 'Не указан';
            _userRole = data['role'] ?? 'Пользователь';
            _completedOrders = data['completed_count'] ?? 0;
            _activeOrders = data['active_count'] ?? 0;
            _rating = (data['avg_rating'] as num?)?.toDouble() ?? 0.0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка загрузки: $e");
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
    // Получаем доступ к теме через ThemeNotifier
    final themeNotifier = context.watch<ThemeNotifier>();
    final bool isDark = themeNotifier.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('Мой Профиль', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
          ),

      
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildHeader(isDark, textColor),
                  const SizedBox(height: 25),
                  _buildStatsGrid(isDark),
                  const SizedBox(height: 25),
                  _buildInfoSection(isDark, textColor),
                  const SizedBox(height: 25),
                  // Передаем themeNotifier в виджет карточки
                  _buildThemeCard(isDark, textColor, themeNotifier),
                  const SizedBox(height: 30),
                  _buildLogoutButton(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              child: const Icon(LucideIcons.user, size: 55, color: Colors.blueAccent),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(_userName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
        Text(userEmail, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        _statItem("В работе", _activeOrders.toString(), LucideIcons.clock, Colors.orange),
        _statItem("Готово", _completedOrders.toString(), LucideIcons.checkCircle2, Colors.green),
        _statItem("Рейтинг", _rating.toString(), LucideIcons.star, Colors.amber),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _infoRow(LucideIcons.briefcase, "Роль", _userRole, Colors.blueAccent),
          const Divider(height: 20),
          _infoRow(LucideIcons.fileDigit, "БИН/ИИН", _userBin, Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 15),
        Text(title, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ОБНОВЛЕННЫЙ ВИДЖЕТ ПЕРЕКЛЮЧАТЕЛЯ
 Widget _buildThemeCard(bool isDark, Color textColor, ThemeNotifier themeNotifier) {
  return Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      leading: Icon(
        themeNotifier.themeMode == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun, 
        color: Colors.blueAccent
      ),
      title: Text('Темный режим', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      trailing: Switch(
        activeColor: Colors.blueAccent,
        // ОЧЕНЬ ВАЖНО: берем значение ТОЛЬКО из themeNotifier
        value: themeNotifier.themeMode == ThemeMode.dark, 
        onChanged: (bool value) async {
          // Вызываем метод и НЕ делаем setState внутри экрана
          await themeNotifier.toggleTheme(value);
        },
      ),
    ),
  );
}

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _signOut,
        icon: const Icon(LucideIcons.logOut, size: 18),
        label: const Text("Выйти из аккаунта", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  void _showEditDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Функция редактирования в разработке")),
    );
  }
}