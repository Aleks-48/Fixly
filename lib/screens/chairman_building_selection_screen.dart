import 'package:fixly_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/building_search_screen.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:fixly_app/services/building_service.dart';
import 'package:fixly_app/utils/app_texts.dart';

// ============================================================
//  ChairmanBuildingSelectionScreen — выбор/создание дома для председателя
// ------------------------------------------------------------
//  ВАЖНО: старый osi_selection_screen.dart писал building_id ТОЛЬКО в
//  profiles. Но BuildingContextService.loadCurrent() сначала смотрит
//  таблицу building_members (verification_status in verified/approved)
//  и только потом — profiles.building_id как fallback. Из-за этого
//  председатель, выбравший дом через старый экран, не получал
//  canManageHouse=true: роль откатывалась на resident внутри
//  _guardUnverifiedManagerRole, и chairman_home_screen показывал
//  "Дом не выбран" даже после привязки.
//
//  Этот экран пишет запись первично в building_members (member_role:
//  'chairman', verification_status: 'verified') и дублирует building_id
//  в profiles для экранов, которые всё ещё читают его напрямую.
//
//  Отдельного flow модерации председателей (в отличие от мастеров,
//  для которых есть verification_screen.dart) в проекте пока нет,
//  поэтому председатель верифицируется сразу — и при создании нового
//  дома, и при присоединении к уже существующему.
// ============================================================
class ChairmanBuildingSelectionScreen extends StatefulWidget {
  const ChairmanBuildingSelectionScreen({super.key});

  @override
  State<ChairmanBuildingSelectionScreen> createState() =>
      _ChairmanBuildingSelectionScreenState();
}

class _ChairmanBuildingSelectionScreenState
    extends State<ChairmanBuildingSelectionScreen> {
  final _sb = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _currentMembership; // текущая привязка, если есть

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final membership = await BuildingService.getUserMembership(uid);
      if (mounted) {
        setState(() {
          _currentMembership = membership;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ChairmanBuildingSelection load: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ВЫБОР ДОМА (поиск/создание через BuildingSearchScreen) ─────────
  Future<void> _pickBuilding() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const BuildingSearchScreen()),
    );
    if (result == null) return;

    if (result['isNew'] == true) {
      await _createAndAttach(result);
    } else {
      final id = result['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _attach(id);
      }
    }
  }

  // ── СОЗДАТЬ НОВЫЙ ДОМ (адрес пришёл из OSM, в Fixly его ещё нет) ────
  Future<void> _createAndAttach(Map<String, dynamic> place) async {
    final osiNameCtrl = TextEditingController();
    final aptCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = appLanguage.value;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1B1F24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTexts.get('new_building', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place['address']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: osiNameCtrl,
              decoration: InputDecoration(
                labelText: AppTexts.get('osi_name', lang),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: aptCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppTexts.get('apartments_count', lang),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTexts.get('cancel', lang)),
          ),
          ElevatedButton(
style: ElevatedButton.styleFrom(backgroundColor: AppColors.of(ctx).primary),        
    onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTexts.get('create', lang),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final uid = _sb.auth.currentUser!.id;
      final lat = double.tryParse(place['lat']?.toString() ?? '');
      final lng = double.tryParse(place['lon']?.toString() ?? '');

      final building = await BuildingService.createBuilding(
        address: place['address']?.toString() ?? '',
        chairmanId: uid,
        osiName: osiNameCtrl.text.trim().isEmpty ? null : osiNameCtrl.text.trim(),
        totalApartments: int.tryParse(aptCtrl.text.trim()) ?? 0,
        lat: lat,
        lng: lng,
      );

      await _attach(building['id'].toString());
    } catch (e) {
      _showError('${AppTexts.get('creation_error', lang)}: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── ПРИВЯЗКА К ДОМУ: building_members (первично) + profiles (fallback) ─
  Future<void> _attach(String buildingId) async {
    setState(() => _isSaving = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await BuildingService.attachUserToBuilding(
        userId: uid,
        buildingId: buildingId,
        role: 'chairman',
        verificationStatus: 'verified',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppTexts.get('building_attached', appLanguage.value)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainWrapper()),
        (route) => false,
      );
    } catch (e) {
      _showError('${AppTexts.get('attachment_error', appLanguage.value)}: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => Scaffold(
        appBar: AppBar(
          title: Text(AppTexts.get('my_home', lang)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentMembership != null) ...[
                      _buildCurrentCard(isDark, lang),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      AppTexts.get('search_or_create_home', lang),
                      style: const TextStyle(color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _pickBuilding,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(LucideIcons.search, color: Colors.white),
                        label: Text(
                          _currentMembership != null
                              ? AppTexts.get('change_home', lang)
                              : AppTexts.get('select_or_create_home', lang),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.of(context).primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentCard(bool isDark, String lang) {
    final buildings = (_currentMembership?['buildings'] as Map?) ?? {};
    final address = buildings['address']?.toString() ?? '';
    final osiName = buildings['osi_name']?.toString() ?? '';
    final status = _currentMembership?['verification_status']?.toString() ?? 'pending';
    final isVerified = status == 'verified' || status == 'approved';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isVerified ? Colors.green : Colors.orange).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.building2, color: isVerified ? Colors.green : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  osiName.isNotEmpty ? osiName : AppTexts.get('current_home', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (address.isNotEmpty)
                  Text(address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  isVerified
                      ? AppTexts.get('verified', lang)
                      : AppTexts.get('pending_verification', lang),
                  style: TextStyle(
                    color: isVerified ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
