import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/models/user_model.dart';
import 'package:fixly_app/screens/master_Detail_Page.dart';

class MastersListScreen extends StatefulWidget {
  const MastersListScreen({super.key});

  @override
  State<MastersListScreen> createState() => _MastersListScreenState();
}

class _MastersListScreenState extends State<MastersListScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<UserModel> _masters = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _selectedSpec;
  int _page = 0;
  static const _pageSize = 20;

  // Специализации
  static const _specs = {
    'Все': null,
    'Сантехник': 'plumber',
    'Электрик': 'electrician',
    'Отделка': 'painter',
    'Сварщик': 'welder',
    'Плотник': 'carpenter',
    'Замки/двери': 'locksmith',
  };
  static const _specsKz = {
    'Барлығы': null,
    'Сантехник': 'plumber',
    'Электрик': 'electrician',
    'Жөндеу': 'painter',
    'Дәнекерші': 'welder',
    'Ұстасы': 'carpenter',
    'Слесарь': 'locksmith',
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _load();
    }
  }

  // ── ЗАГРУЗКА (ИСПРАВЛЕННАЯ ЛОГИКА) ────────────────────────────
  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 0;
        _masters = [];
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      // 1. Инициализация и выбор полей (используем var для PostgrestFilterBuilder)
      var query = _supabase
          .from('profiles')
          .select('id, full_name, specialty, avatar_url, rating, reviews_count, '
              'price_from, experience_years, is_verified, is_available, description');

      // 2. Базовые фильтры (обязательные)
      query = query.eq('role', 'master').eq('is_verified', true);

      // 3. Динамические фильтры (специализация)
      if (_selectedSpec != null) {
        query = query.eq('specialty', _selectedSpec!);
      }

      // 4. Поиск по имени
      final searchText = _searchCtrl.text.trim();
      if (searchText.isNotEmpty) {
        query = query.ilike('full_name', '%$searchText%');
      }

      // 5. Сортировка и пагинация вызываются прямо перед await
      final response = await query
          .order('rating', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
      
      final loaded = (response as List<dynamic>)
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (reset) {
            _masters = loaded;
          } else {
            _masters.addAll(loaded);
          }
          _hasMore = loaded.length == _pageSize;
          _page++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('MastersListScreen load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final specs = lang == 'ru' ? _specs : _specsKz;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            title: Text(
              lang == 'ru' ? 'Мастера' : 'Шеберлер',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black87),
          ),
          body: Column(
            children: [
              // Поиск
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(reset: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: lang == 'ru' ? 'Поиск по имени...' : 'Аты бойынша іздеу...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _load(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              // Фильтры
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: specs.entries.map((entry) {
                    final isSelected = _selectedSpec == entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedSpec = entry.value);
                          _load(reset: true);
                        },
                        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
                        selectedColor: Colors.blueAccent,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Список
              Expanded(
                child: _isLoading
                    ? _buildSkeleton(isDark)
                    : _masters.isEmpty
                        ? _buildEmpty(lang)
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _masters.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == _masters.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                return _buildMasterCard(_masters[i], lang, isDark);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasterCard(UserModel master, String lang, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MasterDetailPage(masterData: master.toMap()),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(isDark ? 0.12 : 0.15)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  backgroundImage: (master.avatarUrl != null && master.avatarUrl!.isNotEmpty)
                      ? NetworkImage(master.avatarUrl!)
                      : null,
                  child: (master.avatarUrl == null || master.avatarUrl!.isEmpty)
                      ? Text(master.initials,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16))
                      : null,
                ),
                if (master.isAvailable)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          master.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (master.isVerified)
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_specLabel(master.specialty, lang),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 3),
                      Text(master.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(' (${master.reviewsCount})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (master.priceFrom != null) ...[
                        const SizedBox(width: 10),
                        Text('${lang == 'ru' ? 'от' : 'бастап'} ${master.priceFrom!.toInt()} ₸',
                            style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _specLabel(String? spec, String lang) {
    const ruMap = {'plumber': 'Сантехник', 'electrician': 'Электрик', 'painter': 'Отделочник', 'welder': 'Сварщик', 'carpenter': 'Плотник', 'locksmith': 'Слесарь'};
    const kzMap = {'plumber': 'Сантехник', 'electrician': 'Электрик', 'painter': 'Жөндеуші', 'welder': 'Дәнекерші', 'carpenter': 'Ұста', 'locksmith': 'Слесарь'};
    if (spec == null) return lang == 'ru' ? 'Специалист' : 'Маман';
    return (lang == 'ru' ? ruMap[spec] : kzMap[spec]) ?? (lang == 'ru' ? 'Специалист' : 'Маман');
  }

  Widget _buildSkeleton(bool isDark) {
    final shimColor = isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 30, backgroundColor: shimColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: shimColor, margin: const EdgeInsets.only(bottom: 6)),
                  Container(height: 12, width: 80, color: shimColor, margin: const EdgeInsets.only(bottom: 6)),
                  Container(height: 10, width: 100, color: shimColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.users, size: 64, color: Colors.grey.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text(lang == 'ru' ? 'Мастера не найдены' : 'Шебер табылмады',
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _selectedSpec = null);
              _load(reset: true);
            },
            child: Text(lang == 'ru' ? 'Сбросить фильтры' : 'Сүзгіні тазалау'),
          ),
        ],
      ),
    );
  }
}