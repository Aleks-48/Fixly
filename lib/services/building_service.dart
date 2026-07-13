import 'package:supabase_flutter/supabase_flutter.dart';

class BuildingService {
  static final _sb = Supabase.instance.client;

  // 1. Получить текущую привязку пользователя к дому
  static Future<Map<String, dynamic>?> getUserMembership(String userId) async {
    try {
      return await _sb
          .from('building_members')
          .select('building_id, verification_status, buildings(address, osi_name)')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // 2. Создать новый дом в базе данных
  static Future<Map<String, dynamic>> createBuilding({
    required String address,
    required String chairmanId,
    String? osiName,
    int totalApartments = 0,
    double? lat,
    double? lng,
  }) async {
    final row = await _sb.from('buildings').insert({
      'address': address,
      'chairman_id': chairmanId, // Обязательное поле по схеме БД
      'osi_name': osiName,
      'total_apartments': totalApartments,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    
    return Map<String, dynamic>.from(row);
  }

  // 3. Привязать пользователя к дому (с удалением старых привязок)
  static Future<void> attachUserToBuilding({
    required String userId,
    required String buildingId,
    required String role,
    String verificationStatus = 'pending',
  }) async {
    // Удаляем предыдущие роли, чтобы осталась только одна активная
    await _sb.from('building_members').delete().eq('user_id', userId);

    // Вставляем новую запись в building_members
    await _sb.from('building_members').insert({
      'user_id': userId,
      'building_id': buildingId,
      'member_role': role,
      'verification_status': verificationStatus,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Обновляем профиль пользователя
    final profileRole = role == 'chairman' ? 'osi' : role;
    await _sb.from('profiles').update({
      'building_id': buildingId,
      'role': profileRole,
    }).eq('id', userId);
  }

  // 4. Получить детали дома по ID
  static Future<Map<String, dynamic>?> getBuildingDetails(String buildingId) async {
    if (buildingId.isEmpty) return null;
    try {
      return await _sb
          .from('buildings')
          .select('id, address, osi_name, total_apartments')
          .eq('id', buildingId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
