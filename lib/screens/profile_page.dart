import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/settings/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userRoleLocal = "master";
  String userName = "Загрузка...";
  String userBin = "";
  String orgName = "";
  // Поля адреса
  String userCity = "";
  String userStreet = "";
  String userHouse = "";
  String userApartment = "";

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
        final data = await supabase
            .from('profiles')
            .select('role, user_type, name, first_name, last_name, avg_rating, bin, org_name, is_online, city, street, house, apartment')
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
            orgName = data?['org_name']?.toString() ?? "";
            userCity = data?['city']?.toString() ?? "";
            userStreet = data?['street']?.toString() ?? "";
            userHouse = data?['house']?.toString() ?? "";
            userApartment = data?['apartment']?.toString() ?? "";

            _isOnline = data?['is_online'] ?? true;

            userRating.value = (data?['avg_rating'] ?? 0.0).toDouble();
            userRole.value = userRoleLocal;

            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Ошибка загрузки профиля: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditFieldDialog(String currentVal, String title, String dbColumn) async {
    final controller = TextEditingController(text: currentVal);
    final c = AppColors.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Изменить $title",
          style: TextStyle(color: c.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: "Введите $title",
            hintStyle: TextStyle(color: c.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.primary.withOpacity(0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Отмена", style: TextStyle(color: c.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              try {
                await supabase.from('profiles').update({dbColumn: controller.text}).eq('id', user!.id);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text("Данные обновлены"), backgroundColor: c.success),
                  );
                }
              } catch (e) {
                debugPrint("Ошибка обновления: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Ошибка сохранения: $e"), backgroundColor: c.danger),
                  );
                }
              }
            },
            child: const Text("Сохранить", style: TextStyle(color: Colors.white)),
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
      debugPrint("Ошибка статуса: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: Text(
              lang == 'ru' ? "Мой Профиль" : "Профилім",
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(LucideIcons.settings, size: 22, color: c.textPrimary),
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
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: c.primary,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildHeaderSection(c, lang),

                        if (userRoleLocal == 'master') ...[
                          const SizedBox(height: 25),
                          _buildStatsHighlightCard(c, lang),
                        ],

                        const SizedBox(height: 25),
                        _buildStatusCard(c, lang),
                        const SizedBox(height: 25),

                        _buildSectionLabel(
                          c,
                          (userRoleLocal == 'osi' || userRoleLocal == 'chairman' || userRoleLocal == 'resident')
                              ? (lang == 'ru' ? "АДРЕСНЫЕ ДАННЫЕ" : "МЕКЕН-ЖАЙ МӘЛІМЕТТЕРІ")
                              : (lang == 'ru' ? "ДАННЫЕ ПРОФИЛЯ" : "ПРОФИЛЬ ДЕРЕКТЕРІ"),
                        ),

                        _buildCardGroup(c, [
                          if (userRoleLocal == 'osi' || userRoleLocal == 'chairman' || userRoleLocal == 'resident')
                            _buildListTile(
                              c,
                              LucideIcons.building,
                              lang == 'ru' ? "Название ОСИ / ЖК" : "ОСИ / ТҮК атауы",
                              orgName.isEmpty ? (lang == 'ru' ? "Нажмите для ввода" : "Енгізу үшін басыңыз") : orgName,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(orgName, "ОСИ / ЖК", 'org_name'),
                            ),

                          if (userRoleLocal == 'master')
                            _buildListTile(
                              c,
                              LucideIcons.contact2,
                              lang == 'ru' ? "БИН / ИИН" : "БСН / ЖСН",
                              userBin.isEmpty ? (lang == 'ru' ? "Не указан" : "Көрсетілмеген") : userBin,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(userBin, "БИН / ИИН", 'bin'),
                            ),

                          _buildListTile(
                            c,
                            LucideIcons.map,
                            lang == 'ru' ? "Город" : "Қала",
                            userCity.isEmpty ? "Не указан" : userCity,
                            isEditable: true,
                            onTap: () => _showEditFieldDialog(userCity, "Город", 'city'),
                          ),

                          _buildListTile(
                            c,
                            LucideIcons.mapPin,
                            lang == 'ru' ? "Улица и дом" : "Көше мен үй",
                            "${userStreet.isEmpty ? '...' : userStreet}, ${userHouse.isEmpty ? '...' : userHouse}",
                            isEditable: true,
                            onTap: () async {
                              await _showEditFieldDialog(userStreet, "Улицу", 'street');
                              if (mounted) await _showEditFieldDialog(userHouse, "Дом", 'house');
                            },
                          ),

                          _buildListTile(
                            c,
                            LucideIcons.home,
                            lang == 'ru' ? "Квартира" : "Пәтер",
                            userApartment.isEmpty ? "Не указано" : "Кв. $userApartment",
                            isEditable: true,
                            onTap: () => _showEditFieldDialog(userApartment, "Квартиру", 'apartment'),
                          ),
                        ]),

                        const SizedBox(height: 25),

                        if (userRoleLocal == 'master')
                          _buildPortfolioBlock(c, lang, Supabase.instance.client.auth.currentUser?.id ?? ""),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // Заголовок: имя и роль
  Widget _buildHeaderSection(AppColors c, String lang) {
    bool isVerified = userBin.length == 12 || orgName.isNotEmpty;

    String roleTitle = "";
    Color roleColor = c.warning;

    if (userRoleLocal == 'osi' || userRoleLocal == 'chairman') {
      roleTitle = lang == 'ru' ? "Председатель ОСИ" : "ОСИ төрағасы";
      roleColor = c.primary;
    } else if (userRoleLocal == 'resident') {
      roleTitle = lang == 'ru' ? "Житель" : "Тұрғын";
      roleColor = c.success;
    } else {
      roleTitle = lang == 'ru' ? "Мастер" : "Шебер";
      roleColor = c.warning;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.primary.withOpacity(0.4), width: 2),
              ),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: c.surfaceVariant,
                child: Icon(LucideIcons.user, size: 55, color: c.textTertiary),
              ),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: isVerified ? c.success : c.warning,
              child: Icon(isVerified ? Icons.check : Icons.priority_high, size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          userName,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: roleColor.withOpacity(0.1),
            border: Border.all(color: roleColor.withOpacity(0.5)),
          ),
          child: Text(roleTitle,
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStatsHighlightCard(AppColors c, String lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: c.gradientStart.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
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

  Widget _buildStatusCard(AppColors c, String lang) {
    return AppCard(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(LucideIcons.zap, color: _isOnline ? c.success : c.textTertiary, size: 20),
        title: Text(
          _isOnline
              ? (lang == 'ru' ? "В СЕТИ" : "ЖЕЛІДЕ")
              : (lang == 'ru' ? "ЗАНЯТ" : "БОС ЕМЕС"),
          style: TextStyle(color: _isOnline ? c.success : c.textTertiary, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        trailing: Switch(
          value: _isOnline,
          activeColor: c.success,
          onChanged: _toggleOnlineStatus,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(AppColors c, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            color: c.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildCardGroup(AppColors c, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(AppColors c, IconData icon, String title, String sub,
      {bool isEditable = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: c.primary, size: 18),
      ),
      title: Text(title, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      subtitle: Text(sub, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: isEditable ? Icon(LucideIcons.edit3, size: 14, color: c.textTertiary) : null,
    );
  }

  Widget _buildPortfolioBlock(AppColors c, String lang, String userId) {
    final supabase = Supabase.instance.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(c, lang == 'ru' ? "ВАШИ РАБОТЫ" : "ЖҰМЫСТАРЫҢЫЗ"),
        SizedBox(
          height: 160,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('portfolio').select('image_url').eq('master_id', userId).limit(10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: c.primary));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20)),
                  child: Center(
                    child: Text(
                      lang == 'ru' ? "Фото еще не добавлены" : "Фотолар жоқ",
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ),
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
                        fit: BoxFit.cover,
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