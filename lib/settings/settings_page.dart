// lib/screens/settings_page.dart

import 'package:fixly_app/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/theme/app_theme.dart'; // Единая дизайн-система Fixly

class SettingsPage extends StatefulWidget {
  final String currentName;
  final String currentBin;

  const SettingsPage({
    super.key,
    required this.currentName,
    required this.currentBin,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;

  Future<void> _contactSupport() async {
    final Uri url = Uri.parse("https://wa.me/77055966486"); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("WhatsApp не найден"),
            backgroundColor: c.danger,
          )
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
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
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeNotifier>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final c = AppColors.of(context);
    
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? "Настройки" : "Баптаулар", 
              style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: c.textPrimary),
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            children: [
              _StaggeredEntrance(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupTitle(context, lang == 'ru' ? "Аккаунт" : "Аккаунт"),
                    _buildCard(context, [
                      _buildActionTile(
                        context, 
                        LucideIcons.user, 
                        c.primary, 
                        lang == 'ru' ? "Редактировать профиль" : "Профильді өңдеу", 
                        () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                initialName: widget.currentName, 
                                initialBin: widget.currentBin,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildActionTile(
                        context, 
                        LucideIcons.shieldCheck, 
                        c.success, 
                        lang == 'ru' ? "Безопасность" : "Қауіпсіздік", 
                        () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const SecurityPage()),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildLanguageTile(context, lang),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _StaggeredEntrance(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupTitle(context, lang == 'ru' ? "Предпочтения" : "Қалаулар"),
                    _buildCard(context, [
                      _buildSwitchTile(
                        context, 
                        Icons.dark_mode_outlined, 
                        c.warning, 
                        lang == 'ru' ? "Темная тема" : "Қараңғы режим", 
                        isDark, 
                        (val) => themeProvider.toggleTheme(val),
                      ),
                      _buildDivider(context),
                      _buildSwitchTile(
                        context, 
                        LucideIcons.bell, 
                        c.primary, 
                        lang == 'ru' ? "Уведомления" : "Хабарландырулар", 
                        _notificationsEnabled, 
                        (val) => setState(() => _notificationsEnabled = val),
                      ),
                      _buildDivider(context),
                      _buildSwitchTile(
                        context, 
                        LucideIcons.fingerprint, 
                        c.success, 
                        lang == 'ru' ? "Биометрия" : "Биометрия", 
                        _biometricEnabled, 
                        (val) => setState(() => _biometricEnabled = val),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _StaggeredEntrance(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupTitle(context, lang == 'ru' ? "Поддержка" : "Қолдау"),
                    _buildCard(context, [
                      _buildActionTile(
                        context, 
                        LucideIcons.helpCircle, 
                        c.primary, 
                        lang == 'ru' ? "Центр помощи" : "Көмек орталығы", 
                        () {},
                      ),
                      _buildDivider(context),
                      _buildActionTile(
                        context, 
                        LucideIcons.messageCircle, 
                        c.success, 
                        lang == 'ru' ? "Написать в WhatsApp" : "WhatsApp-қа жазу", 
                        _contactSupport,
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _StaggeredEntrance(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupTitle(context, lang == 'ru' ? "Система" : "Жүйе"),
                    _buildCard(context, [
                      _buildActionTile(
                        context, 
                        LucideIcons.trash2, 
                        c.danger, 
                        lang == 'ru' ? "Очистить кеш" : "Кешті тазалау", 
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lang == 'ru' ? "Кеш очищен" : "Кеш тазаланды"),
                              backgroundColor: c.success,
                            )
                          );
                        },
                      ),
                      _buildDivider(context),
                      ListTile(
                        leading: _buildIconBackground(LucideIcons.info, c.textTertiary),
                        title: Text(
                          lang == 'ru' ? "Версия" : "Нұсқа", 
                          style: TextStyle(fontWeight: FontWeight.w500, color: c.textPrimary),
                        ),
                        trailing: Text(
                          "1.0.24", 
                          style: TextStyle(color: c.textTertiary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Премиум-кнопка выхода
              _StaggeredEntrance(
                index: 4,
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: _handleSignOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: c.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: c.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.logOut, color: c.danger, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            lang == 'ru' ? "ВЫЙТИ ИЗ АККАУНТА" : "АККАУНТТАН ШЫҒУ",
                            style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupTitle(BuildContext context, String title) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: c.textTertiary, 
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    final c = AppColors.of(context);
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final c = AppColors.of(context);
    return Divider(
      height: 1, 
      indent: 60, 
      endIndent: 20, 
      color: c.textTertiary.withOpacity(0.1),
    );
  }

  Widget _buildIconBackground(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, Color iconColor, String title, VoidCallback onTap) {
    final c = AppColors.of(context);
    return ListTile(
      leading: _buildIconBackground(icon, iconColor),
      title: Text(
        title, 
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
      ),
      trailing: Icon(LucideIcons.chevronRight, size: 18, color: c.textTertiary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(BuildContext context, IconData icon, Color iconColor, String title, bool value, ValueChanged<bool> onChanged) {
    final c = AppColors.of(context);
    return ListTile(
      leading: _buildIconBackground(icon, iconColor),
      title: Text(
        title, 
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: c.primary,
        inactiveTrackColor: c.textTertiary.withOpacity(0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildLanguageTile(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return ListTile(
      leading: _buildIconBackground(LucideIcons.languages, c.primary),
      title: Text(
        lang == 'ru' ? "Язык приложения" : "Қосымша тілі", 
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lang == 'ru' ? "Русский" : "Қазақша", 
            style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.arrowRightLeft, size: 16, color: c.textTertiary),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onTap: () => appLanguage.value = (lang == 'ru' ? 'kz' : 'ru'),
    );
  }
}

// --- СТРАНИЦА РЕДАКТИРОВАНИЯ ПРОФИЛЯ ---
class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialBin;
  const EditProfilePage({super.key, required this.initialName, required this.initialBin});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _binController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _binController = TextEditingController(text: widget.initialBin);
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    try {
      await supabase.from('profiles').update({
        'name': _nameController.text.trim(),
        'bin': _binController.text.trim(),
      }).eq('id', userId!);

      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Профиль обновлен!"),
            backgroundColor: c.success,
          )
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка: $e"),
            backgroundColor: c.danger,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          "Редактирование", 
          style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
        ), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPremiumTextField(context, "Имя", LucideIcons.user, _nameController),
            const SizedBox(height: 20),
            _buildPremiumTextField(context, "БИН/ИИН (12 цифр)", LucideIcons.creditCard, _binController, isNumber: true),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _updateProfile,
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("СОХРАНИТЬ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTextField(BuildContext context, String label, IconData icon, TextEditingController controller, {bool isNumber = false}) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: isNumber ? 12 : null,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textTertiary),
        prefixIcon: Icon(icon, color: c.primary),
        filled: true,
        fillColor: c.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
      ),
    );
  }
}

// --- СТРАНИЦА БЕЗОПАСНОСТИ ---
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          "Безопасность", 
          style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
        ), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.textTertiary.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10), 
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.15), 
                      borderRadius: BorderRadius.circular(12),
                    ), 
                    child: Icon(LucideIcons.mail, color: c.primary),
                  ),
                  title: Text(
                    "Сбросить пароль", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  subtitle: Text(
                    "Отправим письмо для смены", 
                    style: TextStyle(fontSize: 14, color: c.textTertiary),
                  ),
                  trailing: Icon(LucideIcons.chevronRight, color: c.textTertiary),
                  onTap: () async {
                    final email = Supabase.instance.client.auth.currentUser?.email;
                    if (email != null) {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Инструкции отправлены на email"),
                            backgroundColor: c.success,
                          )
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, indent: 70, color: c.textTertiary.withOpacity(0.1)),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10), 
                    decoration: BoxDecoration(
                      color: c.danger.withOpacity(0.15), 
                      borderRadius: BorderRadius.circular(12),
                    ), 
                    child: Icon(LucideIcons.userX, color: c.danger),
                  ),
                  title: Text(
                    "Удалить аккаунт", 
                    style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Данное действие необратимо", 
                    style: TextStyle(fontSize: 14, color: c.textTertiary),
                  ),
                  onTap: () {
                    showDialog(
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
                            "Вы уверены?", 
                            style: TextStyle(color: alertC.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            "Ваш профиль и все данные будут удалены.", 
                            style: TextStyle(color: alertC.textTertiary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx), 
                              child: Text("Отмена", style: TextStyle(color: alertC.textTertiary)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx), 
                              child: Text(
                                "Удалить", 
                                style: TextStyle(color: alertC.danger, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация элементов настроек
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
    begin: const Offset(0, 0.08),
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