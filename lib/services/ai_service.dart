import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class AIService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<String> generateActionPlan(
    String title,
    String description,
    String lang,
  ) async {
    return _invokeText({
      'task': 'action_plan',
      'title': title,
      'description': description,
      'lang': lang,
    });
  }

  static Future<String> getChairmanFinancialAnalysis({
    required double savingAccount,
    required double capitalRepairAccount,
    required String lang,
    List<Map<String, dynamic>>? recentExpenses,
    required String marketContext,
  }) async {
    return _invokeText({
      'task': 'chairman_financial_analysis',
      'savingAccount': savingAccount,
      'capitalRepairAccount': capitalRepairAccount,
      'lang': lang,
      'recentExpenses': recentExpenses ?? const [],
      'marketContext': marketContext,
    });
  }

  static Future<String> verifyPriceFairness(
    String workTask,
    double price,
    String lang,
  ) async {
    return _invokeText({
      'task': 'price_fairness',
      'workTask': workTask,
      'price': price,
      'lang': lang,
    });
  }

  static Future<String> _invokeText(Map<String, dynamic> body) async {
    try {
      final response = await _sb.functions
          .invoke('ai-assistant', body: body)
          .timeout(const Duration(seconds: 35));

      final data = response.data;
      if (data is Map && data['text'] != null) return data['text'].toString();
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['text'] != null) {
          return decoded['text'].toString();
        }
      }
      return 'ERROR_EMPTY_RESPONSE';
    } catch (e) {
      return 'ERROR_NETWORK';
    }
  }
}
