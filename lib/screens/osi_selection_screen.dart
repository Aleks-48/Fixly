import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OsiSelectionScreen extends StatefulWidget {
  const OsiSelectionScreen({super.key});

  @override
  State<OsiSelectionScreen> createState() => _OsiSelectionScreenState();
}

class _OsiSelectionScreenState extends State<OsiSelectionScreen> {
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  
  List<Map<String, dynamic>> _allBuildings = [];
  List<Map<String, dynamic>> _filteredBuildings = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Координаты Кокшетау по умолчанию
  final LatLng _kokshetauCenter = const LatLng(53.2833, 69.3833);

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _searchController.addListener(_filterBuildings);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Загружаем все доступные дома (ОСИ) из базы
  Future<void> _loadBuildings() async {
    try {
      final data = await Supabase.instance.client
          .from('buildings')
          .select('id, address, lat, lng, total_apartments');
          
      setState(() {
        _allBuildings = List<Map<String, dynamic>>.from(data);
        _filteredBuildings = _allBuildings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки зданий: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterBuildings() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBuildings = _allBuildings.where((b) {
        final address = (b['address'] ?? '').toString().toLowerCase();
        return address.contains(query);
      }).toList();
    });
  }

  // Привязка жителя к выбранному дому
  Future<void> _selectBuilding(String buildingId, String address) async {
    // Подтверждение
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Подтверждение"),
        content: Text("Привязать ваш профиль к адресу:\n$address?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отмена")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Да, это мой дом", style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Обновляем профиль жителя, добавляя building_id
        await Supabase.instance.client
            .from('profiles')
            .update({'building_id': buildingId})
            .eq('id', user.id);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Вы успешно привязаны к дому!"), backgroundColor: Colors.green)
          );
          // Здесь можно сделать переход на Главный экран (HomePage)
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Найдите свой дом", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Строка поиска
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Введите адрес (например: Абылай Хана 30)",
                    prefixIcon: const Icon(LucideIcons.search, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Карта (занимает половину экрана)
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _kokshetauCenter,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fixly_app',
                      ),
                      MarkerLayer(
                        markers: _filteredBuildings.where((b) => b['lat'] != null && b['lng'] != null).map((b) {
                          return Marker(
                            point: LatLng(b['lat'] as double, b['lng'] as double),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => _selectBuilding(b['id'], b['address']),
                              child: const Icon(LucideIcons.mapPin, color: Colors.redAccent, size: 40),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Список адресов под картой (занимает вторую половину)
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.white,
                  child: _filteredBuildings.isEmpty
                    ? const Center(child: Text("Дома не найдены", style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _filteredBuildings.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final building = _filteredBuildings[i];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.building, color: Colors.blueAccent),
                            ),
                            title: Text(building['address'] ?? 'Без адреса', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Квартир: ${building['total_apartments'] ?? 0}"),
                            trailing: _isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(LucideIcons.chevronRight, color: Colors.grey),
                            onTap: () {
                              // При клике центрируем карту на этом доме (если есть координаты)
                              if (building['lat'] != null && building['lng'] != null) {
                                _mapController.move(LatLng(building['lat'], building['lng']), 16.0);
                              }
                              // И предлагаем привязаться
                              _selectBuilding(building['id'], building['address']);
                            },
                          );
                        },
                      ),
                ),
              )
            ],
          ),
    );
  }
}