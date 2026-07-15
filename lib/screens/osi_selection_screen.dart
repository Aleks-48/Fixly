import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/screens/main_wrapper.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/theme/app_theme.dart';

// ============================================================
//  OsiSelectionScreen — привязка к дому после регистрации
// ------------------------------------------------------------
//  ВАЖНО: раньше этот экран умел искать ТОЛЬКО дома, уже существующие
//  в таблице buildings — карта просто показывала маркеры для них же.
//  Создания НОВОГО дома тут не было вообще (эта логика жила отдельно в
//  building_search_screen.dart, не подключённом к этому флоу).
//
//  Теперь основной сценарий — список "город → адрес" (искать глазами по
//  карте неудобно, особенно пожилым пользователям — список быстрее и
//  понятнее). Карта — это карта всего Казахстана (OpenStreetMap), она
//  и так покрывает все города; выбор города здесь — это просто фильтр,
//  который сужает список и уточняет поиск по OpenStreetMap, а не
//  ограничение самой карты.
//
//  Если адреса нет в базе Fixly — ищем через OpenStreetMap Nominatim
//  (как раньше делал только building_search_screen.dart) и при выборе
//  такого нового адреса ОБЯЗАТЕЛЬНО просим подтвердить количество
//  квартир перед тем, как создать дом — раньше это число нигде
//  не спрашивалось на этом экране.
// ============================================================
class OsiSelectionScreen extends StatefulWidget {
  const OsiSelectionScreen({super.key});

  @override
  State<OsiSelectionScreen> createState() => _OsiSelectionScreenState();
}

// Крупные города Казахстана — сужает поиск и список, не ограничивает
// саму карту (OSM и так видит всю страну).
const List<String> _kzCities = [
  'Астана',
  'Алматы',
  'Шымкент',
  'Кокшетау',
  'Караганда',
  'Актобе',
  'Тараз',
  'Павлодар',
  'Усть-Каменогорск',
  'Семей',
  'Атырау',
  'Костанай',
  'Кызылорда',
  'Уральск',
  'Петропавловск',
  'Актау',
  'Темиртау',
  'Түркістан',
  'Талдыкорган',
  'Экибастуз',
];

class _OsiSelectionScreenState extends State<OsiSelectionScreen> {
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  Timer? _debounce;

  String _selectedCity = 'Кокшетау';
  bool _isLoading = true;
  bool _isSearchingOsm = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _allBuildings = [];
  List<Map<String, dynamic>> _filteredBuildings = [];
  List<dynamic> _osmResults = [];

  final LatLng _kokshetauCenter = const LatLng(53.2833, 69.3833);

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Безопасное преобразование в double — Supabase/PostgREST может
  // отдать numeric-колонку как int, double или даже строку в
  // зависимости от значения и сериализации. `as double` в таких
  // случаях падает с рантайм-ошибкой; этот хелпер обрабатывает все
  // варианты и возвращает 0.0 только если значение реально отсутствует
  // или нечитаемо (в паре с фильтром `!= null` выше по коду такое
  // почти не должно случаться).
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _loadBuildings() async {
    try {
      final data = await Supabase.instance.client
          .from('buildings')
          .select('id, address, lat, lng, total_apartments');
      if (mounted) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _applyCityAndSearch();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки зданий: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onQueryChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _applyCityAndSearch);
  }

  // ── Фильтр по городу + локальный поиск, затем (если пусто) OSM ──
  Future<void> _applyCityAndSearch() async {
    final query = _searchController.text.trim().toLowerCase();
    final cityLower = _selectedCity.toLowerCase();

    final localMatches = _allBuildings.where((b) {
      final address = (b['address'] ?? '').toString().toLowerCase();
      final matchesCity = address.contains(cityLower);
      final matchesQuery = query.isEmpty || address.contains(query);
      return matchesCity && matchesQuery;
    }).toList();

    setState(() {
      _filteredBuildings = localMatches;
      _osmResults = [];
    });

    // Если в своей базе ничего не нашли и пользователь что-то ввёл —
    // ищем реальный адрес через OpenStreetMap (весь Казахстан, но
    // подсказываем город в самом запросе для точности).
    if (localMatches.isEmpty && query.length >= 3) {
      await _searchOpenStreetMap(query);
    }
  }

