// lib/services/yolo_service.dart
//
// Сервис компьютерного зрения для распознавания неисправностей.
// Отправляет фото на Python FastAPI + YOLOv8 backend (yolo_backend_main.py)
// и возвращает YoloResult — единственный публичный контракт сервиса.
//
// ВАЖНО: классы YoloResult и DefectDetection объявлены ЗДЕСЬ и только здесь.
// defect_scanner_screen.dart импортирует их отсюда, а не дублирует локально —
// раньше в проекте существовали два несовместимых класса с одинаковым
// именем DefectDetection (здесь и в самом экране), что приводило к
// рантайм-краху при касте `as YoloResult?`.
//
// Если бэкенд недоступен (пустой _baseUrl, таймаут, сетевая ошибка,
// не-200 ответ) — сервис автоматически возвращает mock-данные, идентичные
// MOCK_DETECTIONS из yolo_backend_main.py, чтобы экран сканера оставался
// рабочим до развёртывания бэкенда.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

// ============================================================
//  МОДЕЛИ — единственный источник истины для всего приложения
// ============================================================

/// Результат анализа фотографии: список детекций + рекомендация
/// по специализации мастера (используется для prefill в CreateOrderPage).
class YoloResult {
  final List<DefectDetection> detections;
  final String? masterCategory;
  final String? recommendation;

  YoloResult({
    required this.detections,
    this.masterCategory,
    this.recommendation,
  });

  factory YoloResult.empty() => YoloResult(detections: const []);
}

/// Одна обнаруженная неисправность с нормализованным bounding box
/// (координаты 0..1 — масштабируются под размер виджета на экране).
class DefectDetection {
  final String labelRu;
  final double confidence;
  final double x1, y1, x2, y2;
  final int severityColor;

  DefectDetection({
    required this.labelRu,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.severityColor = 0xFF2196F3,
  });

  factory DefectDetection.fromApiJson(Map<String, dynamic> json) {
    final label = json['label']?.toString() ?? 'unknown';
    final meta = _defectMeta[label] ?? _defectMeta['unknown']!;
    final box = (json['box'] as List<dynamic>?) ?? const [0, 0, 1, 1];

    return DefectDetection(
      labelRu: meta['ru']!,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      x1: (box[0] as num).toDouble(),
      y1: (box[1] as num).toDouble(),
      x2: (box[2] as num).toDouble(),
      y2: (box[3] as num).toDouble(),
      severityColor: _severityColors[meta['severity']] ?? _severityColors['medium']!,
    );
  }
}

// Метаданные дефектов (ru-лейбл + критичность) по ключу из YOLO backend
const Map<String, Map<String, String>> _defectMeta = {
  'water_leak': {'ru': 'Протечка воды', 'severity': 'high'},
  'pipe_crack': {'ru': 'Трещина в трубе', 'severity': 'critical'},
  'electrical_spark': {'ru': 'Искрение проводки', 'severity': 'critical'},
  'broken_socket': {'ru': 'Сломанная розетка', 'severity': 'high'},
  'mold': {'ru': 'Плесень', 'severity': 'medium'},
  'wall_crack': {'ru': 'Трещина в стене', 'severity': 'medium'},
  'broken_window': {'ru': 'Разбитое стекло', 'severity': 'high'},
  'door_damage': {'ru': 'Повреждение двери', 'severity': 'medium'},
  'ceiling_damage': {'ru': 'Повреждение потолка', 'severity': 'high'},
  'floor_damage': {'ru': 'Повреждение пола', 'severity': 'low'},
  'gas_meter_issue': {'ru': 'Проблема с газовым счётчиком', 'severity': 'critical'},
  'unknown': {'ru': 'Неизвестный дефект', 'severity': 'medium'},
};

const Map<String, int> _severityColors = {
  'low': 0xFF4CAF50,
  'medium': 0xFFFF9800,
  'high': 0xFFE53935,
  'critical': 0xFF880E4F,
};

// Маппинг дефекта → специализация мастера (для prefill в CreateOrderPage)
const Map<String, String> _specialtyMap = {
  'water_leak': 'plumber',
  'pipe_crack': 'plumber',
  'gas_meter_issue': 'plumber',
  'electrical_spark': 'electrician',
  'broken_socket': 'electrician',
  'mold': 'painter',
  'wall_crack': 'painter',
  'ceiling_damage': 'painter',
  'floor_damage': 'carpenter',
  'door_damage': 'locksmith',
  'broken_window': 'locksmith',
};

