import 'package:fixly_app/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:fixly_app/main.dart'; 

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("WhatsApp не найден"))
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final lang = appLanguage.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        title: Text(lang == 'ru' ? "Выход" : "Шығу"),
        content: Text(lang == 'ru' ? "Завершить сессию?" : "Шыққыңыз келе ме?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang == 'ru' ? "Нет" : "Жоқ", style: const TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(lang == 'ru' ? "Да" : "Иә", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeNotifier>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Настройки" : "Баптаулар", style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            children: [
              _buildGroupTitle(lang == 'ru' ? "Аккаунт" : "Аккаунт"),
              _buildCard(isDark, [
                _buildActionTile(LucideIcons.user, Colors.blue, lang == 'ru' ? "Редактировать профиль" : "Профильді өңдеу", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfilePage(initialName: widget.currentName, initialBin: widget.currentBin)));
                }),
                _buildDivider(isDark),
                _buildActionTile(LucideIcons.shieldCheck, Colors.teal, lang == 'ru' ? "Безопасность" : "Қауіпсіздік", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityPage()));
                }),
                _buildDivider(isDark),
                _buildLanguageTile(lang),
              ]),

              const SizedBox(height: 24),

              _buildGroupTitle(lang == 'ru' ? "Предпочтения" : "Қалаулар"),
              _buildCard(isDark, [
                _buildSwitchTile(Icons.dark_mode_outlined, Colors.orange, lang == 'ru' ? "Темная тема" : "Қараңғы режим", isDark, (val) => themeProvider.toggleTheme(val)),
                _buildDivider(isDark),
                _buildSwitchTile(LucideIcons.bell, Colors.indigo, lang == 'ru' ? "Уведомления" : "Хабарландырулар", _notificationsEnabled, (val) => setState(() => _notificationsEnabled = val)),
                _buildDivider(isDark),
                _buildSwitchTile(LucideIcons.fingerprint, Colors.green, lang == 'ru' ? "Биометрия" : "Биометрия", _biometricEnabled, (val) => setState(() => _biometricEnabled = val)),
              ]),

              const SizedBox(height: 24),

              _buildGroupTitle(lang == 'ru' ? "Поддержка" : "Қолдау"),
              _buildCard(isDark, [
                _buildActionTile(LucideIcons.helpCircle, Colors.purple, lang == 'ru' ? "Центр помощи" : "Көмек орталығы", () {}),
                _buildDivider(isDark),
                _buildActionTile(LucideIcons.messageCircle, Colors.greenAccent.shade700, lang == 'ru' ? "Написать в WhatsApp" : "WhatsApp-қа жазу", _contactSupport),
              ]),

              const SizedBox(height: 24),

              _buildGroupTitle(lang == 'ru' ? "Система" : "Жүйе"),
              _buildCard(isDark, [
                _buildActionTile(LucideIcons.trash2, Colors.redAccent, lang == 'ru' ? "Очистить кеш" : "Кешті тазалау", () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'ru' ? "Кеш очищен" : "Кеш тазаланды")));
                }),
                _buildDivider(isDark),
                ListTile(
                  leading: _buildIconBackground(LucideIcons.info, Colors.grey),
                  title: Text(lang == 'ru' ? "Версия" : "Нұсқа", style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Text("1.0.24", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ]),

              const SizedBox(height: 40),

              // Премиум-кнопка выхода
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _handleSignOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          lang == 'ru' ? "ВЫЙТИ ИЗ АККАУНТА" : "АККАУНТТАН ШЫҒУ",
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
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

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: Text(title.toUpperCase(), 
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, indent: 60, endIndent: 20, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200);
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

  Widget _buildActionTile(IconData icon, Color iconColor, String title, VoidCallback onTap) {
    return ListTile(
      leading: _buildIconBackground(icon, iconColor),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, Color iconColor, String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: _buildIconBackground(icon, iconColor),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueAccent,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildLanguageTile(String lang) {
    return ListTile(
      leading: _buildIconBackground(LucideIcons.languages, Colors.blue),
      title: Text(lang == 'ru' ? "Язык приложения" : "Қосымша тілі", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang == 'ru' ? "Русский" : "Қазақша", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Icon(LucideIcons.arrowRightLeft, size: 16, color: Colors.grey),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Профиль обновлен!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Редактирование", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPremiumTextField("Имя", LucideIcons.user, _nameController, isDark),
            const SizedBox(height: 20),
            _buildPremiumTextField("БИН/ИИН (12 цифр)", LucideIcons.creditCard, _binController, isDark, isNumber: true),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: Colors.blueAccent.withOpacity(0.5),
                ),
                onPressed: _isSaving ? null : _updateProfile,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("СОХРАНИТЬ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTextField(String label, IconData icon, TextEditingController controller, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: isNumber ? 12 : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
      ),
    );
  }
}

// --- СТРАНИЦА БЕЗОПАСНОСТИ ---
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Безопасность", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0, backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.mail, color: Colors.blueAccent)),
                  title: const Text("Сбросить пароль", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Отправим письмо для смены", style: TextStyle(fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
                  onTap: () async {
                    final email = Supabase.instance.client.auth.currentUser?.email;
                    if (email != null) {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Инструкции отправлены на email")));
                    }
                  },
                ),
                Divider(height: 1, indent: 70, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.userX, color: Colors.redAccent)),
                  title: const Text("Удалить аккаунт", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Данное действие необратимо", style: TextStyle(fontSize: 12)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                        title: const Text("Вы уверены?"),
                        content: const Text("Ваш профиль и все данные будут удалены."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена", style: TextStyle(color: Colors.grey))),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Удалить", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                        ],
                      ),
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