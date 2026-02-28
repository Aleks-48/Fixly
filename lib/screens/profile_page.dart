import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/settings/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userRoleLocal = "master"; // По умолчанию мастер
  String userName = "Загрузка...";
  String userBin = ""; 
  String orgName = ""; // Поле для названия ОСИ
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      try {
        // Запрашиваем данные профиля, включая org_name
        final data = await supabase
            .from('profiles')
            .select('role, user_type, name, first_name, last_name, avg_rating, bin, org_name, is_online') 
            .eq('id', user.id)
            .maybeSingle();
        
        if (mounted) {
          setState(() {
            final String rawRole = data?['role'] ?? data?['user_type'] ?? "master";
            userRoleLocal = rawRole.toString().toLowerCase();
            
            if (data?['first_name'] != null) {
              userName = "${data!['first_name']} ${data['last_name'] ?? ''}".trim();
            } else {
              userName = data?['name']?.toString() ?? user.email?.split('@')[0] ?? "User";
            }

            userBin = data?['bin']?.toString() ?? "";
            // Если org_name пустое, ставим заглушку
            orgName = data?['org_name']?.toString() ?? "";
            _isOnline = data?['is_online'] ?? true;
            
            userRating.value = (data?['avg_rating'] ?? 0.0).toDouble();
            userRole.value = userRoleLocal;
            
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Ошибка профиля: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Функция для редактирования названия ОСИ или БИН
  Future<void> _showEditDialog(String currentVal, bool isOsiName) async {
    final controller = TextEditingController(text: currentVal);
    final String title = isOsiName ? "Название ОСИ/ЖК" : "БИН / ИИН";

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text("Изменить $title", style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Введите новое значение",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue.withOpacity(0.5))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              final String column = isOsiName ? 'org_name' : 'bin';
              
              await supabase.from('profiles').update({column: controller.text}).eq('id', user!.id);
              
              if (mounted) {
                Navigator.pop(context);
                _loadUserData(); // Обновляем экран
              }
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOnlineStatus(bool val) async {
    setState(() => _isOnline = val);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_online': val})
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint("Ошибка обновления статуса: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgBlack = Color(0xFF0F0F10);
    const Color cardGrey = Color(0xFF1C1C1E);
    const Color accentBlue = Color(0xFF3B82F6);
    final user = Supabase.instance.client.auth.currentUser;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: bgBlack,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(lang == 'ru' ? "Мой Профиль" : "Профилім", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.settings, size: 22),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        currentName: userName,
                        currentBin: userBin,
                      ),
                    ),
                  );
                  _loadUserData(); 
                },
              )
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: accentBlue)) 
            : RefreshIndicator(
                onRefresh: _loadUserData,
                color: accentBlue,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildHeaderSection(user?.email, accentBlue, lang),
                      const SizedBox(height: 25),
                      _buildStatsHighlightCard(accentBlue, lang),
                      const SizedBox(height: 25),
                      _buildStatusCard(cardGrey, lang),
                      const SizedBox(height: 25),

                      // СЕКЦИЯ ДАННЫХ
                      _buildSectionLabel(userRoleLocal == 'osi' 
                          ? (lang == 'ru' ? "ИНФОРМАЦИЯ ОБ ОСИ" : "ОСИ ТУРАЛЫ АҚПАРАТ")
                          : (lang == 'ru' ? "ДАННЫЕ ОРГАНИЗАЦИИ" : "ҰЙЫМ ДЕРЕКТЕРІ")),
                      
                      _buildCardGroup(cardGrey, [
                        // Если ОСИ - показываем название ОСИ, если Мастер - БИН
                        if (userRoleLocal == 'osi')
                          _buildListTile(
                            LucideIcons.building, 
                            lang == 'ru' ? "Название ОСИ / ЖК" : "ОСИ / ТҮК атауы", 
                            orgName.isEmpty ? (lang == 'ru' ? "Нажмите для ввода" : "Енгізу үшін басыңыз") : orgName,
                            isEditable: true,
                            onTap: () => _showEditDialog(orgName, true),
                          )
                        else
                          _buildListTile(
                            LucideIcons.contact2, 
                            lang == 'ru' ? "БИН / ИИН" : "БСН / ЖСН", 
                            userBin.isEmpty ? (lang == 'ru' ? "Не указан" : "Көрсетілмеген") : userBin,
                            isEditable: true,
                            onTap: () => _showEditDialog(userBin, false),
                          ),

                        _buildListTile(LucideIcons.mapPin, lang == 'ru' ? "Адрес" : "Мекен-жай", "Казахстан, Алматы"),
                      ]),

                      const SizedBox(height: 25),

                      if (userRoleLocal == 'master')
                        _buildPortfolioBlock(lang, user?.id ?? "", cardGrey),

                      const SizedBox(height: 120), 
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  // --- UI КОМПОНЕНТЫ ---

  Widget _buildHeaderSection(String? email, Color accent, String lang) {
    bool isVerified = userBin.length == 12;
    bool isOsi = userRoleLocal == 'osi';
    String roleTitle = isOsi 
        ? (lang == 'ru' ? "Председатель ОСИ" : "ОСИ төрағасы")
        : (lang == 'ru' ? "Мастер" : "Шебер");
    Color roleColor = isOsi ? Colors.blueAccent : Colors.orange;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                border: Border.all(color: accent.withOpacity(0.4), width: 2)
              ),
              child: const CircleAvatar(
                radius: 55,
                backgroundColor: Color(0xFF2C2C2E),
                child: Icon(LucideIcons.user, size: 55, color: Colors.white24),
              ),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: isVerified ? Colors.green : Colors.orange,
              child: Icon(isVerified ? Icons.check : Icons.priority_high, size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(email ?? "", style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: roleColor.withOpacity(0.1),
            border: Border.all(color: roleColor.withOpacity(0.5)),
          ),
          child: Text(roleTitle, 
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildStatsHighlightCard(Color blue, String lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [blue, blue.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("${userRating.value}", lang == 'ru' ? "Рейтинг" : "Рейтинг", LucideIcons.star),
          _divider(),
          _statItem("14", lang == 'ru' ? "Заявки" : "Тапсырыс", LucideIcons.checkCircle),
          _divider(),
          _statItem("2 г.", lang == 'ru' ? "Опыт" : "Тәжірибе", LucideIcons.briefcase),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 8),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _divider() => Container(height: 30, width: 1, color: Colors.white24);

  Widget _buildStatusCard(Color cardColor, String lang) {
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(LucideIcons.zap, color: _isOnline ? Colors.green : Colors.grey, size: 20),
        title: Text(_isOnline 
            ? (lang == 'ru' ? "В СЕТИ" : "ЖЕЛІДЕ") 
            : (lang == 'ru' ? "ЗАНЯТ" : "БОС ЕМЕС"),
            style: TextStyle(color: _isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Switch(
          value: _isOnline,
          activeColor: Colors.green,
          onChanged: _toggleOnlineStatus,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildCardGroup(Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String sub, {bool isEditable = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.blueAccent, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: isEditable ? const Icon(LucideIcons.edit3, size: 14, color: Colors.white24) : null,
    );
  }

  Widget _buildPortfolioBlock(String lang, String userId, Color cardColor) {
    final supabase = Supabase.instance.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(lang == 'ru' ? "ВАШИ РАБОТЫ" : "ЖҰМЫСТАРЫҢЫЗ"),
        SizedBox(
          height: 160,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('portfolio').select('image_url').eq('master_id', userId).limit(10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(lang == 'ru' ? "Фото еще не добавлены" : "Фотолар жоқ", style: const TextStyle(color: Colors.grey, fontSize: 13))),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: NetworkImage(snapshot.data![index]['image_url']), 
                        fit: BoxFit.cover
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}