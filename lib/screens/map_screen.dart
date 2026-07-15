import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/theme/app_theme.dart'; 

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  // Координаты Кокшетау по умолчанию
  final LatLng _defaultCenter = const LatLng(53.2833, 69.3833);
  double _currentZoom = 13.0;

  // Пример маркеров (в будущем сюда можно мапить TaskModel)
  final List<Marker> _markers = [
    Marker(
      point: const LatLng(53.2850, 69.3850),
      width: 40,
      height: 40,
      child: const Icon(
        LucideIcons.mapPin,
        color: Colors.redAccent,
        size: 32,
      ),
    ),
  ];

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(1.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(1.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Карта заявок",
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _currentZoom,
              // interactionOptions можно настроить для запрета вращения и т.д.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Бесплатный слой тайлов OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fixly_app',
                // Для темной темы можно добавить инверсию цветов тайлов, 
                // если пакет flutter_map_dark_theme установлен, или использовать базовый фильтр
                tileBuilder: isDark ? _darkModeTileBuilder : null,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          
          // Элементы управления картой
          Positioned(
            right: 16,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btnZoomIn",
                  backgroundColor: c.card,
                  mini: true,
                  onPressed: _zoomIn,
                  child: Icon(LucideIcons.plus, color: c.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "btnZoomOut",
                  backgroundColor: c.card,
                  mini: true,
                  onPressed: _zoomOut,
                  child: Icon(LucideIcons.minus, color: c.primary),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "btnLocation",
                  backgroundColor: c.primary,
                  onPressed: () {
                    // Здесь в будущем вызов Geolocator.getCurrentPosition()
                    // и _mapController.move(myPosition, 15.0);
                    _mapController.move(_defaultCenter, 15.0);
                  },
                  child: const Icon(LucideIcons.navigation, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Простой фильтр для инверсии светлой карты в темном режиме
  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1,  0,  0, 0, 255,
         0, -1,  0, 0, 255,
         0,  0, -1, 0, 255,
         0,  0,  0, 1,   0,
      ]),
      child: tileWidget,
    );
  }
}