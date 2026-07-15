// lib/screens/profile_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/theme_notifier.dart';
import 'package:fixly_app/main.dart'; // Для работы с appLanguage
import 'package:fixly_app/theme/app_theme.dart'; // Единая дизайн-система Fixly

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String _userName = 'Загрузка...';
  String _userBin = 'Не указан';
  String _userRole = 'resident'; 
  int _completedOrders = 0;
  int _activeOrders = 0;
  double _rating = 0.0;
  String _address = 'Адрес не указан';

  // Двуязычный маппинг ролей для интерфейса
  final Map<String, Map<String, String>> _rolesMap = {
    'ru': {
      'resident': 'Житель',
      'chairman': 'Председатель',
      'master': 'Мастер',
    },
    'kz': {
      'resident': 'Тұрғын',
      'chairman': 'Төраға',
      'master': 'Шебер',
    }
  };

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

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
            
            final String rawRole = data['role']?.toString() ?? 'resident';
            _userRole = _rolesMap['ru']!.containsKey(rawRole) ? rawRole : 'resident';
            
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
          final c = AppColors.of(context);
          final currentLang = appLanguage.value;
          final roleName = _rolesMap[currentLang]?[newRole] ?? newRole;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentLang == 'ru' 
                    ? "Роль успешно изменена на: $roleName" 
                    : "Рөл сәтті өзгертілді: $roleName",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: c.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Ошибка обновления роли: $e");
      if (mounted) {
        final c = AppColors.of(context);
        final currentLang = appLanguage.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == 'ru' ? "Не удалось изменить роль" : "Рөлді өзгерту мүмкін болмады"
            ), 
            backgroundColor: c.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get userEmail => supabase.auth.currentUser?.email ?? 'Гость';

  Future<void> _signOut() async {
    final lang = appLanguage.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final alertC = AppColors.of(dialogCtx);
        return AlertDialog(
          backgroundColor: alertC.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: alertC.textTertiary.withOpacity(0.15)),
          ),
          title: Text(
            lang == 'ru' ? "Выход" : "Шығу", 
            style: TextStyle(color: alertC.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            lang == 'ru' ? "Завершить сессию?" : "Шыққыңыз келе ме?", 
            style: TextStyle(color: alertC.textTertiary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false), 
              child: Text(
                lang == 'ru' ? "Нет" : "Жоқ", 
                style: TextStyle(color: alertC.textTertiary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true), 
              child: Text(
                lang == 'ru' ? "Да" : "Иә", 
                style: TextStyle(color: alertC.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    
    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final bool isDark = themeNotifier.themeMode == ThemeMode.dark;
    final c = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        // Динамический перевод дефолтных текстовых плейсхолдеров
        final displayName = _userName == 'Загрузка...' 
            ? (lang == 'ru' ? "Загрузка..." : "Жүктелуде...")
            : _userName == 'Имя не указано'
                ? (lang == 'ru' ? "Имя не указано" : "Аты-жөні көрсетілмеген")
                : _userName;

        final displayAddress = _address == 'Адрес не указан'
            ? (lang == 'ru' ? "Адрес не указан" : "Мекенжай көрсетілмеген")
            : _address;

        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? 'Мой Профиль' : 'Менің профилім', 
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(LucideIcons.refreshCw, size: 20, color: c.textTertiary),
                onPressed: _loadUserProfile,
              )
            ],
          ),
          body: _isLoading 
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : RefreshIndicator(
                  onRefresh: _loadUserProfile,
                  color: c.primary,
                  backgroundColor: c.card,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                    child: Column(
                      children: [
                        _StaggeredEntrance(
                          index: 0,
                          child: _buildHeader(context, displayName),
                        ),
                        const SizedBox(height: 25),
                        _StaggeredEntrance(
                          index: 1,
                          child: _buildStatsGrid(context, lang),
                        ),
                        const SizedBox(height: 25),
                        _StaggeredEntrance(
                          index: 2,
                          child: _buildDetailedInfoSection(context, lang, displayAddress),
                        ),
                        const SizedBox(height: 20),
                        _StaggeredEntrance(
                          index: 3,
                          child: _buildThemeCard(context, isDark, themeNotifier, lang),
                        ),
                        const SizedBox(height: 30),
                        _StaggeredEntrance(
                          index: 4,
                          child: _buildLogoutButton(context, lang),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    final c = AppColors.of(context);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.primary.withOpacity(0.15), width: 2),
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: c.primary.withOpacity(0.12),
                child: Icon(LucideIcons.user, size: 50, color: c.primary),
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.5),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          displayName, 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          userEmail, 
          style: TextStyle(color: c.textTertiary, fontSize: 14, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _statItem(
          context, 
          lang == 'ru' ? "В работе" : "Жұмыста", 
          _activeOrders.toString(), 
          LucideIcons.clock, 
          c.warning,
        ),
        const SizedBox(width: 12),
        _statItem(
          context, 
          lang == 'ru' ? "Завершено" : "Бітті", 
          _completedOrders.toString(), 
          LucideIcons.checkCircle2, 
          c.success,
        ),
        const SizedBox(width: 12),
        _statItem(
          context, 
          lang == 'ru' ? "Рейтинг" : "Рейтинг", 
          _rating.toString(), 
          LucideIcons.star, 
          c.warning,
        ),
      ],
    );
  }

  Widget _statItem(BuildContext context, String label, String value, IconData icon, Color color) {
    final c = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value, 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label, 
              style: TextStyle(fontSize: 13, color: c.textTertiary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedInfoSection(BuildContext context, String lang, String displayAddress) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.textTertiary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withOpacity(0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // ВЫБОР РОЛИ
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.shieldCheck, size: 18, color: c.primary),
              ),
              const SizedBox(width: 15),
              Text(
                lang == 'ru' ? "Ваша роль" : "Сіздің рөліңіз", 
                style: TextStyle(color: c.textTertiary, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _userRole,
                  dropdownColor: c.card,
                  icon: Icon(Icons.keyboard_arrow_down, size: 18, color: c.textTertiary),
                  style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 14),
                  borderRadius: BorderRadius.circular(15),
                  onChanged: _updateRole,
                  items: _rolesMap[lang]!.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          Divider(height: 30, thickness: 0.5, color: c.textTertiary.withOpacity(0.15)),
          _infoRow(
            context, 
            LucideIcons.fileDigit, 
            lang == 'ru' ? "ИИН / БИН" : "ЖСН / БСН", 
            _userBin == 'Не указан' 
                ? (lang == 'ru' ? "Не указан" : "Көрсетілмеген") 
                : _userBin, 
            c.primary,
          ),
          Divider(height: 30, thickness: 0.5, color: c.textTertiary.withOpacity(0.15)),
          _infoRow(
            context, 
            LucideIcons.mapPin, 
            lang == 'ru' ? "Адрес" : "Мекенжай", 
            displayAddress, 
            c.primary,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String title, String value, Color iconColor) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 15),
        Text(
          title, 
          style: TextStyle(color: c.textTertiary, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Expanded(
          child: Text(
            value, 
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context, bool isDark, ThemeNotifier themeNotifier, String lang) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.textTertiary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withOpacity(0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? LucideIcons.moon : LucideIcons.sun, 
            color: c.primary,
            size: 18,
          ),
        ),
        title: Text(
          lang == 'ru' ? 'Темная тема' : 'Қараңғы режим', 
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        trailing: Switch.adaptive(
          activeColor: c.primary,
          inactiveTrackColor: c.textTertiary.withOpacity(0.3),
          value: isDark, 
          onChanged: (bool value) async {
            await themeNotifier.toggleTheme(value);
          },
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _signOut,
        icon: const Icon(LucideIcons.logOut, size: 18),
        label: Text(
          lang == 'ru' ? "Выйти из аккаунта" : "Аккаунттан шығу", 
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: TextButton.styleFrom(
          foregroundColor: c.danger,
          backgroundColor: c.danger.withOpacity(0.1),
          side: BorderSide(color: c.danger.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация появления элементов
// ============================================================
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}