// Текст рекомендации по ключу дефекта (для YoloResult.recommendation)
const Map<String, String> _recommendationMap = {
  'water_leak': 'Перекройте воду и вызовите сантехника',
  'pipe_crack': 'Немедленно перекройте воду',
  'electrical_spark': 'Отключите электричество и вызовите электрика',
  'broken_socket': 'Не используйте розетку до ремонта',
  'mold': 'Обработайте противогрибковым средством',
  'wall_crack': 'Требует заделки, проверьте фундамент',
  'broken_window': 'Застеклите или закройте проём',
  'door_damage': 'Требует ремонта петель или замка',
  'ceiling_damage': 'Возможно протекает сверху',
  'floor_damage': 'Требует ремонта покрытия',
  'gas_meter_issue': 'Немедленно вызовите газовую службу',
};

// ── Mock-детекции — идентичны MOCK_DETECTIONS из yolo_backend_main.py ──
const List<Map<String, dynamic>> _mockApiDetections = [
  {
    'label': 'water_leak',
    'confidence': 0.87,
    'box': [0.1, 0.2, 0.6, 0.8],
  },
  {
    'label': 'mold',
    'confidence': 0.62,
    'box': [0.5, 0.3, 0.9, 0.7],
  },
];

// ============================================================
//  СЕРВИС
// ============================================================
class YoloService {
  /// URL Python FastAPI сервера с YOLOv8.
  /// Передаётся через --dart-define=FIXLY_YOLO_BASE_URL=https://...
  /// Пока бэкенд не развёрнут — _baseUrl пуст, сервис работает в mock-режиме.
  static const String _baseUrl = String.fromEnvironment('FIXLY_YOLO_BASE_URL');

  static const Duration _timeout = Duration(seconds: 20);

  /// Главный метод, используемый экраном сканера.
  static Future<YoloResult> analyzeDefect(File image) async {
    try {
      final bytes = await image.readAsBytes();
      return await _analyzeBytes(bytes);
    } catch (e) {
      debugPrint('YoloService.analyzeDefect error: $e — fallback to mock');
      return _mockResult();
    }
  }

  static Future<YoloResult> analyzeBytes(Uint8List bytes) async {
    try {
      return await _analyzeBytes(bytes);
    } catch (e) {
      debugPrint('YoloService.analyzeBytes error: $e — fallback to mock');
      return _mockResult();
    }
  }

  static Future<YoloResult> _analyzeBytes(Uint8List bytes) async {
    // Бэкенд ещё не развёрнут — сразу mock, без попытки сетевого запроса.
    if (_baseUrl.isEmpty) {
      debugPrint('YoloService: FIXLY_YOLO_BASE_URL не задан, используется mock-режим');
      return _mockResult();
    }

    final uri = Uri.parse('$_baseUrl/detect');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'defect_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ))
      ..fields['confidence_threshold'] = '0.4'
      ..fields['max_detections'] = '10';

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('YOLO API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rawDetections = (json['detections'] as List<dynamic>?) ?? [];

    return _buildResult(rawDetections);
  }

  /// Собирает mock-результат (фиксированные детекции для офлайн-тестирования).
  static YoloResult _mockResult() => _buildResult(_mockApiDetections);

  /// Общая сборка YoloResult из сырых JSON-детекций (как от реального API,
  /// так и от mock-набора — формат одинаковый).
  static YoloResult _buildResult(List<dynamic> rawDetections) {
    final detections = rawDetections
        .map((d) => DefectDetection.fromApiJson(d as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    if (detections.isEmpty) {
      return YoloResult.empty();
    }

    // Определяем ключ первого (самого уверенного) дефекта через обратный
    // поиск по ru-лейблу, чтобы получить специализацию и рекомендацию.
    final topKey = _defectMeta.entries
        .firstWhere(
          (e) => e.value['ru'] == detections.first.labelRu,
          orElse: () => const MapEntry('unknown', {'ru': 'Неизвестный дефект', 'severity': 'medium'}),
        )
        .key;

    return YoloResult(
      detections: detections,
      masterCategory: _specialtyMap[topKey] ?? 'general',
      recommendation: _recommendationMap[topKey] ?? 'Требуется осмотр профильного мастера.',
    );
  }

  /// Рекомендация специализации по уже готовому списку детекций
  /// (оставлено для обратной совместимости, если понадобится отдельно).
  static String recommendSpecialty(List<DefectDetection> detections) {
    if (detections.isEmpty) return 'general';
    final topKey = _defectMeta.entries
        .firstWhere(
          (e) => e.value['ru'] == detections.first.labelRu,
          orElse: () => const MapEntry('unknown', {'ru': '', 'severity': 'medium'}),
        )
        .key;
    return _specialtyMap[topKey] ?? 'general';
  }
}