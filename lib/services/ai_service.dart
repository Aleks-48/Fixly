import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Твой ключ
  static const String _apiKey = 'AIzaSyAXFUyS_VhZUSOoBe7qhomPoUuatfjBt5M'; 
  
  // Модель gemini-3-flash-preview через v1beta
  static const String _url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent';

  static Future<String> generateActionPlan(String title, String description, String lang) async {
    try {
      final response = await http.post(
        Uri.parse('$_url?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": "Составь подробный технический план для мастера: $title. Описание: $description. Пиши на языке: $lang. Не обрывай текст, дай полный ответ."}]
          }],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 2000, // Увеличил с 500 до 2000, чтобы ответы были полными
            "topP": 0.95,
          }
        }),
      ).timeout(const Duration(seconds: 25)); // Увеличил таймаут для тяжелых ответов

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else if (response.statusCode == 503 || response.statusCode == 429) {
        // Если сервер перегружен или лимиты исчерпаны
        return "WAIT_LIMIT_REACHED"; 
      } else {
        print("Ошибка от Google: ${response.body}");
        return "ERROR_${response.statusCode}";
      }
    } catch (e) {
      print("Сетевая ошибка: $e");
      return "ERROR_NETWORK";
    }
  }
}