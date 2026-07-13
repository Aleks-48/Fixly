import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// AIService — обёртка над Gemini API
// ------------------------------------------------------------
// ВАЖНО: раньше API-ключ Gemini лежал прямо в этом файле как
// `static const String _apiKey = '...'`. Это означает, что после сборки
// APK/IPA ключ можно было вытащить простой декомпиляцией бинарника —
// любой человек, скачавший приложение, мог украсть ключ и использовать
// Gemini API за счёт владельца проекта.
//
// Теперь все три метода вызывают серверную Supabase Edge Function
// 'gemini-proxy' (см. supabase/functions/gemini-proxy/index.ts),
// которая хранит настоящий ключ Gemini как секрет на сервере и никогда
// не отдаёт его клиенту. Flutter-приложение общается только со своим же
// Supabase-проектом (через обычную авторизацию), ключ Gemini клиенту
// вообще не виден.
// ============================================================
class AIService {
  static final _functions = Supabase.instance.client.functions;

  /// Общий вызов прокси-функции. Возвращает текст ответа Gemini или один
  /// из специальных кодов ошибки (сохранена обратная совместимость с
  /// тем, что раньше возвращали методы этого класса напрямую).
  static Future<String> _invokeGemini({
    required String prompt,
    double temperature = 0.7,
    int maxOutputTokens = 2000,
    double? topP,
  }) async {
    try {
      final response = await _functions.invoke(
        'gemini-proxy',
        body: {
          'prompt': prompt,
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
          if (topP != null) 'topP': topP,
        },
      );

      final status = response.status;
      final data = response.data;

      if (status == 429) {
        return 'WAIT_LIMIT_REACHED';
      }

      if (status != 200) {
        final errMsg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'HTTP $status';
        print('Ошибка gemini-proxy: $errMsg');
        return 'ERROR_$status';
      }

      if (data is Map && data['text'] != null) {
        return data['text'].toString();
      }

      return 'ERROR_EMPTY_RESPONSE';
    } on FunctionException catch (e) {
      // FunctionException возникает при сетевых сбоях/недоступности
      // функции — например, если 'gemini-proxy' ещё не задеплоена.
      if (e.status == 429) return 'WAIT_LIMIT_REACHED';
      print('FunctionException (gemini-proxy): ${e.details ?? e.status}');
      return 'ERROR_${e.status}';
    } catch (e) {
      print('Сетевая ошибка (gemini-proxy): $e');
      return 'ERROR_NETWORK';
    }
  }

  /// 1. ФУНКЦИЯ ДЛЯ МАСТЕРА: Создание технического плана работ
  static Future<String> generateActionPlan(
      String title, String description, String lang) {
    final prompt =
        "Ты — профессиональный технический эксперт. Составь подробный "
        "пошаговый технический план для мастера по заявке: '$title'. "
        "Описание проблемы: '$description'. Пиши строго на языке: $lang. "
        "Ответ должен быть структурированным и полным.";

    return _invokeGemini(
      prompt: prompt,
      temperature: 0.7,
      maxOutputTokens: 2000,
      topP: 0.95,
    );
  }

  /// 2. ФУНКЦИЯ ДЛЯ ПРЕДСЕДАТЕЛЯ: Финансовая аналитика и прогнозы
  static Future<String> getChairmanFinancialAnalysis({
    required double savingAccount,       // Накопительный счет
    required double capitalRepairAccount,  // Капитальный ремонт
    required String lang,                // Язык интерфейса
    List<Map<String, dynamic>>? recentExpenses,
    required String marketContext,       // Список последних трат
  }) {
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

    return _invokeGemini(
      prompt: prompt,
      temperature: 0.8,
      maxOutputTokens: 1500,
    );
  }

  /// 3. ФУНКЦИЯ ДЛЯ ЧАТА: Анализ честности цены (Детектор лжи)
  static Future<String> verifyPriceFairness(
      String workTask, double price, String lang) {
    final prompt = '''
      Проверь, является ли цена $price тенге за работу "$workTask" адекватной для рынка Казахстана.
      Ответь очень кратко:
      1. Средний диапазон цен.
      2. Вердикт: (Честно / Дорого / Слишком дешево).
      3. Если дорого — почему.
      Язык: $lang.
      ''';

    return _invokeGemini(
      prompt: prompt,
      temperature: 0.3,
      maxOutputTokens: 500,
    );
  }
}
