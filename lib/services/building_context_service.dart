import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FixlyRole {
  resident,
  chairman,
  manager,
  master,
  admin,
}

class BuildingContext {
  const BuildingContext({
    required this.userId,
    required this.role,
    required this.profile,
    this.buildingId,
    this.buildingAddress,
    this.osiName,
    this.totalApartments = 0,
    this.apartmentId,
    this.apartmentNumber,
    this.verificationStatus = 'unverified',
  });

  final String userId;
  final FixlyRole role;
  final Map<String, dynamic> profile;
  final String? buildingId;
  final String? buildingAddress;
  final String? osiName;
  final int totalApartments;
  final String? apartmentId;
  final String? apartmentNumber;
  final String verificationStatus;

  bool get hasBuilding => buildingId != null && buildingId!.isNotEmpty;
  bool get isVerifiedMember =>
      verificationStatus == 'verified' || verificationStatus == 'approved';
  bool get canManageHouse =>
      role == FixlyRole.admin ||
      isVerifiedMember &&
          (role == FixlyRole.chairman || role == FixlyRole.manager);

  String get roleKey => role.name;
}

class BuildingContextService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static String normalizeRoleKey(String? rawRole, [String? rawUserType]) {
    final role = (rawRole ?? rawUserType ?? '').toLowerCase().trim();
    if (role == 'osi' || role == 'chairman') return 'chairman';
    if (role == 'manager' || role == 'uk') return 'manager';
    if (role == 'admin') return 'admin';
    if (role == 'master' || role == 'contractor') return 'master';
    return 'resident';
  }

  static FixlyRole normalizeRole(String? rawRole, [String? rawUserType]) {
    switch (normalizeRoleKey(rawRole, rawUserType)) {
      case 'chairman':
        return FixlyRole.chairman;
      case 'manager':
        return FixlyRole.manager;
      case 'admin':
        return FixlyRole.admin;
      case 'master':
        return FixlyRole.master;
      default:
        return FixlyRole.resident;
    }
  }

  static Future<BuildingContext?> loadCurrent() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;

    final profile = await _loadProfile(user.id);
    if (profile == null) return null;

    final membership = await _loadVerifiedMembership(user.id);
    final rawRole = membership?['member_role']?.toString() ??
        profile['role']?.toString() ??
        profile['user_type']?.toString();
    final rawStatus = membership?['verification_status']?.toString() ??
        profile['chairman_verification_status']?.toString() ??
        profile['verification_status']?.toString() ??
        'unverified';

    final normalizedRole =
        normalizeRole(rawRole, profile['user_type']?.toString());
    final role = _guardUnverifiedManagerRole(normalizedRole, rawStatus);
    final buildingId = membership?['building_id']?.toString() ??
        profile['building_id']?.toString();
    final building = await _loadBuilding(buildingId);

    return BuildingContext(
      userId: user.id,
      role: role,
      profile: profile,
      buildingId: buildingId,
      buildingAddress: building?['address']?.toString(),
      osiName:
          building?['osi_name']?.toString() ?? profile['org_name']?.toString(),
      totalApartments: _toInt(building?['total_apartments']),
      apartmentId: membership?['apartment_id']?.toString(),
      apartmentNumber: membership?['apartment_number']?.toString() ??
          profile['apartment_number']?.toString() ??
          profile['apartment']?.toString(),
      verificationStatus: rawStatus,
    );
  }

  static Future<String?> currentBuildingId() async {
    final context = await loadCurrent();
    return context?.buildingId;
  }

  static Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    try {
      return await _sb.from('profiles').select().eq('id', userId).maybeSingle();
    } catch (e) {
      debugPrint('BuildingContextService profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadVerifiedMembership(
      String userId) async {
    try {
      return await _sb
          .from('building_members')
          .select()
          .eq('user_id', userId)
          .inFilter(
              'verification_status', ['verified', 'approved']).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadBuilding(String? buildingId) async {
    if (buildingId == null || buildingId.isEmpty) return null;
    try {
      return await _sb
          .from('buildings')
          .select('id, address, osi_name, total_apartments')
          .eq('id', buildingId)
          .maybeSingle();
    } catch (e) {
      debugPrint('BuildingContextService building: $e');
      return null;
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static FixlyRole _guardUnverifiedManagerRole(
    FixlyRole role,
    String status,
  ) {
    if (role == FixlyRole.admin) return role;
    final isManagerRole =
        role == FixlyRole.chairman || role == FixlyRole.manager;
    final isVerified = status == 'verified' || status == 'approved';
    if (isManagerRole && !isVerified) return FixlyRole.resident;
    return role;
  }
}
