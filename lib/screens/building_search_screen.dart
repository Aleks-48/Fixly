import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/theme/app_theme.dart';

class BuildingSearchScreen extends StatefulWidget {
  const BuildingSearchScreen({super.key});

  @override
  State<BuildingSearchScreen> createState() => _BuildingSearchScreenState();
}

class _BuildingSearchScreenState extends State<BuildingSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  Timer? _debounce;
  
  bool _isLoading = false;
  List<dynamic> _supabaseResults = [];
  List<dynamic> _osmResults = []; 

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Задержка 800мс, чтобы не спамить бесплатный сервер OSM
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (query.length >= 3) {
        _searchDatabase(query.trim());
      } else {
        setState(() {
          _supabaseResults = [];
          _osmResults = [];
        });
      }
    });
  }

  // 1. Сначала ищем в нашей базе Fixly (вдруг ОСИ уже создано)
  Future<void> _searchDatabase(String query) async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('buildings')
          .select('id, osi_name, address')
          .or('address.ilike.%$query%,osi_name.ilike.%$query%')
          .limit(5);

      setState(() => _supabaseResults = response);
      
      // Если в нашей базе ничего нет, ищем глобально через бесплатный OpenStreetMap
      if (_supabaseResults.isEmpty) {
        await _searchOpenStreetMap(query);
      }
    } catch (e) {
      debugPrint("Ошибка БД: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Бесплатный геокодинг (Поиск по всей карте Казахстана)
  Future<void> _searchOpenStreetMap(String query) async {
    // Ограничиваем поиск Казахстаном (countrycodes=kz)
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&countrycodes=kz&limit=5'
    );

    try {
      final response = await http.get(url, headers: {
        'Accept-Language': 'ru-RU,ru;q=0.9',
        // OSM требует указывать User-Agent для бесплатных запросов
        'User-Agent': 'FixlyApp/1.0' 
      });

      if (response.statusCode == 200) {
        setState(() {
          _osmResults = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Ошибка OSM: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text(
          "Поиск адреса", 
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(c),
          Expanded(child: _buildResultsList(c)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColors c) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: 'Например: Абылай Хана 30',
          hintStyle: TextStyle(color: c.textTertiary),
          prefixIcon: Icon(LucideIcons.search, color: c.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, color: c.textTertiary),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: c.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(AppColors c) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    // Показываем результаты из Supabase
    if (_supabaseResults.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _supabaseResults.length,
        itemBuilder: (ctx, i) {
          final b = _supabaseResults[i];
          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            onTap: () {
              // Возвращаем ID найденного здания и его адрес
              Navigator.pop(context, {
                'id': b['id'],
                'address': b['address'],
                'isNew': false
              });
            },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.building2, color: c.success, size: 28),
              title: Text(
                b['osi_name'] ?? 'ОСИ', 
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                b['address'] ?? '', 
                style: TextStyle(color: c.textSecondary, fontSize: 13)
              ),
              trailing: Icon(LucideIcons.chevronRight, color: c.textTertiary),
            ),
          );
        },
      );
    }

    // Показываем результаты из OSM
    if (_osmResults.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "ОСИ не найдено. Выберите адрес для создания нового:", 
              style: TextStyle(color: c.textSecondary, fontSize: 13)
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _osmResults.length,
              itemBuilder: (ctx, i) {
                final place = _osmResults[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () {
                    // Возвращаем полный адрес из OSM, чтобы создать новый дом
                    Navigator.pop(context, {
                      'id': null,
                      'address': place['display_name'],
                      'lat': place['lat'],
                      'lon': place['lon'],
                      'isNew': true
                    });
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(LucideIcons.mapPin, color: c.danger, size: 28),
                    title: Text(
                      place['display_name'] ?? 'Неизвестный адрес',
                      style: TextStyle(color: c.textPrimary, fontSize: 14),
                    ),
                    trailing: Icon(LucideIcons.plusCircle, color: c.primary),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Если ввели 3+ символа, но ничего не нашли
    if (_searchController.text.length >= 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.mapPinOff, size: 48, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              "Адрес не найден", 
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Text(
              "Попробуйте изменить запрос", 
              style: TextStyle(color: c.textSecondary),
            ),
          ],
        )
      );
    }

    return const SizedBox.shrink();
  }
}