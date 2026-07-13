import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/screens/main_wrapper.dart';

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
        final sb = Supabase.instance.client;

        // ВАЖНО: раньше здесь обновлялся ТОЛЬКО profiles.building_id.
        // Но BuildingContextService (и вся проверка прав — canManageHouse,
        // isVerifiedMember, доступ к голосованиям) в первую очередь смотрит
        // таблицу building_members, а profiles.building_id — лишь fallback.
        // Без строки в building_members житель не мог голосовать
        // (apartment_id/isVerifiedMember оставались пустыми), а
        // председатель не получал canManageHouse — сколько бы раз он ни
        // выбирал дом на этом экране, для системы он оставался "без дома".
        //
        // Отдельного flow модерации жителей в проекте пока нет (только
        // у мастеров есть verification_screen), поэтому верифицируем сразу.
        final profile = await sb
            .from('profiles')
            .select('role, user_type')
            .eq('id', user.id)
            .maybeSingle();
        final rawRole = (profile?['role'] ?? profile?['user_type'] ?? 'resident')
            .toString()
            .toLowerCase();
        final memberRole = (rawRole == 'osi' || rawRole == 'chairman')
            ? 'chairman'
            : 'resident';

        // На пользователя — одна активная привязка к дому. Если раньше
        // уже была запись (например, к другому дому), заменяем её.
        await sb.from('building_members').delete().eq('user_id', user.id);
        await sb.from('building_members').insert({
          'user_id': user.id,
          'building_id': buildingId,
          'member_role': memberRole,
          'verification_status': 'verified',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Дублируем building_id в profiles — для экранов, которые ещё
        // читают его оттуда напрямую (create_order_page.dart и т.п.).
        await sb
            .from('profiles')
            .update({'building_id': buildingId})
            .eq('id', user.id);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Вы успешно привязаны к дому!"), backgroundColor: Colors.green)
          );
          // ВАЖНО: раньше здесь был Navigator.pop(context). Но
          // register_page.dart открывает OsiSelectionScreen через
          // pushAndRemoveUntil(..., (_) => false), который полностью
          // очищает стек навигации — под этим экраном ничего нет, и pop
          // не срабатывал. Пользователь застревал на этом экране навсегда
          // после успешной привязки к дому. Теперь ведём его дальше в
          // приложение через pushReplacement на MainWrapper.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainWrapper()),
          );
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