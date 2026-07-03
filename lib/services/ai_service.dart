import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
//  AIService — раньше здесь был зашит API-ключ Gemini прямо в Dart-код
//  (static const String _apiKey = 'AIzaSy...'). Это критическая проблема:
//  ключ попадает в скомпилированный APK/IPA и его можно вытащить
//  декомпиляцией / простым strings по бинарнику, после чего кто угодно
//  может расходовать твою квоту Gemini от твоего имени.
//
//  Теперь все вызовы идут через Supabase Edge Function 'gemini-proxy'
//  (см. supabase/functions/gemini-proxy/index.ts), которая хранит ключ
//  как секрет на сервере и никогда не отдаёт его клиенту.
//
//  Деплой функции один раз:
//    supabase functions deploy gemini-proxy
//    supabase secrets set GEMINI_API_KEY=твой_ключ
// ============================================================
class AIService {
  static final _sb = Supabase.instance.client;

  /// Низкоуровневый вызов прокси-функции. Возвращает текст ответа Gemini
  /// либо один из кодов ошибок: ERROR_NETWORK, WAIT_LIMIT_REACHED, ERROR_<code>.
  static Future<String> _callGemini(
    String prompt, {
    double temperature = 0.7,
    int maxOutputTokens = 1500,
    double topP = 0.95,
  }) async {
    try {
      final response = await _sb.functions.invoke(
        'gemini-proxy',
        body: {
          'prompt': prompt,
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
          'topP': topP,
        },
      );

      final data = response.data;
      if (data is Map && data['text'] != null) {
        return data['text'].toString();
      }
      if (data is Map && data['error'] == 'WAIT_LIMIT_REACHED') {
        return 'WAIT_LIMIT_REACHED';
      }
      if (data is Map && data['error'] != null) {
        print('Ошибка gemini-proxy: ${data['error']} ${data['details'] ?? ''}');
        return data['error'].toString();
      }
      return 'ERROR_EMPTY_RESPONSE';
    } catch (e) {
      print('Сетевая ошибка вызова gemini-proxy: $e');
      return 'ERROR_NETWORK';
    }
  }

  /// 1. ФУНКЦИЯ ДЛЯ МАСТЕРА: Создание технического плана работ
  static Future<String> generateActionPlan(String title, String description, String lang) async {
    final prompt =
        "Ты — профессиональный технический эксперт. Составь подробный пошаговый технический план для мастера по заявке: '$title'. Описание проблемы: '$description'. Пиши строго на языке: $lang. Ответ должен быть структурированным и полным.";

    return _callGemini(prompt, temperature: 0.7, maxOutputTokens: 2000, topP: 0.95);
  }

  /// 2. ФУНКЦИЯ ДЛЯ ПРЕДСЕДАТЕЛЯ: Финансовая аналитика и прогнозы
  static Future<String> getChairmanFinancialAnalysis({
    required double savingAccount,       // Накопительный счет
    required double capitalRepairAccount,  // Капитальный ремонт
    required String lang,                // Язык интерфейса
    List<Map<String, dynamic>>? recentExpenses,
    required String marketContext,       // Список последних трат
  }) async {
    String expensesText = (recentExpenses != null && recentExpenses.isNotEmpty)
        ? recentExpenses.map((e) => "- ${e['title']}: ${e['amount']} тг").join("\n")
        : (lang == 'ru' ? "Трат за последнее время нет." : "Жақында шығындар болған жоқ.");

    final prompt = '''
    Ты — финансовый ИИ-консультант для председателей ОСИ (объединение собственников имущества) в Казахстане. 
    Проанализируй финансовое состояние дома:
    
    Данные:
    1. Накопительный счет (текущие нужды): $savingAccount тенге.
    2. Счёт на капитальный ремонт: $capitalRepairAccount тенге.
    3. Последние расходы:
    $expensesText
    
    Твоя задача:
    - Кратко оцени состояние бюджета.
    - Дай прогноз: на какие важные работы хватит средств, а на что нужно начать копить (учитывай цены в РК).
    - Если в расходах есть подозрительно высокие суммы, деликатно укажи на это.
    - Дай один полезный совет по управлению домом на эту неделю.

    Пиши строго на языке: $lang. 
    Используй эмодзи (💰, 🛠, ⚠️, ✅) для того, чтобы текст было легко читать.
    Тон: профессиональный, поддерживающий.
    ''';

    return _callGemini(prompt, temperature: 0.8, maxOutputTokens: 1500);
  }

  /// 3. ФУНКЦИЯ ДЛЯ ЧАТА: Анализ честности цены (Детектор лжи)
  static Future<String> verifyPriceFairness(String workTask, double price, String lang) async {
    final prompt = '''
    Проверь, является ли цена $price тенге за работу "$workTask" адекватной для рынка Казахстана.
    Ответь очень кратко:
    1. Средний диапазон цен.
    2. Вердикт: (Честно / Дорого / Слишком дешево).
    3. Если дорого — почему.
    Язык: $lang.
    ''';

    final result = await _callGemini(prompt, temperature: 0.3, maxOutputTokens: 500);
    // Сохраняем прежнее поведение метода: при ошибке отдаём просто "ERROR"
    return result.startsWith('ERROR') ? 'ERROR' : result;
  }
}