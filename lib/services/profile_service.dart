// lib/services/profile_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/models/user_model.dart';

// ============================================================
//  ProfileService — централизованная работа с профилями
//  Методы: get, update, uploadAvatar, updateSpecialty,
//          setAvailability, getById, searchMasters
// ============================================================
class ProfileService {
  static final _sb = Supabase.instance.client;

  // ── ПОЛУЧИТЬ ТЕКУЩИЙ ПРОФИЛЬ ──────────────────────────────
  static Future<UserModel?> getCurrentProfile() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    return getById(uid);
  }

  // ── ПОЛУЧИТЬ ПРОФИЛЬ ПО ID ────────────────────────────────
  static Future<UserModel?> getById(String userId) async {
    try {
      final data = await _sb
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data != null ? UserModel.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  // ── ОБНОВИТЬ ОСНОВНЫЕ ДАННЫЕ ──────────────────────────────
  static Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? description,
    int?    experienceYears,
    double? priceFrom,
    int?    apartmentNumber,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName        != null) updates['full_name']         = fullName;
      if (phone           != null) updates['phone']             = phone;
      if (description     != null) updates['description']       = description;
      if (experienceYears != null) updates['experience_years']  = experienceYears;
      if (priceFrom       != null) updates['price_from']        = priceFrom;
      if (apartmentNumber != null) updates['apartment_number']  = apartmentNumber;

      await _sb.from('profiles').update(updates).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── ЗАГРУЗИТЬ АВАТАР ──────────────────────────────────────
  static Future<String?> uploadAvatar(File imageFile) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final bytes = await imageFile.readAsBytes();
      final ext   = imageFile.path.split('.').last.toLowerCase();
      final path  = 'avatars/$uid.${ext.isEmpty ? 'jpg' : ext}';

      await _sb.storage.from('documents').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = _sb.storage.from('documents').getPublicUrl(path);

      await _sb.from('profiles')
          .update({'avatar_url': url}).eq('id', uid);

      return url;
    } catch (_) {
      return null;
    }
  }

  // ── ОБНОВИТЬ СПЕЦИАЛИЗАЦИЮ МАСТЕРА ───────────────────────
  static Future<bool> updateSpecialty({
    required String specialty,
    String? description,
    double? priceFrom,
    int?    experienceYears,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final updates = <String, dynamic>{
        'specialty'  : specialty,
        'updated_at' : DateTime.now().toIso8601String(),
      };
      if (description     != null) updates['description']      = description;
      if (priceFrom       != null) updates['price_from']       = priceFrom;
      if (experienceYears != null) updates['experience_years'] = experienceYears;

      await _sb.from('profiles').update(updates).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── ПЕРЕКЛЮЧИТЬ ДОСТУПНОСТЬ МАСТЕРА ──────────────────────
  static Future<bool> setAvailability(bool isAvailable) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _sb.from('profiles')
          .update({'is_available': isAvailable}).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── ПОИСК МАСТЕРОВ ────────────────────────────────────────
  static Future<List<UserModel>> searchMasters({
    String? specialty,
    String? nameQuery,
    double? minRating,
    String? buildingId,
    int     page     = 0,
    int     pageSize = 20,
  }) async {
    try {
      // 1. Создаем базовый запрос
      var query = _sb
          .from('profiles')
          .select()
          .eq('role', 'master')
          .eq('is_verified', true);

      // 2. Добавляем динамические фильтры
      if (specialty != null) {
        query = query.eq('specialty', specialty);
      }
      if (minRating != null) {
        query = query.gte('rating', minRating);
      }
      if (nameQuery != null && nameQuery.isNotEmpty) {
        query = query.ilike('full_name', '%$nameQuery%');
      }
      if (buildingId != null) {
        query = query.eq('building_id', buildingId);
      }

      // 3. Сортировка и пагинация в конце
      final response = await query
          .order('rating', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return (response as List)
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── ОБНОВИТЬ FCM ТОКЕН ────────────────────────────────────
  static Future<void> updateFcmToken(String? token) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('profiles').update({'fcm_token': token}).eq('id', uid);
    } catch (_) {}
  }
}