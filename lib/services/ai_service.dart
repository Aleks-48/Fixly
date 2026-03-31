import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Твой API Ключ
  static const String _apiKey = 'AIzaSyB5euntyx2psfrdb3zo_5ewDFy9Im89DyE'; 
  
  // Прямая ссылка на модель, которая 100% работает
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent';

  /// 1. ФУНКЦИЯ ДЛЯ МАСТЕРА: Создание технического плана работ
  static Future<String> generateActionPlan(String title, String description, String lang) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{
              "text": "Ты — профессиональный технический эксперт. Составь подробный пошаговый технический план для мастера по заявке: '$title'. Описание проблемы: '$description'. Пиши строго на языке: $lang. Ответ должен быть структурированным и полным."
            }]
          }],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 2000,
            "topP": 0.95,
          }
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else if (response.statusCode == 429) {
        return "WAIT_LIMIT_REACHED"; 
      } else {
        print("Ошибка Gemini (ActionPlan): ${response.body}");
        return "ERROR_${response.statusCode}";
      }
    } catch (e) {
      print("Сетевая ошибка (ActionPlan): $e");
      return "ERROR_NETWORK";
    }
  }

  /// 2. ФУНКЦИЯ ДЛЯ ПРЕДСЕДАТЕЛЯ: Финансовая аналитика и прогнозы
  static Future<String> getChairmanFinancialAnalysis({
    required double savingAccount,       // Накопительный счет
    required double capitalRepairAccount,  // Капитальный ремонт
    required String lang,                // Язык интерфейса
    List<Map<String, dynamic>>? recentExpenses, required String marketContext, // Список последних трат
  }) async {
    try {
      // Формируем текстовый список трат для ИИ
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

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {
            "temperature": 0.8,
            "maxOutputTokens": 1500,
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print("Ошибка Gemini (Analysis): ${response.body}");
        return "ERROR_${response.statusCode}";
      }
    } catch (e) {
      print("Сетевая ошибка (Analysis): $e");
      return "ERROR_NETWORK";
    }
  }

  /// 3. ФУНКЦИЯ ДЛЯ ЧАТА: Анализ честности цены (Детектор лжи)
  static Future<String> verifyPriceFairness(String workTask, double price, String lang) async {
    try {
      final prompt = '''
      Проверь, является ли цена $price тенге за работу "$workTask" адекватной для рынка Казахстана.
      Ответь очень кратко:
      1. Средний диапазон цен.
      2. Вердикт: (Честно / Дорого / Слишком дешево).
      3. Если дорого — почему.
      Язык: $lang.
      ''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {"temperature": 0.3} // Низкая температура для точности фактов
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "ERROR";
      }
    } catch (e) {
      return "ERROR_NETWORK";
    }
  }
}