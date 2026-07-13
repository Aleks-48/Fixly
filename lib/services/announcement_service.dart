import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementService {
  static final _supabase = Supabase.instance.client;

  /// Загружает все объявления для конкретного дома
  static Future<List<Map<String, dynamic>>> getAnnouncements(String buildingId) async {
    final resp = await _supabase
        .from('announcements')
        .select('id, title, content, author_id, is_urgent, created_at')
        .eq('building_id', buildingId)
        .order('is_urgent', ascending: false)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(resp as List);
  }

  /// Создает новое объявление
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required String authorId,
    required String buildingId,
    bool isUrgent = false,
  }) async {
    final resp = await _supabase.from('announcements').insert({
      'title': title,
      'content': content,
      'author_id': authorId,
      'building_id': buildingId,
      'is_urgent': isUrgent,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return resp;
  }

  /// Удаляет объявление по его ID
  static Future<void> deleteAnnouncement(String id) async {
    await _supabase.from('announcements').delete().eq('id', id);
  }
}
