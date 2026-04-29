import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/services/yolo_service.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ============================================================================
// DefectScannerScreen — интеллектуальный сканер дефектов (YOLOv8)
// ============================================================================

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
          imageFormatGroup: ImageFormatGroup.jpeg,
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

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _cameraCtrl == null || _cameraCtrl!.value.isTakingPicture) {
      return;
    }
    try {
      final XFile pic = await _cameraCtrl!.takePicture();
      _analyzeImage(File(pic.path));
    } catch (e) {
      debugPrint("Ошибка при создании снимка: $e");
    }
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final XFile? pic = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pic != null) {
      _analyzeImage(File(pic.path));
    }
  }

  Future<void> _analyzeImage(File image) async {
    setState(() {
      _imageFile = image;
      _isAnalyzing = true;
      _detections.clear();
      _masterCategory = null;
      _recommendationRu = null;
    });

    try {
      // ИСПРАВЛЕНИЕ: Сразу приводим результат к нужному типу YoloResult
      final result = await YoloService.analyzeDefect(image) as YoloResult?;
      
      if (mounted && result != null) {
        setState(() {
          _detections = result.detections; // Убрали !, так как в модели это не null
          _masterCategory = result.masterCategory;
          _recommendationRu = result.recommendation;
        });
      }
    } catch (e) {
      debugPrint("Ошибка анализа: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка анализа ИИ: $e")),
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
    final lang = 'ru'; 

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(lang == 'ru' ? "Умный сканер" : "Ақылды сканер"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
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
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageFile == null && _isCameraInitialized)
                    CameraPreview(_cameraCtrl!),
                  
                  if (_imageFile != null)
                    Image.file(_imageFile!, fit: BoxFit.cover),
                  
                  if (_imageFile != null && _detections.isNotEmpty && !_isAnalyzing)
                    CustomPaint(
                      painter: _BBoxPainter(_detections),
                    ),

                  if (_isAnalyzing)
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.blueAccent,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              lang == 'ru' ? "ИИ распознает поломку..." : "ЖИ ақауды іздеуде...",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _imageFile == null ? 180 : 320,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111112) : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: _imageFile == null ? _buildCameraControls() : _buildResultsUI(),
          )
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Наведите на неисправность",
          style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionBtn(LucideIcons.image, _pickGallery, Colors.blueAccent.withOpacity(0.1), Colors.blueAccent),
            
            GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.camera, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),

            _actionBtn(LucideIcons.zap, () {}, Colors.grey.withOpacity(0.1), Colors.grey),
          ],
        )
      ],
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap, Color bg, Color iconCol) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: iconCol, size: 24),
      ),
    );
  }

  Widget _buildResultsUI() {
    if (_isAnalyzing) return const SizedBox.shrink();

    if (_detections.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.searchX, color: Colors.orangeAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            "Дефекты не обнаружены",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Попробуйте другой ракурс или освещение", style: TextStyle(color: Colors.grey)),
          const Spacer(),
          _bottomButton("Повторить", _reset, isOutline: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Результат анализа", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("${_detections.length} объекта", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _recommendationRu ?? "Требуется осмотр профильного мастера.",
          style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 8,
          children: _detections.map((d) => Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.blueAccent.withOpacity(0.05),
            side: BorderSide.none,
            avatar: Icon(LucideIcons.alertCircle, size: 14, color: Color(d.severityColor)),
            label: Text(d.labelRu, style: const TextStyle(fontSize: 12)),
          )).toList(),
        ),

        const Spacer(),
        
        _bottomButton(
          "Создать заявку", 
          () {
            final String summary = _detections.map((e) => e.labelRu).join(", ");
            final String fullDescription = "Обнаружено через ИИ: $summary. ${_recommendationRu ?? ''}";

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => CreateOrderPage(
                  initialCategory: _masterCategory ?? '',
                  prefillDescription: fullDescription,
                  masterId:'',
                  masterName:'',
                ),
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _bottomButton(String label, VoidCallback onTap, {bool isOutline = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutline ? Colors.transparent : Colors.blueAccent,
          foregroundColor: isOutline ? Colors.blueAccent : Colors.white,
          elevation: isOutline ? 0 : 2,
          side: isOutline ? const BorderSide(color: Colors.blueAccent) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER: Отрисовка рамок (Bounding Boxes)
// ─────────────────────────────────────────────────────────────────────────────

class _BBoxPainter extends CustomPainter {
  final List<DefectDetection> detections;
  _BBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final color = Color(d.severityColor);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final rect = Rect.fromLTRB(
        d.x1 * size.width,
        d.y1 * size.height,
        d.x2 * size.width,
        d.y2 * size.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );

      final text = "${d.labelRu} ${(d.confidence * 100).toStringAsFixed(0)}%";
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final backgroundPaint = Paint()..color = color.withOpacity(0.8);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top - textPainter.height - 4, textPainter.width + 8, textPainter.height + 4),
        backgroundPaint,
      );

      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS: Классы данных
// ─────────────────────────────────────────────────────────────────────────────

class YoloResult {
  final List<DefectDetection> detections;
  final String? masterCategory;
  final String? recommendation;

  YoloResult({
    required this.detections,
    this.masterCategory,
    this.recommendation,
  });
}

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
}