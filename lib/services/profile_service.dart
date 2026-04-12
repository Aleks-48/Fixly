import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

  // 1. ПОЛУЧАЕМ ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ
  Future<UserModel> fetchUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel(
        id: data['id'],
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        email: user.email ?? '',
        phone: data['phone'] ?? '',
        bin: data['bin']?.toString() ?? '',
        role: data['role'] ?? 'master', fullName: '',
      );
    } catch (e) {
      print('Ошибка fetchUserProfile: $e');
      rethrow;
    }
  }

  // 2. ПОЛУЧАЕМ РЕАЛЬНУЮ СТАТИСТИКУ МАСТЕРА (ИСПРАВЛЕНО)
  Future<Map<String, dynamic>> getMasterStats(String masterId) async {
    try {
      // Считаем выполненные задачи (простой и надежный способ без FetchOptions)
      final List<dynamic> tasksData = await _supabase
          .from('tasks')
          .select('id')
          .eq('master_id', masterId)
          .eq('status', 'completed');
      
      final int completedCount = tasksData.length;

      // Получаем все рейтинги из таблицы reviews
      final List<dynamic> reviewsData = await _supabase
          .from('reviews')
          .select('rating')
          .eq('master_id', masterId);
      
      double averageRating = 0.0;
      int reviewCount = reviewsData.length;

      if (reviewCount > 0) {
        double totalRating = 0;
        for (var item in reviewsData) {
          totalRating += (item['rating'] as num).toDouble();
        }
        averageRating = totalRating / reviewCount;
      }

      // Получаем опыт работы (безопасно, через try-catch для одной строки)
      int experience = 0;
      try {
        final profileData = await _supabase
            .from('profiles')
            .select('experience_years')
            .eq('id', masterId)
            .maybeSingle(); // Используем maybeSingle чтобы не было ошибки если пусто
            
        if (profileData != null) {
          experience = profileData['experience_years'] ?? 0;
        }
      } catch (e) {
        print('Ошибка получения опыта: $e');
      }

      return {
        'completed_tasks': completedCount,
        'rating': averageRating,
        'review_count': reviewCount,
        'experience': experience,
      };
    } catch (e) {
      print('ОБЩАЯ ОШИБКА СТАТИСТИКИ: $e');
      return {
        'completed_tasks': 0,
        'rating': 0.0,
        'review_count': 0,
        'experience': 0,
      };
    }
  }

  // 3. СОХРАНЯЕМ ПРОФИЛЬ
  Future<bool> saveProfile(UserModel user) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final String fullName = "${user.firstName} ${user.lastName}".trim();

      final Map<String, dynamic> profileData = {
        'id': userId,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'name': fullName,
        'bin': user.id,
        'role': user.role,
        'email': user.email,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('profiles').upsert(profileData);

      print('Успех! Профиль сохранен.');
      return true;
    } catch (e) {
      print('ОШИБКА СОХРАНЕНИЯ ПРОФИЛЯ: $e');
      return false;
    }
  }
}