  Future<void> _searchOpenStreetMap(String query) async {
    setState(() => _isSearchingOsm = true);
    final fullQuery = '$query, $_selectedCity, Казахстан';
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(fullQuery)}&format=json&addressdetails=1&countrycodes=kz&limit=6',
    );
    try {
      final response = await http.get(url, headers: {
        'Accept-Language': 'ru-RU,ru;q=0.9',
        'User-Agent': 'FixlyApp/1.0',
      });
      if (response.statusCode == 200 && mounted) {
        setState(() => _osmResults = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Ошибка OSM: $e');
    } finally {
      if (mounted) setState(() => _isSearchingOsm = false);
    }
  }

  // ── Подтверждение количества квартир для НОВОГО дома ────────────
  // ВАЖНО: раньше этого шага не существовало нигде на этом экране —
  // новый дом невозможно было создать отсюда вообще. total_apartments
  // используется потом в кворуме голосований (voting_page.dart) и в
  // KPI председателя — без него эти расчёты будут неверными (деление
  // на 0 или на дефолтные значения).
  Future<int?> _askApartmentCount(String address) async {
    final ctrl = TextEditingController();
    final c = AppColors.of(context);
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Сколько квартир в доме?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              address,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Например: 80',
                hintStyle: TextStyle(color: c.textTertiary),
                filled: true,
                fillColor: c.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Это число нужно для подсчёта кворума на голосованиях дома — укажите точно.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Отмена', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary, // Шалфейный акцент вместо синего
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim());
              if (n == null || n <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Введите корректное число квартир')),
                );
                return;
              }
              Navigator.pop(ctx, n);
            },
            child: const Text('Подтвердить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Создание НОВОГО дома (найден через OSM, в базе Fixly его нет) ──
  Future<void> _createAndSelectBuilding(Map<String, dynamic> osmPlace) async {
    final address = osmPlace['display_name']?.toString() ?? '';
    final lat = double.tryParse(osmPlace['lat']?.toString() ?? '');
    final lon = double.tryParse(osmPlace['lon']?.toString() ?? '');

    final apartments = await _askApartmentCount(address);
    if (apartments == null) return; // отменено

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('buildings')
          .insert({
            'address': address,
            'lat': lat,
            'lng': lon,
            'total_apartments': apartments,
          })
          .select('id')
          .single();

      await _selectBuilding(row['id'].toString(), address);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания дома: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Привязка пользователя к выбранному (существующему) дому
  Future<void> _selectBuilding(String buildingId, String address) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Подтверждение", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text("Привязать ваш профиль к адресу:\n$address?", style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: Text("Отмена", style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary, // Шалфейный акцент вместо синего
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Да, это мой дом", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final supabase = Supabase.instance.client;

        await supabase
            .from('profiles')
            .update({'building_id': buildingId})
            .eq('id', user.id);

        // См. пояснение выше по файлу — синхронизируем building_members,
        // иначе BuildingContextService не увидит подтверждённое членство.
        final profileRow = await supabase
            .from('profiles')
            .select('role, user_type')
            .eq('id', user.id)
            .maybeSingle();
        final memberRole = BuildingContextService.normalizeRoleKey(
          profileRow?['role']?.toString(),
          profileRow?['user_type']?.toString(),
        );

        final existingMembership = await supabase
            .from('building_members')
            .select('id')
            .eq('user_id', user.id)
            .eq('building_id', buildingId)
            .maybeSingle();

        if (existingMembership != null) {
          await supabase
              .from('building_members')
              .update({
                'member_role': memberRole,
                'verification_status': 'verified',
              })
              .eq('id', existingMembership['id']);
        } else {
          await supabase.from('building_members').insert({
            'user_id': user.id,
            'building_id': buildingId,
            'member_role': memberRole,
            'verification_status': 'verified',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Вы успешно привязаны к дому!"), backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainWrapper()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text("Найдите свой дом"),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                // ── Город (сужает список и поиск, не ограничивает карту) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCity,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown),
                    style: TextStyle(fontSize: 17, color: c.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Город',
                      labelStyle: TextStyle(color: c.textSecondary),
                      prefixIcon: Icon(LucideIcons.mapPin, color: c.primary), // Шалфейный акцент
                      filled: true,
                      fillColor: c.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _kzCities
                        .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                        .toList(),
                    onChanged: (city) {
                      if (city == null) return;
                      setState(() => _selectedCity = city);
                      _applyCityAndSearch();
                    },
                  ),
                ),

                // ── Поиск адреса внутри выбранного города ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 16, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Улица, дом (например: Абылай Хана 30)",
                      hintStyle: TextStyle(color: c.textTertiary),
                      prefixIcon: Icon(LucideIcons.search, color: c.primary), // Шалфейный акцент
                      suffixIcon: _isSearchingOsm
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: c.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // ── Карта: вся страна видна всегда, это просто визуальная
                //    подсказка/подтверждение, а не основной способ поиска ──
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _kokshetauCenter,
                        initialZoom: 12.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.fixly_app',
                        ),
                        MarkerLayer(
                          markers: _filteredBuildings
                              .where((b) => b['lat'] != null && b['lng'] != null)
                              .map((b) => Marker(
                                    // ВАЖНО: раньше был жёсткий каст `as double`.
                                    // Supabase/PostgREST может отдать numeric-
                                    // колонку как int, если у координаты нет
                                    // дробной части (или в зависимости от
                                    // сериализации) — `as double` в этом
                                    // случае падает с "type 'int' is not a
                                    // subtype of type 'double'", и карта не
                                    // отрисовывалась вовсе. _toDouble() безопасно
                                    // обрабатывает и int, и double, и String.
                                    point: LatLng(_toDouble(b['lat']), _toDouble(b['lng'])),
                                    width: 46,
                                    height: 46,
                                    child: GestureDetector(
                                      onTap: () => _selectBuilding(b['id'], b['address']),
                                      child: const Icon(LucideIcons.mapPin,
                                          color: Colors.redAccent, size: 38),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Основной способ выбора: список ──
                Expanded(
                  flex: 5,
                  child: Container(
                    color: c.background,
                    child: _buildResultsList(c),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResultsList(AppColors c) {
    // 1. Есть совпадения в базе Fixly — показываем их (это уже
    //    существующие ОСИ, к которым можно просто присоединиться).
    if (_filteredBuildings.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _filteredBuildings.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
        itemBuilder: (ctx, i) {
          final building = _filteredBuildings[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.success.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(LucideIcons.building2, color: c.success),
            ),
            title: Text(building['address'] ?? 'Без адреса',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary)),
            subtitle: Text("Квартир: ${building['total_apartments'] ?? 0} · уже в Fixly",
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            trailing: _isSaving
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                : const Icon(LucideIcons.chevronRight, color: Colors.grey),
            onTap: () {
              if (building['lat'] != null && building['lng'] != null) {
                _mapController.move(LatLng(_toDouble(building['lat']), _toDouble(building['lng'])), 16.0);
              }
              _selectBuilding(building['id'], building['address']);
            },
          );
        },
      );
    }

    // 2. Ничего своего не нашли — показываем результаты OpenStreetMap,
    //    выбор любого из них создаёт НОВЫЙ дом (после подтверждения
    //    количества квартир).
    if (_osmResults.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              "Дома нет в Fixly. Выберите адрес, чтобы создать новый:",
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _osmResults.length,
              itemBuilder: (ctx, i) {
                final place = _osmResults[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: c.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isSaving ? null : () => _createAndSelectBuilding(place),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.mapPin, color: c.danger, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                place['display_name'] ?? 'Неизвестный адрес',
                                style: TextStyle(color: c.textPrimary, fontSize: 15),
                              ),
                            ),
                            Icon(LucideIcons.plusCircle, color: c.primary), // Шалфейный плюс
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (_searchController.text.trim().length >= 3 && !_isSearchingOsm) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.mapPinOff, size: 44, color: c.textTertiary),
              const SizedBox(height: 12),
              Text("Адрес не найден в $_selectedCity",
                  style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Проверьте написание или выберите другой город",
                  style: TextStyle(color: c.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Введите улицу и номер дома в поле поиска выше",
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 15),
        ),
      ),
    );
  }
}


// ==========================================
// FILE: D:\Fixly_APP\fixly_app\lib\screens\portfolio_screen.dart