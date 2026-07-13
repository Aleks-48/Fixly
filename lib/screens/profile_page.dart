import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/settings/settings_page.dart';
import 'package:fixly_app/screens/portfolio_screen.dart';
import 'package:fixly_app/screens/verification_screen.dart';
import 'package:fixly_app/screens/osi_selection_screen.dart';
import 'package:fixly_app/services/profile_service.dart';
import 'package:fixly_app/utils/app_texts.dart';

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
  String userAvatarUrl = "";
  bool _isUploadingAvatar = false;

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
            .select(
                'role, user_type, name, first_name, last_name, avg_rating, bin, org_name, is_online, city, street, house, apartment, avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            final String rawRole =
                data?['role'] ?? data?['user_type'] ?? "master";
            userRoleLocal = rawRole.toString().toLowerCase();

            if (data?['first_name'] != null) {
              userName =
                  "${data!['first_name']} ${data['last_name'] ?? ''}".trim();
            } else {
              userName = data?['name']?.toString() ??
                  user.email?.split('@')[0] ??
                  "User";
            }

            userBin = data?['bin']?.toString() ?? "";
            orgName = data?['org_name']?.toString() ?? "";
            userCity = data?['city']?.toString() ?? "";
            userStreet = data?['street']?.toString() ?? "";
            userHouse = data?['house']?.toString() ?? "";
            userApartment = data?['apartment']?.toString() ?? "";
            userAvatarUrl = data?['avatar_url']?.toString() ?? "";

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

  Future<void> _showEditFieldDialog(
      String currentVal, String title, String dbColumn) async {
    final controller = TextEditingController(text: currentVal);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = appLanguage.value;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTexts.get('edit_field', lang).replaceAll('{field}', title),
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: AppTexts.get('enter_field', lang).replaceAll('{field}', title),
            hintStyle:
                TextStyle(color: isDark ? Colors.white24 : Colors.black38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.withOpacity(0.5))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text(AppTexts.get('cancel', lang), style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              try {
                await supabase
                    .from('profiles')
                    .update({dbColumn: controller.text}).eq('id', user!.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppTexts.get('data_updated', lang)),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                debugPrint("Ошибка обновления: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("${AppTexts.get('save_error', lang)}: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child:
                Text(AppTexts.get('save', lang), style: const TextStyle(color: Colors.white)),
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
            .update({'is_online': val}).eq('id', user.id);
      }
    } catch (e) {
      debugPrint("Ошибка статуса: $e");
    }
  }

  // ВАЖНО: раньше ProfileService.uploadAvatar() был полностью реализован
  // (загрузка в Storage + обновление profiles.avatar_url), но нигде в
  // UI не было кнопки, которая бы его вызывала — аватар всегда
  // отображался как иконка-заглушка.
  Future<void> _pickAndUploadAvatar() async {
    final xf = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (xf == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await ProfileService.uploadAvatar(File(xf.path));
      final lang = appLanguage.value;
      if (mounted && url != null) {
        setState(() => userAvatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppTexts.get('photo_updated', lang)),
              backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppTexts.get('photo_error', lang)),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7);
    final Color cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    const Color accentBlue = Color(0xFF3B82F6);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(AppTexts.get('my_profile', lang),
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(LucideIcons.settings, size: 22, color: textColor),
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
              ? const Center(
                  child: CircularProgressIndicator(color: accentBlue))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: accentBlue,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Вызываем заголовок БЕЗ почты
                        _buildHeaderSection(accentBlue, lang, isDark),

                        if (userRoleLocal == 'master') ...[
                          const SizedBox(height: 25),
                          _buildStatsHighlightCard(accentBlue, lang),
                        ],

                        const SizedBox(height: 25),
                        _buildStatusCard(cardColor, lang, isDark),
                        const SizedBox(height: 25),

                        _buildSectionLabel(
                            (userRoleLocal == 'osi' ||
                                    userRoleLocal == 'chairman' ||
                                    userRoleLocal == 'resident')
                                ? AppTexts.get('address_data', lang)
                                : AppTexts.get('profile_data', lang),
                            isDark),

                        _buildCardGroup(cardColor, isDark, [
                          _buildListTile(
                            LucideIcons.mapPin,
                            AppTexts.get('select_home_map', lang),
                            AppTexts.get('confirm_home', lang),
                            isDark: isDark,
                            isEditable: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OsiSelectionScreen(),
                              ),
                            ),
                          ),
                          if (userRoleLocal == 'osi' ||
                              userRoleLocal == 'chairman' ||
                              userRoleLocal == 'resident')
                            _buildListTile(
                              LucideIcons.building,
                              AppTexts.get('osi_jk_name', lang),
                              orgName.isEmpty
                                  ? AppTexts.get('tap_to_enter', lang)
                                  : orgName,
                              isDark: isDark,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(
                                  orgName, AppTexts.get('osi_jk_name', lang), 'org_name'),
                            ),

                          if (userRoleLocal == 'master')
                            _buildListTile(
                              LucideIcons.contact2,
                              AppTexts.get('bin_iin', lang),
                              userBin.isEmpty
                                  ? AppTexts.get('not_specified', lang)
                                  : userBin,
                              isDark: isDark,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(
                                  userBin, AppTexts.get('bin_iin', lang), 'bin'),
                            ),

                          // ВАЖНО: раньше verification_screen.dart (загрузка
                          // документов, статус проверки) существовал, но
                          // никуда не был подключён — мастер физически не
                          // мог попасть на верификацию.
                          if (userRoleLocal == 'master')
                            _buildListTile(
                              LucideIcons.shieldCheck,
                              AppTexts.get('verification', lang),
                              AppTexts.get('confirm_profile', lang),
                              isDark: isDark,
                              isEditable: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const VerificationScreen()),
                              ),
                            ),

                          _buildListTile(
                            LucideIcons.map,
                            AppTexts.get('city', lang),
                            userCity.isEmpty ? AppTexts.get('not_specified', lang) : userCity,
                            isDark: isDark,
                            isEditable: true,
                            onTap: () =>
                                _showEditFieldDialog(userCity, AppTexts.get('city', lang), 'city'),
                          ),

                          _buildListTile(
                            LucideIcons.mapPin,
                            AppTexts.get('street_house', lang),
                            "${userStreet.isEmpty ? '...' : userStreet}, ${userHouse.isEmpty ? '...' : userHouse}",
                            isDark: isDark,
                            isEditable: true,
                            onTap: () async {
                              await _showEditFieldDialog(
                                  userStreet, AppTexts.get('street_house', lang), 'street');
                              if (mounted)
                                await _showEditFieldDialog(
                                    userHouse, AppTexts.get('street_house', lang), 'house');
                            },
                          ),

                          _buildListTile(
                            LucideIcons.home,
                            AppTexts.get('apartment', lang),
                            userApartment.isEmpty
                                ? AppTexts.get('not_specified', lang)
                                : "${AppTexts.get('apartment', lang)} $userApartment",
                            isDark: isDark,
                            isEditable: true,
                            onTap: () => _showEditFieldDialog(
                                userApartment, AppTexts.get('apartment', lang), 'apartment'),
                          ),
                        ]),

                        const SizedBox(height: 25),

                        if (userRoleLocal == 'master')
                          _buildPortfolioBlock(
                              lang,
                              Supabase.instance.client.auth.currentUser?.id ??
                                  "",
                              cardColor,
                              isDark),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // Обновленный заголовок: Чисто Имя и Роль
  Widget _buildHeaderSection(Color accent, String lang, bool isDark) {
    bool isVerified = userBin.length == 12 || orgName.isNotEmpty;

    String roleTitle = "";
    Color roleColor = Colors.orange;

    if (userRoleLocal == 'osi' || userRoleLocal == 'chairman') {
      roleTitle = AppTexts.get('role_chairman', lang);
      roleColor = Colors.blueAccent;
    } else if (userRoleLocal == 'resident') {
      roleTitle = AppTexts.get('role_resident', lang);
      roleColor = Colors.green;
    } else {
      roleTitle = AppTexts.get('role_master', lang);
      roleColor = Colors.orange;
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
                  border: Border.all(color: accent.withOpacity(0.4), width: 2)),
              child: CircleAvatar(
                radius: 55,
                backgroundColor:
                    isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                backgroundImage: userAvatarUrl.isNotEmpty
                    ? NetworkImage(userAvatarUrl)
                    : null,
                child: userAvatarUrl.isEmpty
                    ? Icon(LucideIcons.user,
                        size: 55,
                        color: isDark ? Colors.white24 : Colors.black26)
                    : null,
              ),
            ),
            // Кнопка смены фото — раньше не существовала, аватар был
            // навсегда заглушкой.
            GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(right: 60),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isDark ? const Color(0xFF0F0F10) : Colors.white,
                      width: 2),
                ),
                child: _isUploadingAvatar
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.camera,
                        size: 14, color: Colors.white),
              ),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: isVerified ? Colors.green : Colors.orange,
              child: Icon(isVerified ? Icons.check : Icons.priority_high,
                  size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Только имя пользователя
        Text(userName,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        // Только роль в плашке
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: roleColor.withOpacity(0.1),
            border: Border.all(color: roleColor.withOpacity(0.5)),
          ),
          child: Text(roleTitle,
              style: TextStyle(
                  color: roleColor, fontWeight: FontWeight.bold, fontSize: 13)),
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
        boxShadow: [
          BoxShadow(
              color: blue.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("${userRating.value}", AppTexts.get('rating', lang),
              LucideIcons.star),
          _divider(),
          _statItem("14", AppTexts.get('orders_count', lang),
              LucideIcons.checkCircle),
          _divider(),
          _statItem("2 г.", AppTexts.get('experience', lang),
              LucideIcons.briefcase),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 8),
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _divider() => Container(height: 30, width: 1, color: Colors.white24);

  Widget _buildStatusCard(Color cardColor, String lang, bool isDark) {
    return Container(
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(LucideIcons.zap,
            color: _isOnline ? Colors.green : Colors.grey, size: 20),
        title: Text(
            _isOnline
                ? AppTexts.get('online', lang)
                : AppTexts.get('busy', lang),
            style: TextStyle(
                color: _isOnline ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        trailing: Switch(
          value: _isOnline,
          activeColor: Colors.green,
          onChanged: _toggleOnlineStatus,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildCardGroup(Color color, bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, String sub,
      {required bool isDark, bool isEditable = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.blueAccent, size: 18),
      ),
      title: Text(title,
          style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
      subtitle: Text(sub,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      trailing: isEditable
          ? Icon(LucideIcons.edit3,
              size: 14, color: isDark ? Colors.white24 : Colors.black26)
          : null,
    );
  }

  Widget _buildPortfolioBlock(
      String lang, String userId, Color cardColor, bool isDark) {
    final supabase = Supabase.instance.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel(
                AppTexts.get('your_works', lang), isDark),
            // ВАЖНО: раньше здесь не было способа добавить работу —
            // portfolio_screen.dart (загрузка фото, описание, удаление)
            // существовал в проекте, но никуда не был подключён.
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PortfolioScreen()),
                );
                if (mounted) setState(() {}); // обновить превью после возврата
              },
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(AppTexts.get('add', lang)),
            ),
          ],
        ),
        SizedBox(
          height: 160,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('portfolio')
                .select('image_url')
                .eq('master_id', userId)
                .limit(10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Center(
                      child: Text(
                          AppTexts.get('no_photos', lang),
                          style: TextStyle(
                              color: isDark ? Colors.grey : Colors.grey[600],
                              fontSize: 13))),
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
                          image:
                              NetworkImage(snapshot.data![index]['image_url']),
                          fit: BoxFit.cover),
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
