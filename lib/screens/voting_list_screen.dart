import 'package:fixly_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:fixly_app/screens/voting_page.dart';
import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';
import 'package:fixly_app/utils/app_texts.dart';
import 'package:fixly_app/utils/app_error_handler.dart';
import 'package:fixly_app/services/notification_service.dart';
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

  // Эко-палитра "Шалфей и Песок" для статусов и акцентов
  static const _sageColor = Color(0xFF738B77);  // Шалфей (активно / основные действия)
  static const _sandColor = Color(0xFFD1BFA7);  // Песок (черновик)
  static const _stoneGray = Color(0xFF9E9B98);  // Теплый камень (закрыто)
  static const _dustyTaupe = Color(0xFF8C857B); // Пыльный тауп (в архиве)

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
                icon: const Icon(LucideIcons.plusCircle, color: _sageColor),
              ),
          ],
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                onPressed: _showCreateDialog,
                backgroundColor: _sageColor,
                child: const Icon(LucideIcons.plus, color: Colors.white),
              )
            : null,
        body: RefreshIndicator(
          color: _sageColor,
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
              selectedColor: _sageColor.withOpacity(0.2),
              checkmarkColor: _sageColor,
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

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CreateVotingDialog(lang: lang),
    );

    if (created != null && mounted) {
      try {
        final contextData = await BuildingContextService.loadCurrent();
        if (contextData?.buildingId != null) {
          await NotificationService.notifyBuilding(
            buildingId: contextData!.buildingId!,
            title: AppTexts.get('new_voting', lang),
            body: created['title']?.toString() ?? '',
          );
        }
      } catch (e) {
        debugPrint('Ошибка отправки уведомления: $e');
      }

      await _load();

      if (mounted) {
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
        return _sandColor;    // Песочный цвет для черновиков
      case 'closed':
        return _stoneGray;    // Мягкий серый камень
      case 'archived':
        return _dustyTaupe;   // Природный пыльный тауп
      default:
        return _sageColor;    // Шалфейный для активных
    }
  }
}

class _CreateVotingDialog extends StatefulWidget {
  final String lang;
  const _CreateVotingDialog({required this.lang});

  @override
  State<_CreateVotingDialog> createState() => _CreateVotingDialogState();
}

class _CreateVotingDialogState extends State<_CreateVotingDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _daysCtrl;
  bool _isSubmitting = false;

  static const _sageAccent = Color(0xFF738B77);

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _daysCtrl = TextEditingController(text: '7');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final titleText = _titleCtrl.text.trim();
    if (titleText.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final row = await VotingService.createProposal(
        title: titleText,
        description: _descriptionCtrl.text.trim(),
        days: int.tryParse(_daysCtrl.text.trim()) ?? 7,
      );
      if (mounted) {
        Navigator.pop(context, row);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final dialogBg = isDark ? const Color(0xFF1B1F24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    return AlertDialog(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppTexts.get('new_voting', widget.lang),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                labelText: AppTexts.get('voting_question', widget.lang),
                labelStyle: TextStyle(color: subColor, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _sageAccent),
                ),
              ),
              autofocus: true,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                labelText: AppTexts.get('voting_description', widget.lang),
                labelStyle: TextStyle(color: subColor, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _sageAccent),
                ),
              ),
              maxLines: 2,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysCtrl,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                labelText: AppTexts.get('voting_days', widget.lang),
                labelStyle: TextStyle(color: subColor, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _sageAccent),
                ),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(
            AppTexts.get('cancel', widget.lang),
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _sageAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  AppTexts.get('create', widget.lang),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}