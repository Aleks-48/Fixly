// lib/screens/profile_page.dart

import 'package:fixly_app/screens/orders_page.dart';
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
import 'package:fixly_app/theme/app_theme.dart'; // Импорт нашей единой дизайн-системы

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
    final lang = appLanguage.value;
    final c = AppColors.of(context); // Инициализация темы

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTexts.get('edit_field', lang).replaceAll('{field}', title),
          style: TextStyle(color: c.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: AppTexts.get('enter_field', lang).replaceAll('{field}', title),
            hintStyle: TextStyle(color: c.textTertiary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.primary.withOpacity(0.5)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppTexts.get('cancel', lang),
              style: TextStyle(color: c.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary, // Фирменный зеленый
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Скругление по стандарту AppDimens.radiusSm
              ),
            ),
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
                      backgroundColor: c.success,
                    ),
                  );
                }
              } catch (e) {
                debugPrint("Ошибка обновления: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${AppTexts.get('save_error', lang)}: $e"),
                      backgroundColor: c.danger,
                    ),
                  );
                }
              }
            },
            child: Text(
              AppTexts.get('save', lang),
              style: const TextStyle(color: Colors.white),
            ),
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
      final c = AppColors.of(context);
      if (mounted && url != null) {
        setState(() => userAvatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppTexts.get('photo_updated', lang)),
              backgroundColor: c.success),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppTexts.get('photo_error', lang)),
              backgroundColor: c.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        final c = AppColors.of(context); // Читаем тему дизайн-системы

        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: Text(
              AppTexts.get('my_profile', lang),
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
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
              ? Center(
                  child: CircularProgressIndicator(color: c.primary))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: c.primary,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildHeaderSection(context, lang),

                        if (userRoleLocal == 'master') ...[
                          const SizedBox(height: 25),
                          _buildStatsHighlightCard(context, lang),
                        ],

                        const SizedBox(height: 25),
                        _buildStatusCard(context, lang),
                        const SizedBox(height: 25),

                        _buildSectionLabel(
                            (userRoleLocal == 'osi' ||
                                    userRoleLocal == 'chairman' ||
                                    userRoleLocal == 'resident')
                                ? AppTexts.get('address_data', lang)
                                : AppTexts.get('profile_data', lang),
                            c.isDark),

                        _buildCardGroup(c.card, c.isDark, [
                          _buildListTile(
                            context,
                            LucideIcons.mapPin,
                            AppTexts.get('select_home_map', lang),
                            AppTexts.get('confirm_home', lang),
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
                              context,
                              LucideIcons.building,
                              AppTexts.get('osi_jk_name', lang),
                              orgName.isEmpty
                                  ? AppTexts.get('tap_to_enter', lang)
                                  : orgName,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(
                                  orgName, AppTexts.get('osi_jk_name', lang), 'org_name'),
                            ),

                          if (userRoleLocal == 'master')
                            _buildListTile(
                              context,
                              LucideIcons.contact2,
                              AppTexts.get('bin_iin', lang),
                              userBin.isEmpty
                                  ? AppTexts.get('not_specified', lang)
                                  : userBin,
                              isEditable: true,
                              onTap: () => _showEditFieldDialog(
                                  userBin, AppTexts.get('bin_iin', lang), 'bin'),
                            ),

                          if (userRoleLocal == 'master')
                            _buildListTile(
                              context,
                              LucideIcons.shieldCheck,
                              AppTexts.get('verification', lang),
                              AppTexts.get('confirm_profile', lang),
                              isEditable: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const VerificationScreen()),
                              ),
                            ),

                          _buildListTile(
                            context,
                            LucideIcons.map,
                            AppTexts.get('city', lang),
                            userCity.isEmpty ? AppTexts.get('not_specified', lang) : userCity,
                            isEditable: true,
                            onTap: () =>
                                _showEditFieldDialog(userCity, AppTexts.get('city', lang), 'city'),
                          ),

                          _buildListTile(
                            context,
                            LucideIcons.mapPin,
                            AppTexts.get('street_house', lang),
                            "${userStreet.isEmpty ? '...' : userStreet}, ${userHouse.isEmpty ? '...' : userHouse}",
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
                            context,
                            LucideIcons.home,
                            AppTexts.get('apartment', lang),
                            userApartment.isEmpty
                                ? AppTexts.get('not_specified', lang)
                                : "${AppTexts.get('apartment', lang)} $userApartment",
                            isEditable: true,
                            onTap: () => _showEditFieldDialog(
                                userApartment, AppTexts.get('apartment', lang), 'apartment'),
                          ),
                        ]),

                        const SizedBox(height: 25),

                        if (userRoleLocal == 'master')
                          _buildPortfolioBlock(
                              context,
                              lang,
                              Supabase.instance.client.auth.currentUser?.id ?? ""),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context, String lang) {
    final c = AppColors.of(context);
    bool isVerified = userBin.length == 12 || orgName.isNotEmpty;

    String roleTitle = "";
    Color roleColor = c.warning;

    if (userRoleLocal == 'osi' || userRoleLocal == 'chairman') {
      roleTitle = AppTexts.get('role_chairman', lang);
      roleColor = c.primary; 
    } else if (userRoleLocal == 'resident') {
      roleTitle = AppTexts.get('role_resident', lang);
      roleColor = c.success; 
    } else {
      roleTitle = AppTexts.get('role_master', lang);
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
                  border: Border.all(color: c.primary.withOpacity(0.4), width: 2)),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: c.surfaceVariant,
                backgroundImage: userAvatarUrl.isNotEmpty
                    ? NetworkImage(userAvatarUrl)
                    : null,
                child: userAvatarUrl.isEmpty
                    ? Icon(LucideIcons.user,
                        size: 55,
                        color: c.textTertiary)
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(right: 60),
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c.background,
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
              backgroundColor: isVerified ? c.success : c.warning,
              child: Icon(isVerified ? Icons.check : Icons.priority_high,
                  size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(userName,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: c.textPrimary)),
        const SizedBox(height: 12),
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

  Widget _buildStatsHighlightCard(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, c.primary.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: c.shadow,
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

  Widget _buildStatusCard(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
          color: c.card, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(LucideIcons.zap,
            color: _isOnline ? c.success : c.textTertiary, size: 20),
        title: Text(
            _isOnline
                ? AppTexts.get('online', lang)
                : AppTexts.get('busy', lang),
            style: TextStyle(
                color: _isOnline ? c.success : c.textTertiary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        trailing: Switch(
          value: _isOnline,
          activeColor: c.success,
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

  Widget _buildListTile(BuildContext context, IconData icon, String title, String sub,
      {bool isEditable = false, VoidCallback? onTap}) {
    final c = AppColors.of(context); 
    
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: c.isDark 
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12)), 
        child: Icon(icon, color: c.primary, size: 18), 
      ),
      title: Text(title,
          style: TextStyle(
              color: c.isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
      subtitle: Text(sub,
          style: TextStyle(
              color: c.isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      trailing: isEditable
          ? Icon(LucideIcons.edit3,
              size: 14, color: c.isDark ? Colors.white24 : Colors.black26)
          : null,
    );
  }

  Widget _buildPortfolioBlock(
      BuildContext context, String lang, String userId) {
    final c = AppColors.of(context);
    final supabase = Supabase.instance.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel(
                AppTexts.get('your_works', lang), c.isDark),
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PortfolioScreen()),
                );
                if (mounted) setState(() {}); 
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
                      color: c.card,
                      borderRadius: BorderRadius.circular(20)),
                  child: Center(
                      child: Text(
                          AppTexts.get('no_photos', lang),
                          style: TextStyle(
                              color: c.isDark ? Colors.grey : Colors.grey[600],
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