import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/models/user_model.dart';
import 'package:fixly_app/screens/master_Detail_Page.dart';
import 'package:fixly_app/screens/create_order_page.dart';

// ============================================================
//  MarketScreen — маркет услуг
//  • Каталог специализаций с иконками
//  • При выборе — список мастеров данной специализации
//  • Быстрый переход на создание заявки с предвыбранной категорией
// ============================================================
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _supabase = Supabase.instance.client;

  String? _selectedSpec;
  List<UserModel> _masters     = [];
  bool    _isLoadingMasters    = false;

  static const _services = [
    ('plumber',     'Сантехник',     'Сантехник',     LucideIcons.droplets,    Color(0xFF3B82F6)),
    ('electrician', 'Электрик',      'Электрик',      LucideIcons.zap,          Color(0xFFF59E0B)),
    ('painter',     'Отделочник',    'Жөндеуші',      LucideIcons.paintbrush,   Color(0xFF8B5CF6)),
    ('carpenter',   'Плотник',       'Ұста',           LucideIcons.hammer,       Color(0xFF10B981)),
    ('welder',      'Сварщик',       'Дәнекерші',     LucideIcons.flame,        Color(0xFFEF4444)),
    ('locksmith',   'Слесарь',       'Слесарь',       LucideIcons.keyRound,     Color(0xFF6366F1)),
    ('cleaner',     'Уборщик',       'Тазалаушы',     LucideIcons.sparkles,     Color(0xFF06B6D4)),
    ('general',     'Другое',        'Басқа',          LucideIcons.wrench,       Color(0xFF64748B)),
  ];

  Future<void> _loadMasters(String spec) async {
    setState(() { _selectedSpec = spec; _isLoadingMasters = true; });
    try {
      final resp = await _supabase
          .from('profiles')
          .select('id, full_name, specialty, avatar_url, rating, reviews_count, price_from, is_verified, is_available, description, experience_years')
          .eq('role', 'master')
          .eq('is_verified', true)
          .eq('specialty', spec)
          .order('rating', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _masters = (resp as List)
              .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
              .toList();
          _isLoadingMasters = false;
        });
      }
    } catch (e) {
      debugPrint('MarketScreen: $e');
      if (mounted) setState(() => _isLoadingMasters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardBg  = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (_, lang, __) => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          title: Text(
            lang == 'ru' ? 'Маркет услуг' : 'Қызметтер маркеті',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
          ),
          centerTitle: true,
          leading: _selectedSpec != null
              ? IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () => setState(() {
                    _selectedSpec = null;
                    _masters = [];
                  }),
                )
              : null,
          iconTheme:
              IconThemeData(color: isDark ? Colors.white : Colors.black87),
        ),
        body: _selectedSpec == null
            ? _buildCatalog(lang, isDark, cardBg)
            : _buildMastersList(lang, isDark, cardBg),
      ),
    );
  }

  // ── КАТАЛОГ СПЕЦИАЛИЗАЦИЙ ─────────────────────────────────
  Widget _buildCatalog(String lang, bool isDark, Color cardBg) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount  : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing : 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _services.length,
      itemBuilder: (_, i) {
        final (key, ruLabel, kzLabel, icon, color) = _services[i];
        final label = lang == 'ru' ? ruLabel : kzLabel;
        return GestureDetector(
          onTap: () => _loadMasters(key),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: (color).withOpacity(0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  lang == 'ru' ? 'Найти мастера' : 'Шебер табу',
                  style: TextStyle(
                      fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── СПИСОК МАСТЕРОВ ───────────────────────────────────────
  Widget _buildMastersList(String lang, bool isDark, Color cardBg) {
    final spec    = _services.firstWhere(
        (s) => s.$1 == _selectedSpec,
        orElse: () => _services.last);
    final label   = lang == 'ru' ? spec.$2 : spec.$3;
    final color   = spec.$5;

    return Column(
      children: [
        // Шапка категории
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(spec.$4, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87)),
                    Text(
                      lang == 'ru'
                          ? 'Мастеров: ${_masters.length}'
                          : 'Шебер: ${_masters.length}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Создать заявку сразу
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateOrderPage(
                      initialCategory: _selectedSpec ?? '',
                    ),
                  ),
                ),
                child: Text(
                  lang == 'ru' ? 'Заявка' : 'Өтінім',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingMasters
              ? const Center(child: CircularProgressIndicator())
              : _masters.isEmpty
                  ? _buildEmpty(lang)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _masters.length,
                      itemBuilder: (_, i) =>
                          _buildMasterCard(_masters[i], lang, isDark, cardBg),
                    ),
        ),
      ],
    );
  }

  Widget _buildMasterCard(
      UserModel m, String lang, bool isDark, Color cardBg) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MasterDetailPage(masterData: m.toMap())),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  backgroundImage: (m.avatarUrl?.isNotEmpty == true)
                      ? NetworkImage(m.avatarUrl!) : null,
                  child: (m.avatarUrl?.isEmpty ?? true)
                      ? Text(m.initials,
                          style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15))
                      : null,
                ),
                if (m.isAvailable)
                  Positioned(
                    bottom: 1, right: 1,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m.fullName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (m.isVerified)
                        const Icon(Icons.verified,
                            color: Colors.blueAccent, size: 15),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 13, color: Colors.orange),
                      const SizedBox(width: 3),
                      Text(m.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(' (${m.reviewsCount})',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      if (m.priceFrom != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${lang == 'ru' ? 'от' : 'бастап'} ${m.priceFrom!.toInt()} ₸',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String lang) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users,
                size: 56, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 14),
            Text(
              lang == 'ru'
                  ? 'Мастеров не найдено'
                  : 'Шебер табылмады',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'ru'
                  ? 'Создайте заявку — мастера сами откликнутся'
                  : 'Өтінім жасаңыз — шеберлер хабарласады',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
}