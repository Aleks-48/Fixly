import 'package:supabase_flutter/supabase_flutter.dart';

class BillingService {
  final _supabase = Supabase.instance.client;

  // 1. Метод создания счета + авто-публикация в объявления
  Future<void> createInvoice({
    required String buildingId,
    required double amount,
    required String purpose,
    required bool isBuildingWide,
    String? residentId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Шаг А: Создаем сам счет в таблице invoices
      await _supabase.from('invoices').insert({
        'building_id': buildingId,
        'amount': amount,
        'purpose': purpose,
        'is_building_wide': isBuildingWide,
        'resident_id': residentId, 
        'created_by': userId,
        'status': 'pending',
      });

      // Шаг Б: Автоматически создаем объявление в ленту, чтобы жильцы СРАЗУ увидели
      await _supabase.from('announcements').insert({
        'building_id': buildingId,
        'title': '📑 Выставлен новый счет',
        'content': 'Уважаемые жильцы! Выставлен целевой счет: "$purpose".\n💰 Сумма к оплате: $amount ₸.\n\nПодробности и оплата доступны в боковом меню в разделе "Счета и квитанции".',
        'author_id': userId,
      });

    } catch (e) {
      throw Exception('Ошибка при выставлении счета: $e');
    }
  }

  // 2. НОВЫЙ МЕТОД: Получение счетов для экрана жителя (ResidentInvoicesScreen)
  Future<List<Map<String, dynamic>>> getBuildingInvoices(String buildingId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('building_id', buildingId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Ошибка при загрузке счетов: $e');
    }
  }
}