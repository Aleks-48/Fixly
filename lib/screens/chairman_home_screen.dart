import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixly_app/screens/announcements_screen.dart';
import 'package:fixly_app/screens/create_order_page.dart';
import 'package:fixly_app/screens/documents_screen.dart';
import 'package:fixly_app/screens/orders_page.dart';
import 'package:fixly_app/screens/voting_page.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';
import 'package:fixly_app/screens/voting_list_screen.dart';
import 'package:fixly_app/screens/create_announcement_screen.dart';
import 'package:fixly_app/screens/chairman_building_selection_screen.dart';
class ChairmanHomeScreen extends StatefulWidget {
  const ChairmanHomeScreen({super.key});

  @override
  State<ChairmanHomeScreen> createState() => _ChairmanHomeScreenState();
}

class _ChairmanHomeScreenState extends State<ChairmanHomeScreen> {
  final _sb = Supabase.instance.client;
  final _money = NumberFormat.decimalPattern('ru');

  BuildingContext? _context;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final context = await BuildingContextService.loadCurrent();
      if (context == null || !context.hasBuilding) {
        if (mounted) {
          setState(() {
            _context = context;
            _tasks = [];
            _proposals = [];
            _announcements = [];
            _isLoading = false;
          });
        }
        return;
      }

      final buildingId = context.buildingId!;
      final tasksResp = await _sb
          .from('tasks')
          .select()
          .eq('building_id', buildingId)
          .order('created_at', ascending: false)
          .limit(20);
      final proposalsResp = await _sb
          .from('proposals')
          .select()
          .eq('building_id', buildingId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(5);
      final announcementsResp = await _sb
          .from('announcements')
          .select()
          .eq('building_id', buildingId)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _context = context;
          _tasks = List<Map<String, dynamic>>.from(tasksResp as List);
          _proposals = List<Map<String, dynamic>>.from(proposalsResp as List);
          _announcements =
              List<Map<String, dynamic>>.from(announcementsResp as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int get _activeTasks => _tasks
      .where((t) => t['status'] == 'new' || t['status'] == 'in_progress')
      .length;
  int get _criticalTasks => _tasks.where((t) => t['priority'] == 'high').length;
  double get _spent => _tasks.fold<double>(0, (sum, task) {
        final value = task['final_price'] ?? task['price'];
        if (value is num) return sum + value.toDouble();
        return sum + (double.tryParse(value?.toString() ?? '') ?? 0);
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101214) : const Color(0xFFF6F7F9);
    final card = isDark ? const Color(0xFF1B1F24) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 14),
                    if (_error != null) _buildError(card, isDark),
                    if (_context?.hasBuilding != true)
                      _buildNoBuilding(card, isDark),
                    if (_context?.hasBuilding == true) ...[
                      _buildKpiGrid(card, isDark),
                      const SizedBox(height: 14),
                      _buildQuickActions(card, isDark),
                      const SizedBox(height: 18),
                      _sectionTitle('Активные голосования', LucideIcons.vote),
                      const SizedBox(height: 8),
                      _proposals.isEmpty
                          ? _emptyLine('Нет активных голосований', card, isDark)
                          : Column(
                              children: _proposals
                                  .map((p) => _proposalCard(p, card, isDark))
                                  .toList(),
                            ),
                      const SizedBox(height: 18),
                      _sectionTitle(
                          'Критичные заявки', LucideIcons.alertTriangle),
                      const SizedBox(height: 8),
                      _criticalTasks == 0
                          ? _emptyLine('Критичных заявок нет', card, isDark)
                          : Column(
                              children: _tasks
                                  .where((t) => t['priority'] == 'high')
                                  .take(4)
                                  .map((t) => _taskCard(t, card, isDark))
                                  .toList(),
                            ),
                      const SizedBox(height: 18),
                      _sectionTitle(
                          'Последние объявления', LucideIcons.megaphone),
                      const SizedBox(height: 8),
                      _announcements.isEmpty
                          ? _emptyLine('Объявлений пока нет', card, isDark)
                          : Column(
                              children: _announcements
                                  .map(
                                      (a) => _announcementCard(a, card, isDark))
                                  .toList(),
                            ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final address = _context?.buildingAddress ?? 'Дом не выбран';
    final osi = _context?.osiName ?? 'Fixly ОСИ/НСУ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(LucideIcons.building2, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дом',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    osi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1F24) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE6E8EC),
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.mapPin,
                  color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildKpiGrid(Color card, bool isDark) {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.95,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
    children: [
      _kpi('Заявки', '$_activeTasks', LucideIcons.clipboardList,
          Colors.blueAccent, card, isDark),
      _kpi('Критично', '$_criticalTasks', LucideIcons.alertTriangle,
          Colors.redAccent, card, isDark),
      
      // Обернули в GestureDetector для быстрого перехода к списку
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VotingListScreen())),
        child: _kpi('Голосования', '${_proposals.length}', LucideIcons.vote,
            Colors.green, card, isDark),
      ),
      
      _kpi('Финансы', '${_money.format(_spent.round())} ₸',
          LucideIcons.wallet, Colors.orange, card, isDark),
    ],
  );
}

  Widget _kpi(
    String label,
    String value,
    IconData icon,
    Color color,
    Color card,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildQuickActions(Color card, bool isDark) {
  final actions = [
    _QuickAction(
        'Заявка',
        LucideIcons.wrench,
        Colors.blueAccent,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CreateOrderPage()))),
    _QuickAction(
        'Объявление',
        LucideIcons.megaphone,
        Colors.orange,
        // Восстановлен путь: ведем сразу на форму создания объявления
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CreateAnnouncementScreen()))),
    _QuickAction(
        'Голосование', 
        LucideIcons.vote, 
        Colors.green, 
        // Восстановлен путь: открываем полноценный менеджер голосований с FAB-кнопкой "Создать"
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VotingListScreen()))),
    _QuickAction(
        'Документ',
        LucideIcons.fileText,
        Colors.indigo,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DocumentsScreen()))),
  ];

  // ... остальная часть метода _buildQuickActions остается без изменений


    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE6E8EC)),
      ),
      child: Row(
        children: actions
            .map(
              (a) => Expanded(
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Icon(a.icon, color: a.color, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          a.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showProposalDialog() async {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '7');
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое голосование'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Вопрос'),
              autofocus: true,
            ),
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Пояснение'),
              maxLines: 2,
            ),
            TextField(
              controller: daysCtrl,
              decoration: const InputDecoration(labelText: 'Срок, дней'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                final row = await VotingService.createProposal(
                  title: titleCtrl.text,
                  description: descriptionCtrl.text,
                  days: int.tryParse(daysCtrl.text) ?? 7,
                );
                if (ctx.mounted) Navigator.pop(ctx, row);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
      );
      
    Future.delayed(const Duration(seconds: 1), () {
      titleCtrl.dispose();
      descriptionCtrl.dispose();
      daysCtrl.dispose();
    });

    if (created != null && mounted) {
      await _load();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VotingPage(
            proposalId: created['id'].toString(),
            proposalTitle: created['title']?.toString() ?? '',
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      );

  Widget _proposalCard(Map<String, dynamic> proposal, Color card, bool isDark) {
    final title = proposal['title']?.toString() ?? 'Без названия';
    final endAt = DateTime.tryParse(proposal['end_at']?.toString() ?? '');
    return _rowCard(
      card,
      isDark,
      icon: LucideIcons.vote,
      color: Colors.green,
      title: title,
      subtitle: endAt == null
          ? 'Активно'
          : 'До ${DateFormat('dd.MM.yyyy').format(endAt)}',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VotingPage(
            proposalId: proposal['id'].toString(),
            proposalTitle: title,
          ),
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, Color card, bool isDark) =>
      _rowCard(
        card,
        isDark,
        icon: LucideIcons.alertTriangle,
        color: Colors.redAccent,
        title: task['title']?.toString() ?? 'Заявка',
        subtitle: task['status']?.toString() ?? 'new',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        ),
      );

  Widget _announcementCard(Map<String, dynamic> ann, Color card, bool isDark) =>
      _rowCard(
        card,
        isDark,
        icon: LucideIcons.megaphone,
        color: ann['is_urgent'] == true ? Colors.redAccent : Colors.orange,
        title: ann['title']?.toString() ?? 'Объявление',
        subtitle: ann['content']?.toString() ?? '',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
        ),
      );

  Widget _rowCard(
    Color card,
    bool isDark, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE6E8EC),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
                    color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyLine(String text, Color card, bool isDark) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE6E8EC)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );

  // Раньше это был просто статичный текст без действия — председатель
  // видел "нет привязки к дому", но не мог ничего с этим сделать прямо
  // отсюда. Теперь кнопка ведёт на ChairmanBuildingSelectionScreen и
  // перезагружает дашборд после возврата.
  Widget _buildNoBuilding(Color card, bool isDark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Нет подтвержденной привязки к дому. Выберите или создайте дом, чтобы открыть управленческие функции.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChairmanBuildingSelectionScreen()),
                  );
                  _load();
                },
                icon: const Icon(LucideIcons.building2, size: 18, color: Colors.white),
                label: const Text('Выбрать дом',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildError(Color card, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
        ),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}