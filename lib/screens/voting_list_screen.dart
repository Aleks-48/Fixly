import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fixly_app/screens/voting_page.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';
import 'package:fixly_app/utils/app_texts.dart';
import 'package:fixly_app/utils/app_error_handler.dart';
import 'package:fixly_app/services/notification_service.dart';
import 'package:fixly_app/widgets/app_shimmer.dart';
import 'package:fixly_app/main.dart';

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
      final ctx = await AppErrorHandler.withRetry(
        () => BuildingContextService.loadCurrent(),
      );
      final items = await AppErrorHandler.withRetry(
        () => VotingService.listForCurrentBuilding(status: _status),
      );
      if (mounted) {
        setState(() {
          _canCreate = ctx?.canManageHouse == true;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.getMessage(e, appLanguage.value);
          _isLoading = false;
        });
        AppErrorHandler.show(context, e, onRetry: _load);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101214) : const Color(0xFFF6F7F9);
    final card = isDark ? const Color(0xFF1B1F24) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (_, lang, __) => Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: card,
          elevation: 0,
          title: Text(
            AppTexts.get('votings', lang),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (_canCreate)
              IconButton(
                tooltip: AppTexts.get('create_voting', lang),
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
              _statusBar(lang),
              const SizedBox(height: 12),
              if (_error != null)
                _message(_error!, Colors.redAccent, card, isDark)
              else if (_isLoading)
                ...List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppShimmer.announcementCard(context),
                ))
              else if (_items.isEmpty)
                _message(
                    AppTexts.get('no_votings', lang), Colors.grey, card, isDark)
              else
                ..._items.map((item) => _voteCard(item, card, isDark, lang)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBar(String lang) {
    final filters = {
      'active': AppTexts.get('filter_active', lang),
      'draft': AppTexts.get('filter_draft', lang),
      'closed': AppTexts.get('filter_closed', lang),
      'all': AppTexts.get('filter_all', lang),
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

  Widget _voteCard(Map<String, dynamic> item, Color card, bool isDark, String lang) {
    final title = item['title']?.toString() ?? AppTexts.get('no_title', lang);
    final status = item['status']?.toString() ?? 'active';
    final endAt = DateTime.tryParse(item['end_at']?.toString() ?? '');
    final subtitle = endAt == null
        ? _statusLabel(status, lang)
        : '${_statusLabel(status, lang)} · ${AppTexts.get('until', lang)} ${DateFormat('dd.MM.yyyy').format(endAt)}';

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
                            const TextStyle(color: Colors.grey, fontSize: 14),
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
    final lang = appLanguage.value;
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '7');

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTexts.get('new_voting', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: AppTexts.get('voting_question', lang)),
              autofocus: true,
            ),
            TextField(
              controller: descriptionCtrl,
              decoration: InputDecoration(labelText: AppTexts.get('voting_description', lang)),
              maxLines: 2,
            ),
            TextField(
              controller: daysCtrl,
              decoration: InputDecoration(labelText: AppTexts.get('voting_days', lang)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppTexts.get('cancel', lang))),
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
                
                // Получаем ID дома из сервиса
                final contextData = await BuildingContextService.loadCurrent();
                if (contextData?.buildingId != null) {
                  NotificationService.notifyBuilding(
                    buildingId: contextData!.buildingId!,
                    title: AppTexts.get('new_voting', lang),
                    body: titleCtrl.text,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text(AppTexts.get('create', lang)),
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

  String _statusLabel(String status, String lang) {
    switch (status) {
      case 'draft':
        return AppTexts.get('status_draft', lang);
      case 'closed':
        return AppTexts.get('status_closed', lang);
      case 'archived':
        return AppTexts.get('status_archived', lang);
      default:
        return AppTexts.get('status_active', lang);
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