import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fixly_app/screens/voting_page.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';

class VotingListScreen extends StatefulWidget {
  const VotingListScreen({super.key});

  @override
  State<VotingListScreen> createState() => _VotingListScreenState();
}

class _VotingListScreenState extends State<VotingListScreen> {
  String _status = 'active';
  bool _isLoading = true;
  bool _canCreate = false;
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final context = await BuildingContextService.loadCurrent();
      final items = await VotingService.listForCurrentBuilding(status: _status);
      if (mounted) {
        setState(() {
          _canCreate = context?.canManageHouse == true;
          _items = items;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101214) : const Color(0xFFF6F7F9);
    final card = isDark ? const Color(0xFF1B1F24) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Голосования',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_canCreate)
            IconButton(
              tooltip: 'Создать голосование',
              onPressed: _showCreateDialog,
              icon: const Icon(LucideIcons.plusCircle),
            ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: Colors.blueAccent,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _statusBar(),
            const SizedBox(height: 12),
            if (_error != null)
              _message(_error!, Colors.redAccent, card, isDark)
            else if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              _message(
                  'По этому фильтру голосований нет', Colors.grey, card, isDark)
            else
              ..._items.map((item) => _voteCard(item, card, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _statusBar() {
    final filters = {
      'active': 'Активные',
      'draft': 'Черновики',
      'closed': 'Закрытые',
      'all': 'Все',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = _status == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _status = entry.key);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _voteCard(Map<String, dynamic> item, Color card, bool isDark) {
    final title = item['title']?.toString() ?? 'Без названия';
    final status = item['status']?.toString() ?? 'active';
    final endAt = DateTime.tryParse(item['end_at']?.toString() ?? '');
    final subtitle = endAt == null
        ? _statusLabel(status)
        : '${_statusLabel(status)} · до ${DateFormat('dd.MM.yyyy').format(endAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VotingPage(
                proposalId: item['id'].toString(),
                proposalTitle: title,
              ),
            ),
          ).then((_) => _load()),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE6E8EC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.vote, color: _statusColor(status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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

  Future<void> _showCreateDialog() async {
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
              decoration: const InputDecoration(labelText: 'Описание'),
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
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
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

    titleCtrl.dispose();
    descriptionCtrl.dispose();
    daysCtrl.dispose();

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

  Widget _message(String text, Color color, Color card, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(text, style: TextStyle(color: color)),
      );

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'closed':
        return 'Закрыто';
      case 'archived':
        return 'Архив';
      default:
        return 'Активно';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      case 'archived':
        return Colors.blueGrey;
      default:
        return Colors.green;
    }
  }
}
