import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/chat_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';

class MasterDetailPage extends StatefulWidget {
  final Map<String, dynamic> masterData;

  const MasterDetailPage({super.key, required this.masterData});

  @override
  State<MasterDetailPage> createState() => _MasterDetailPageState();
}

class _MasterDetailPageState extends State<MasterDetailPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _portfolioItems = [];
  List<Map<String, dynamic>> _reviews        = [];
  bool   _isLoading      = true;
  int    _ordersCount    = 0;   // реальное кол-во завершённых заказов
  double _avgRating      = 0.0; // среднее из отзывов
  String _experienceText = '';  // из profiles.experience_years

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── ЗАГРУЗКА ДАННЫХ ────────────────────────────────────────
  Future<void> _loadData() async {
    final masterId = widget.masterData['id']?.toString() ?? '';
    if (masterId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        // Портфолио
        _supabase
            .from('portfolio')
            .select('image_url, title, description')
            .eq('master_id', masterId)
            .limit(10),
        // Отзывы — сначала новые
        _supabase
            .from('reviews')
            .select('rating, comment, created_at, profiles(full_name, avatar_url)')
            .eq('master_id', masterId)
            .order('created_at', ascending: false)
            .limit(20),
        // Количество завершённых заказов
        _supabase
            .from('tasks')
            .select('id')
            .eq('master_id', masterId)
            .eq('status', 'completed'),
      ]);

      final portfolio = List<Map<String, dynamic>>.from(results[0] as List);
      final reviews   = List<Map<String, dynamic>>.from(results[1] as List);
      final orders    = results[2] as List;

      // Среднее рейтинга из реальных отзывов
      double avgRating = 0;
      if (reviews.isNotEmpty) {
        final sum = reviews.fold<double>(
            0, (acc, r) => acc + ((r['rating'] as num?)?.toDouble() ?? 0));
        avgRating = sum / reviews.length;
      } else {
        // Fallback из профиля
        avgRating = (widget.masterData['rating'] as num?)?.toDouble() ?? 5.0;
      }

      // Опыт
      final expYears = widget.masterData['experience_years'] as int?;
      final lang = appLanguage.value;
      String expText = expYears != null
          ? '$expYears ${lang == 'ru' ? 'лет' : 'жыл'}'
          : (lang == 'ru' ? 'Новый' : 'Жаңа');

      if (mounted) {
        setState(() {
          _portfolioItems = portfolio;
          _reviews        = reviews;
          _ordersCount    = orders.length;
          _avgRating      = avgRating;
          _experienceText = expText;
          _isLoading      = false;
        });
      }
    } catch (e) {
      debugPrint('MasterDetailPage load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(
        scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF4361EE);
    final bgColor   = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        _buildAppBar(),
                        SliverToBoxAdapter(
                          child: FadeTransition(
                            opacity: _fadeController,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildNameRow(lang, isDark),
                                  const SizedBox(height: 24),
                                  _buildStatsRow(lang, isDark),
                                  const SizedBox(height: 24),
                                  _buildAbout(lang, isDark),
                                  const SizedBox(height: 24),
                                  _buildPortfolio(lang),
                                  const SizedBox(height: 24),
                                  _buildReviews(lang, isDark),
                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Кнопка "Заказать" только для жителей
                    if (userRole.value == 'resident')
                      _buildBottomAction(accentColor, isDark, lang),
                  ],
                ),
        );
      },
    );
  }

  // ── APPBAR С ФОТО ──────────────────────────────────────────
  Widget _buildAppBar() {
    final avatarUrl = widget.masterData['avatar_url']?.toString();
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade800),
                  )
                : Container(color: Colors.grey.shade800,
                    child: const Icon(LucideIcons.user,
                        size: 80, color: Colors.white38)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ИМЯ + КНОПКИ ЗВОНОК/ЧАТ ───────────────────────────────
  Widget _buildNameRow(String lang, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.masterData['full_name']?.toString() ?? 'Мастер',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.masterData['specialty']?.toString() ??
                    (lang == 'ru' ? 'Специалист' : 'Маман'),
                style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),
        _iconBtn(
          LucideIcons.phone,
          Colors.green,
          () => _makePhoneCall(
              widget.masterData['phone']?.toString()),
        ),
        const SizedBox(width: 10),
        _iconBtn(
          LucideIcons.messageSquare,
          Colors.blueAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                receiverId:   widget.masterData['id']?.toString() ?? '',
                receiverName: widget.masterData['full_name']?.toString() ?? '',
                taskId:    '',
                taskTitle: '',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ── СТАТИСТИКА (РЕАЛЬНАЯ из БД) ────────────────────────────
  Widget _buildStatsRow(String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            _avgRating.toStringAsFixed(1),
            lang == 'ru' ? 'Рейтинг' : 'Рейтинг',
            LucideIcons.star,
            Colors.orange,
          ),
          _divider(),
          _statItem(
            '$_ordersCount',
            lang == 'ru' ? 'Заказов' : 'Тапсырыс',
            LucideIcons.checkCircle,
            Colors.green,
          ),
          _divider(),
          _statItem(
            _experienceText,
            lang == 'ru' ? 'Опыт' : 'Тәжірибе',
            LucideIcons.award,
            Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 40,
        width: 0.5,
        color: Colors.grey.withOpacity(0.3),
      );

  Widget _statItem(
      String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(val,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label,
            style:
                const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  // ── О МАСТЕРЕ ──────────────────────────────────────────────
  Widget _buildAbout(String lang, bool isDark) {
    final bio = widget.masterData['description']?.toString() ??
        widget.masterData['bio']?.toString() ??
        (lang == 'ru'
            ? 'Опытный специалист по ремонту и обслуживанию.'
            : 'Тәжірибелі жөндеу маманы.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            lang == 'ru' ? 'О мастере' : 'Маман туралы'),
        const SizedBox(height: 10),
        Text(
          bio,
          style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.6,
              fontSize: 14),
        ),
      ],
    );
  }

  // ── ПОРТФОЛИО ──────────────────────────────────────────────
  Widget _buildPortfolio(String lang) {
    if (_portfolioItems.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            lang == 'ru' ? 'Примеры работ' : 'Жұмыс мысалдары'),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _portfolioItems.length,
            itemBuilder: (context, i) {
              final url = _portfolioItems[i]['image_url']?.toString();
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.grey.shade300,
                ),
                clipBehavior: Clip.antiAlias,
                child: url != null && url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.grey),
                      )
                    : const Icon(LucideIcons.image,
                        color: Colors.grey),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── ОТЗЫВЫ ─────────────────────────────────────────────────
  Widget _buildReviews(String lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle(
                lang == 'ru' ? 'Отзывы' : 'Пікірлер'),
            Text(
              '${_reviews.length}',
              style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _reviews.isEmpty
            ? Text(
                lang == 'ru'
                    ? 'Отзывов пока нет'
                    : 'Пікірлер әлі жоқ',
                style: const TextStyle(color: Colors.grey),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                itemBuilder: (context, i) =>
                    _reviewCard(_reviews[i], isDark),
              ),
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> rev, bool isDark) {
    final profile   = (rev['profiles'] as Map<String, dynamic>?) ?? {};
    final avatarUrl = profile['avatar_url']?.toString();
    final name      = profile['full_name']?.toString() ?? 'Клиент';
    final rating    = (rev['rating'] as num?)?.toInt() ?? 5;
    final comment   = rev['comment']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                onBackgroundImageError:
                    avatarUrl != null ? (_, __) {} : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
              ),
              Row(
                children: List.generate(
                  5,
                  (j) => Icon(
                    Icons.star,
                    size: 13,
                    color: j < rating ? Colors.orange : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold),
      );

  // ── КНОПКА "ЗАКАЗАТЬ" (только для жителей) ─────────────────
  Widget _buildBottomAction(
      Color accent, bool isDark, String lang) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F0F10)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateOrderPage(
                masterId:        widget.masterData['id']?.toString() ?? '',
                masterName:      widget.masterData['full_name']?.toString() ?? '',
                initialCategory: widget.masterData['specialty']?.toString() ?? '', prefillDescription: '',
              ),
            ),
          ),
          child: Text(
            lang == 'ru'
                ? 'ЗАКАЗАТЬ УСЛУГУ'
                : 'ҚЫЗМЕТКЕ ТАПСЫРЫС БЕРУ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}