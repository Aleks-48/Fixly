// lib/services/yolo_service.dart
// Сервис компьютерного зрения для распознавания неисправностей
// Отправляет фото на Python FastAPI + YOLOv8 backend
// и возвращает список обнаруженных дефектов

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ── Результат детекции ─────────────────────────────────────
class DefectDetection {
  final String  label;       // тип дефекта
  final double  confidence;  // уверенность 0.0–1.0
  final String  labelRu;     // на русском
  final String  labelKz;     // на казахском
  final String  severity;    // low | medium | high | critical
  final String  suggestion;  // рекомендация
  // Bounding box (нормализованные координаты 0..1)
  final double  x1, y1, x2, y2;

  const DefectDetection({
    required this.label,
    required this.confidence,
    required this.labelRu,
    required this.labelKz,
    required this.severity,
    required this.suggestion,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory DefectDetection.fromJson(Map<String, dynamic> j) {
    final label      = j['label']?.toString() ?? 'unknown';
    final meta       = _defectMeta[label] ?? _defectMeta['unknown']!;
    final box        = (j['box'] as List<dynamic>?) ?? [0, 0, 1, 1];

    return DefectDetection(
      label      : label,
      confidence : (j['confidence'] as num?)?.toDouble() ?? 0.0,
      labelRu    : meta['ru']!,
      labelKz    : meta['kz']!,
      severity   : meta['severity']!,
      suggestion : meta['suggestion']!,
      x1         : (box[0] as num).toDouble(),
      y1         : (box[1] as num).toDouble(),
      x2         : (box[2] as num).toDouble(),
      y2         : (box[3] as num).toDouble(),
    );
  }

  // Цвет по уровню критичности
  static const _severityColors = {
    'low'     : 0xFF4CAF50,
    'medium'  : 0xFFFF9800,
    'high'    : 0xFFE53935,
    'critical': 0xFF880E4F,
  };

  int get severityColor =>
      _severityColors[severity] ?? _severityColors['medium']!;

  String severityLabel(String lang) => lang == 'ru'
      ? const {'low': 'Низкий', 'medium': 'Средний', 'high': 'Высокий', 'critical': 'Критический'}[severity]!
      : const {'low': 'Төмен', 'medium': 'Орташа', 'high': 'Жоғары', 'critical': 'Маңызды'}[severity]!;
}

// Метаданные дефектов — словарь
const _defectMeta = <String, Map<String, String>>{
  'water_leak': {
    'ru'        : 'Протечка воды',
    'kz'        : 'Су ағуы',
    'severity'  : 'high',
    'suggestion': 'Перекройте воду и вызовите сантехника',
  },
  'pipe_crack': {
    'ru'        : 'Трещина в трубе',
    'kz'        : 'Құбырдағы жарық',
    'severity'  : 'critical',
    'suggestion': 'Немедленно перекройте воду',
  },
  'electrical_spark': {
    'ru'        : 'Искрение проводки',
    'kz'        : 'Сымның ұшқыны',
    'severity'  : 'critical',
    'suggestion': 'Отключите электричество и вызовите электрика',
  },
  'broken_socket': {
    'ru'        : 'Сломанная розетка',
    'kz'        : 'Сынған розетка',
    'severity'  : 'high',
    'suggestion': 'Не используйте розетку',
  },
  'mold': {
    'ru'        : 'Плесень',
    'kz'        : 'Зең',
    'severity'  : 'medium',
    'suggestion': 'Обработайте противогрибковым средством',
  },
  'wall_crack': {
    'ru'        : 'Трещина в стене',
    'kz'        : 'Қабырғадағы жарық',
    'severity'  : 'medium',
    'suggestion': 'Требует заделки, проверьте фундамент',
  },
  'broken_window': {
    'ru'        : 'Разбитое стекло',
    'kz'        : 'Сынған шыны',
    'severity'  : 'high',
    'suggestion': 'Застеклите или закройте проём',
  },
  'door_damage': {
    'ru'        : 'Повреждение двери',
    'kz'        : 'Есіктің зақымдануы',
    'severity'  : 'medium',
    'suggestion': 'Требует ремонта петель или замка',
  },
  'ceiling_damage': {
    'ru'        : 'Повреждение потолка',
    'kz'        : 'Төбенің зақымдануы',
    'severity'  : 'high',
    'suggestion': 'Возможно протекает сверху',
  },
  'floor_damage': {
    'ru'        : 'Повреждение пола',
    'kz'        : 'Еденнің зақымдануы',
    'severity'  : 'low',
    'suggestion': 'Требует ремонта покрытия',
  },
  'gas_meter_issue': {
    'ru'        : 'Проблема с газовым счётчиком',
    'kz'        : 'Газ счётчигінің мәселесі',
    'severity'  : 'critical',
    'suggestion': 'Немедленно вызовите газовую службу',
  },
  'unknown': {
    'ru'        : 'Неизвестный дефект',
    'kz'        : 'Белгісіз ақау',
    'severity'  : 'medium',
    'suggestion': 'Опишите проблему мастеру',
  },
};

// ── Сам сервис ─────────────────────────────────────────────
class YoloService {
  // URL вашего Python FastAPI сервера с YOLOv8
  // Для локального тестирования: 'http://10.0.2.2:8000' (Android emulator)
  // Для продакшн: URL вашего сервера
  static const String _baseUrl = 'https://your-yolo-api.fixly.kz';

  static const Duration _timeout = Duration(seconds: 20);

  // ── Анализ изображения ────────────────────────────────────
  static Future<List<DefectDetection>> analyzeImage(
      File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await _sendBytes(bytes);
    } catch (e) {
      debugPrint('YoloService.analyzeImage error: $e');
      rethrow;
    }
  }

  static Future<List<DefectDetection>> analyzeBytes(
      Uint8List bytes) async {
    try {
      return await _sendBytes(bytes);
    } catch (e) {
      debugPrint('YoloService.analyzeBytes error: $e');
      rethrow;
    }
  }

  static Future<List<DefectDetection>> _sendBytes(
      Uint8List bytes) async {
    final uri = Uri.parse('$_baseUrl/detect');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'defect_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ))
      ..fields['confidence_threshold'] = '0.4'
      ..fields['max_detections']        = '10';

    final streamedResponse =
        await request.send().timeout(_timeout);
    final response =
        await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'YOLO API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final detections = (json['detections'] as List<dynamic>?) ?? [];

    return detections
        .map((d) => DefectDetection.fromJson(d as Map<String, dynamic>))
        .where((d) => d.confidence >= 0.4)
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  // ── Рекомендация специализации мастера ────────────────────
  static String recommendSpecialty(List<DefectDetection> detections) {
    if (detections.isEmpty) return 'general';
    const specMap = {
      'water_leak'      : 'plumber',
      'pipe_crack'      : 'plumber',
      'electrical_spark': 'electrician',
      'broken_socket'   : 'electrician',
      'gas_meter_issue' : 'plumber',
      'mold'            : 'painter',
      'wall_crack'      : 'painter',
      'ceiling_damage'  : 'painter',
      'floor_damage'    : 'carpenter',
      'door_damage'     : 'locksmith',
      'broken_window'   : 'locksmith',
    };
    return specMap[detections.first.label] ?? 'general';
  }

  static Future<Object?> analyzeDefect(File image) async {}
}
