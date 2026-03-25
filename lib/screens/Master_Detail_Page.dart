import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixly_app/screens/ai_chat_screen.dart';
import 'package:fixly_app/screens/chat_screen.dart';

class MasterDetailPage extends StatefulWidget {
  final Map<String, dynamic> masterData;

  const MasterDetailPage({super.key, required this.masterData});

  @override
  State<MasterDetailPage> createState() => _MasterDetailPageState();
}

class _MasterDetailPageState extends State<MasterDetailPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _portfolioItems = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadPortfolio(),
      _loadReviews(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPortfolio() async {
    try {
      final data = await supabase
          .from('portfolio')
          .select('*')
          .eq('master_id', widget.masterData['id']);
      if (mounted) _portfolioItems = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Ошибка загрузки портфолио: $e");
    }
  }

  Future<void> _loadReviews() async {
    try {
      final data = await supabase
          .from('reviews')
          .select('*, profiles(full_name, avatar_url)')
          .eq('master_id', widget.masterData['id'])
          .order('created_at', ascending: false);
      if (mounted) _reviews = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Ошибка загрузки отзывов: $e");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _showCallSimulation(String title, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5), width: 2)),
              child: CircleAvatar(
                radius: 70,
                backgroundImage: widget.masterData['avatar_url'] != null ? NetworkImage(widget.masterData['avatar_url']) : null,
                child: widget.masterData['avatar_url'] == null ? const Icon(LucideIcons.user, size: 70) : null,
              ),
            ),
            const SizedBox(height: 30),
            Text(widget.masterData['name'] ?? "Мастер", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: color, fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w500)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _callActionButton(LucideIcons.micOff, Colors.white10),
                const SizedBox(width: 20),
                _callActionButton(LucideIcons.phoneOff, Colors.redAccent, isEndCall: true),
                const SizedBox(width: 20),
                _callActionButton(LucideIcons.videoOff, Colors.white10),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _callActionButton(IconData icon, Color bg, {bool isEndCall = false}) {
    return GestureDetector(
      onTap: () => isEndCall ? Navigator.pop(context) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  void _openChat() {
    final myId = supabase.auth.currentUser?.id;
    final masterId = widget.masterData['id'].toString();
    final masterName = widget.masterData['name'] ?? "Мастер";
    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Пожалуйста, войдите в аккаунт")));
      return;
    }
    final String generatedChatId = "chat_${myId.substring(0, 8)}_${masterId.substring(0, 8)}";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          taskId: generatedChatId,
          taskTitle: "Чат с мастером",
          receiverId: masterId,
          receiverName: masterName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgBlack = Color(0xFF0F0F10);
    const Color cardGrey = Color(0xFF1C1C1E);
    const Color accentBlue = Color(0xFF3B82F6);

    final String name = widget.masterData['name'] ?? "Мастер";
    final String spec = widget.masterData['specialization'] ?? "Специалист";
    final double rating = (widget.masterData['avg_rating'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: bgBlack,
      body: FadeTransition(
        opacity: _fadeController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: bgBlack,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black38,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2563EB), bgBlack]),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Hero(
                          tag: widget.masterData['id'] ?? 'avatar',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: cardGrey,
                              backgroundImage: widget.masterData['avatar_url'] != null ? NetworkImage(widget.masterData['avatar_url']) : null,
                              child: widget.masterData['avatar_url'] == null ? const Icon(LucideIcons.user, size: 55, color: Colors.white24) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(spec, style: const TextStyle(color: accentBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildContactAction(LucideIcons.phone, "Аудио", () => _showCallSimulation("Входящий вызов...", LucideIcons.phone, Colors.greenAccent)),
                        _buildContactAction(LucideIcons.video, "Видео", () => _showCallSimulation("Запуск трансляции...", LucideIcons.video, accentBlue)),
                        _buildContactAction(LucideIcons.messageSquare, "Чат", _openChat),
                        _buildContactAction(LucideIcons.sparkles, "AI Помощь", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AIChatScreen()))),
                      ],
                    ),
                    const SizedBox(height: 35),
                    _buildStatsRow(rating),
                    const SizedBox(height: 35),
                    _buildSectionTitle("О МАСТЕРЕ"),
                    Text(
                      widget.masterData['bio'] ?? "Профессиональный мастер с большим опытом работы. Гарантирую качество, соблюдение сроков и чистоту на объекте. Работаю с современными материалами и оборудованием.",
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                    ),
                    const SizedBox(height: 35),
                    _buildSectionTitle("ПОРТФОЛИО"),
                    _buildPortfolioGrid(accentBlue, cardGrey),
                    const SizedBox(height: 35),
                    
                    // БЛОК ОТЗЫВОВ
                    _buildSectionTitle("ОТЗЫВЫ"),
ExpansionTile(
  title: const Text("Отзывы клиентов", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
  backgroundColor: Colors.transparent, // Убираем лишний фон
  collapsedBackgroundColor: Colors.transparent,
  iconColor: Colors.blueAccent, // Цвет стрелочки при открытии
  collapsedIconColor: Colors.white54, // Цвет стрелочки при закрытии
  childrenPadding: const EdgeInsets.only(top: 10),
  children: _reviews.isEmpty 
    ? [const Padding(padding: EdgeInsets.all(20), child: Text("Пока отзывов нет", style: TextStyle(color: Colors.white30)))]
    : _reviews.map((review) => _buildReviewItem(
        review['profiles']?['full_name'] ?? "Клиент", 
        review['comment'] ?? "", 
        (review['rating'] ?? 0).toDouble()
      )).toList(),
),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(accentBlue, bgBlack),
    );
  }

  Widget _buildPortfolioGrid(Color accent, Color card) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    if (_portfolioItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [Icon(LucideIcons.imageOff, color: Colors.white24, size: 40), SizedBox(height: 10), Text("Портфолио пусто", style: TextStyle(color: Colors.white38))]),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
      itemCount: _portfolioItems.length,
      itemBuilder: (context, index) => _buildWorkItem(_portfolioItems[index]['image_url'], _portfolioItems[index]['type'] == 'video'),
    );
  }

  Widget _buildContactAction(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

Widget _buildWorkItem(String url, bool isVideo) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.network(
      url,
      fit: BoxFit.cover,
      // ЭТО РЕШЕНИЕ ПРОБЛЕМЫ:
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.white10,
          child: const Center(
            child: Icon(LucideIcons.imageOff, color: Colors.white24, size: 30),
          ),
        );
      },
    ),
  );
}

  Widget _buildStatsRow(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(rating.toString(), "Рейтинг", LucideIcons.star, Colors.orangeAccent),
          _stat("48", "Работ", LucideIcons.briefcase, Colors.blueAccent),
          _stat("99%", "Успех", LucideIcons.checkCircle, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _stat(String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

Widget _buildReviewItem(String user, String text, double r) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04), // Мягкая прозрачная подложка
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.05)), // Едва заметная рамка
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14, 
                  backgroundColor: Colors.white12, 
                  child: Icon(LucideIcons.user, size: 14, color: Colors.white54)
                ),
                const SizedBox(width: 8),
                Text(user, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 12), 
                  Text(" $r", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
                ]
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
      ],
    ),
  );
}

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
    );
  }

  Widget _buildBottomAction(Color accent, Color bg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: accent, minimumSize: const Size(double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Запрос отправлен!"))),
        child: const Text("ЗАКАЗАТЬ УСЛУГУ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ),
    );
  }
}