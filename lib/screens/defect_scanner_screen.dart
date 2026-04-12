import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/services/yolo_service.dart';
import 'package:fixly_app/screens/create_order_page.dart';

// ============================================================
//  DefectScannerScreen — сканер неисправностей через YOLOv8
//
//  Как использовать:
//  1. Нажать на камеру → сделать фото дефекта
//  2. Или выбрать из галереи
//  3. YOLOv8 API определяет тип неисправности
//  4. Показывает bounding boxes и описание дефекта
//  5. Кнопка "Создать заявку" — автоматически заполняет
//     поля заявки (категория мастера, описание)
//
//  pubspec.yaml зависимости:
//    camera: ^0.10.5
//    image_picker: ^1.0.4
//    http: ^1.1.0
// ============================================================
class DefectScannerScreen extends StatefulWidget {
  const DefectScannerScreen({super.key});

  @override
  State<DefectScannerScreen> createState() => _DefectScannerScreenState();
}

class _DefectScannerScreenState extends State<DefectScannerScreen> {
  CameraController? _cameraCtrl;
  List<CameraDescription>? _cameras;
  
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  
  File? _imageFile;
  List<DefectDetection> _detections = [];
  String? _masterCategory;
  String? _recommendationRu;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraCtrl = CameraController(
          _cameras!.first, 
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraCtrl!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Ошибка инициализации камеры: $e");
    }
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    super.dispose();
  }

  // Сделать фото
  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _cameraCtrl == null || _cameraCtrl!.value.isTakingPicture) {
      return;
    }
    try {
      final XFile pic = await _cameraCtrl!.takePicture();
      _analyzeImage(File(pic.path));
    } catch (e) {
      debugPrint("Ошибка снимка: $e");
    }
  }

  // Выбрать фото из галереи
  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final XFile? pic = await picker.pickImage(source: ImageSource.gallery);
    if (pic != null) {
      _analyzeImage(File(pic.path));
    }
  }

  // Отправка картинки в YOLOv8 (или Flask бэкенд)
  Future<void> _analyzeImage(File image) async {
    setState(() {
      _imageFile = image;
      _isAnalyzing = true;
      _detections.clear();
      _masterCategory = null;
      _recommendationRu = null;
    });

    try {
      // Вызываем наш сервис YOLO. 
      // Если у вас свой сервер, YoloService.detect(image) 
      // должен вернуть List<DefectDetection>.
      final result = await YoloService.analyzeDefect(image);
      
      if (mounted) {
        setState(() {
          _detections = result!.detections!;
          _masterCategory = result.masterCategory;
          _recommendationRu = result.recommendation;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка анализа: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  // Сброс и возврат к камере
  void _reset() {
    setState(() {
      _imageFile = null;
      _detections.clear();
      _masterCategory = null;
      _recommendationRu = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("Умный сканер поломок"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(LucideIcons.refreshCcw),
              onPressed: _reset,
            )
        ],
      ),
      body: Column(
        children: [
          // Область просмотра (камера или готовое фото)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageFile == null && _isCameraInitialized)
                    CameraPreview(_cameraCtrl!),
                  if (_imageFile != null)
                    Image.file(_imageFile!, fit: BoxFit.cover),
                  
                  // Отрисовка Bounding Boxes (рамок дефекта) поверх фото
                  if (_imageFile != null && _detections.isNotEmpty)
                    CustomPaint(
                      painter: _BBoxPainter(_detections),
                    ),

                  // Индикатор загрузки
                  if (_isAnalyzing)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.blueAccent),
                            SizedBox(height: 12),
                            Text("ИИ анализирует дефект...", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Область результатов
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111112) : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: _imageFile == null ? _buildCameraControls() : _buildResultsUI(),
            ),
          )
        ],
      ),
    );
  }

  // Кнопки управления съемкой
  Widget _buildCameraControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Наведите камеру на поломку\nили выберите фото из галереи",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 32,
              color: Colors.blueAccent,
              icon: const Icon(LucideIcons.image),
              onPressed: _pickGallery,
            ),
            GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              iconSize: 32,
              color: Colors.grey,
              icon: const Icon(LucideIcons.fish),
              onPressed: () {}, // Переключение вспышки
            ),
          ],
        )
      ],
    );
  }

  // Отображение результатов анализа
  Widget _buildResultsUI() {
    if (_isAnalyzing) {
      return const Center(child: Text("Пожалуйста, подождите..."));
    }

    if (_detections.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.checkCircle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text("Видимых дефектов не найдено.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _reset,
            child: const Text("Попробовать еще раз"),
          )
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Обнаружено: ${_detections.length}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(_recommendationRu ?? "Рекомендуется вызвать специалиста.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 16),
          
          // Список дефектов
          ..._detections.map((d) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(d.severityColor).withOpacity(0.2),
              child: Icon(LucideIcons.alertTriangle, color: Color(d.severityColor), size: 20),
            ),
            title: Text(d.labelRu, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Точность: ${(d.confidence * 100).toStringAsFixed(1)}%"),
          )),

          const SizedBox(height: 20),
          
          // Кнопка создания заявки на основе ИИ
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(LucideIcons.filePlus2, color: Colors.white),
              label: const Text("Создать заявку с этим фото", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () {
                // Передача данных на страницу создания заявки
                // Убрали description: summary, т.к. CreateOrderPage его не принимает
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (ctx) => const CreateOrderPage(initialCategory: '', masterId: null, masterName: null, prefillDescription: '',), // ИСПРАВЛЕНО ЗДЕСЬ
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

extension on Object {
  String? get masterCategory => null;
  
  List<DefectDetection>? get detections => null;
  
  String? get recommendation => null;
}

// ───────────────────── Painter для bounding boxes ─────────────────────
class _BBoxPainter extends CustomPainter {
  final List<DefectDetection> detections;
  _BBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final color = Color(d.severityColor);
      final paint = Paint()
        ..color   = color
        ..style   = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rect = Rect.fromLTRB(
        d.x1 * size.width,
        d.y1 * size.height,
        d.x2 * size.width,
        d.y2 * size.height,
      );

      // Рамка
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Фон метки
      final labelText = d.labelRu;
      final tp = TextPainter(
        text: TextSpan(
          text: ' $labelText ${(d.confidence * 100).toStringAsFixed(0)}% ',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - tp.height - 4,
        tp.width,
        tp.height + 4,
      );
      canvas.drawRect(
          labelRect, Paint()..color = color.withOpacity(0.8));
      
      // Текст
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}