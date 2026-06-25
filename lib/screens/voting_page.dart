import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixly_app/services/building_context_service.dart';
import 'package:fixly_app/services/voting_service.dart';

class VotingPage extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;

  const VotingPage({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
  });

  @override
  State<VotingPage> createState() => _VotingPageState();
}

class _VotingPageState extends State<VotingPage> {
  final _sb = Supabase.instance.client;
  late final SignatureController _signatureController;
  StreamSubscription<List<Map<String, dynamic>>>? _votesSubscription;

  BuildingContext? _context;
  Map<String, dynamic>? _proposal;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _hasVoted = false;
  String? _error;
  String? _voteSelection;

  int _yesCount = 0;
  int _noCount = 0;
  int _abstainCount = 0;

  String _buildingId = '';
  String _buildingAddress = '';
  String _osiName = 'ОСИ/НСУ';
  int _totalApartments = 0;
  DateTime _votingStartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.blueAccent,
      exportBackgroundColor: Colors.white,
    );
    _initializeData();
  }

  @override
  void dispose() {
    _votesSubscription?.cancel();
    _signatureController.dispose();
    super.dispose();
  }

  String get _currentTitle =>
      _proposal?['title']?.toString() ??
      (widget.proposalTitle.isNotEmpty ? widget.proposalTitle : 'Голосование');

  String get _status => _proposal?['status']?.toString() ?? 'active';
  bool get _isActive => _status == 'active' || _proposal?['is_active'] == true;
  bool get _canVote =>
      !_hasVoted &&
      _isActive &&
      _context?.isVerifiedMember == true &&
      _context?.hasBuilding == true &&
      widget.proposalId.isNotEmpty;
  bool get _canGenerateProtocol => _context?.canManageHouse == true;

  Future<void> _initializeData() async {
    await _loadData();
    _setupRealtimeStats();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.proposalId.isEmpty) {
      setState(() {
        _error = 'Голосование не выбрано';
        _isLoading = false;
      });
      return;
    }

    try {
      final context = await BuildingContextService.loadCurrent();
      final proposal = await _sb
          .from('proposals')
          .select()
          .eq('id', widget.proposalId)
          .maybeSingle();

      if (proposal == null) {
        if (mounted) {
          setState(() {
            _context = context;
            _error = 'Голосование не найдено';
            _isLoading = false;
          });
        }
        return;
      }

      final proposalBuildingId = proposal['building_id']?.toString();
      if (context?.buildingId != null &&
          proposalBuildingId != null &&
          proposalBuildingId != context!.buildingId) {
        if (mounted) {
          setState(() {
            _context = context;
            _error = 'Нет доступа к голосованию другого дома';
            _isLoading = false;
          });
        }
        return;
      }

      _buildingId = proposalBuildingId ?? context?.buildingId ?? '';
      _buildingAddress = context?.buildingAddress ?? '';
      _osiName = context?.osiName ?? 'ОСИ/НСУ';
      _totalApartments = context?.totalApartments ?? 0;
      _votingStartDate = DateTime.tryParse(
            proposal['start_at']?.toString() ??
                proposal['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now();

      final hasVoted =
          await VotingService.hasCurrentUserVoted(widget.proposalId);
      if (mounted) {
        setState(() {
          _context = context;
          _proposal = Map<String, dynamic>.from(proposal);
          _hasVoted = hasVoted;
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

  void _setupRealtimeStats() {
    if (widget.proposalId.isEmpty) return;
    _votesSubscription = _sb
        .from('votes')
        .stream(primaryKey: ['id'])
        .eq('proposal_id', widget.proposalId)
        .listen((data) {
          var yes = 0;
          var no = 0;
          var abstain = 0;
          for (final vote in data) {
            final choice =
                vote['choice']?.toString() ?? vote['decision']?.toString();
            if (choice == 'yes') {
              yes++;
            } else if (choice == 'no') {
              no++;
            } else if (choice == 'abstain') {
              abstain++;
            }
          }
          if (mounted) {
            setState(() {
              _yesCount = yes;
              _noCount = no;
              _abstainCount = abstain;
            });
          }
        });
  }

  Future<void> _submitVote() async {
    if (_voteSelection == null || _signatureController.isEmpty) {
      _showSnackBar('Выберите вариант и поставьте подпись', Colors.orange);
      return;
    }

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null || signatureBytes.isEmpty) {
      _showSnackBar('Не удалось подготовить подпись', Colors.orange);
      return;
    }

    setState(() => _isUploading = true);
    try {
      await VotingService.submitVote(
        proposalId: widget.proposalId,
        choice: _voteSelection!,
        signatureBytes: signatureBytes,
      );
      if (!mounted) return;
      setState(() {
        _hasVoted = true;
        _isUploading = false;
      });
      _signatureController.clear();
      _showSnackBar('Голос засчитан', Colors.green);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      final message = e.toString().toLowerCase().contains('duplicate')
          ? 'Вы уже голосовали по этому вопросу'
          : e.toString();
      _showSnackBar(message, Colors.redAccent);
    }
  }

  Future<void> _generateOfficialProtocol() async {
    if (_buildingId.isEmpty) {
      _showSnackBar('Дом не определен', Colors.orange);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final participants = await _loadParticipants();
      final votes = await _sb
          .from('votes')
          .select()
          .eq('proposal_id', widget.proposalId)
          .eq('building_id', _buildingId);
      final voteMap = {
        for (final vote in votes as List) vote['user_id']?.toString(): vote,
      };

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(base: font, bold: bold),
          ),
          build: (ctx) => [
            pw.Center(
              child: pw.Text(
                'ПРОТОКОЛ ОНЛАЙН-ГОЛОСОВАНИЯ СОБСТВЕННИКОВ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('ОСИ/НСУ: $_osiName',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Адрес: $_buildingAddress'),
            pw.Text(
                'Дата начала: ${DateFormat('dd.MM.yyyy HH:mm').format(_votingStartDate)}'),
            pw.Text('Статус: ${_statusLabel(_status)}'),
            pw.Divider(),
            pw.Text(
              'ВОПРОС: $_currentTitle',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(45),
                1: pw.FlexColumnWidth(2),
                2: pw.FixedColumnWidth(80),
                3: pw.FixedColumnWidth(90),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColor(0.93, 0.94, 0.96)),
                  children: [
                    _cell('Кв.', bold, isHeader: true),
                    _cell('Собственник', bold, isHeader: true),
                    _cell('Решение', bold, isHeader: true),
                    _cell('Подпись', bold, isHeader: true),
                  ],
                ),
                for (final person in participants)
                  pw.TableRow(
                    children: [
                      _cell(person.apartmentNumber ?? '-', font),
                      _cell(person.fullName ?? 'Не указано', font),
                      _cell(
                          _choiceLabel(
                              voteMap[person.userId]?['choice']?.toString()),
                          font),
                      _cell(
                          voteMap[person.userId] == null
                              ? '-'
                              : 'ЭЦП/моб. подпись',
                          font),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'ИТОГИ: ЗА - $_yesCount, ПРОТИВ - $_noCount, ВОЗДЕРЖАЛИСЬ - $_abstainCount',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Явка: ${(_turnout * 100).toStringAsFixed(1)}%',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          'Protocol_${widget.proposalId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: fileName,
        );
      } else {
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      _showSnackBar('Ошибка PDF: $e', Colors.redAccent);
      debugPrint('PDF Gen Error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  pw.Widget _cell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<List<_Participant>> _loadParticipants() async {
    try {
      final members = await _sb
          .from('building_members')
          .select('user_id, apartment_number')
          .eq('building_id', _buildingId)
          .inFilter('verification_status', ['verified', 'approved']);
      final list = List<Map<String, dynamic>>.from(members as List);
      final userIds = list
          .map((m) => m['user_id']?.toString())
          .whereType<String>()
          .toList();
      final names = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await _sb
            .from('profiles')
            .select('id, full_name, name, first_name, last_name')
            .inFilter('id', userIds);
        for (final profile in profiles as List) {
          final row = Map<String, dynamic>.from(profile as Map);
          final id = row['id']?.toString();
          if (id != null) {
            names[id] = row['full_name']?.toString() ??
                row['name']?.toString() ??
                [row['first_name'], row['last_name']]
                    .where((p) => p != null && p.toString().isNotEmpty)
                    .join(' ');
          }
        }
      }
      return list
          .map(
            (m) => _Participant(
              userId: m['user_id']?.toString() ?? '',
              apartmentNumber: m['apartment_number']?.toString(),
              fullName: names[m['user_id']?.toString()],
            ),
          )
          .where((p) => p.userId.isNotEmpty)
          .toList();
    } catch (_) {
      final profiles = await _sb
          .from('profiles')
          .select(
              'id, full_name, name, first_name, last_name, apartment_number, apartment')
          .eq('building_id', _buildingId);
      return (profiles as List)
          .map((profile) {
            final row = Map<String, dynamic>.from(profile as Map);
            return _Participant(
              userId: row['id']?.toString() ?? '',
              apartmentNumber: row['apartment_number']?.toString() ??
                  row['apartment']?.toString(),
              fullName: row['full_name']?.toString() ??
                  row['name']?.toString() ??
                  [row['first_name'], row['last_name']]
                      .where((p) => p != null && p.toString().isNotEmpty)
                      .join(' '),
            );
          })
          .where((p) => p.userId.isNotEmpty)
          .toList();
    }
  }

  double get _turnout {
    final totalVotes = _yesCount + _noCount + _abstainCount;
    final denominator = math.max(1, _totalApartments);
    return totalVotes / denominator;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101214) : const Color(0xFFF6F7F9);
    final card = isDark ? const Color(0xFF1B1F24) : Colors.white;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          _osiName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_error != null)
              _message(_error!, Colors.redAccent, card, isDark)
            else ...[
              _questionCard(card, isDark),
              const SizedBox(height: 12),
              _statsCard(card, isDark),
              const SizedBox(height: 12),
              if (_canVote)
                _votingForm(card, isDark)
              else
                _message(
                  _hasVoted
                      ? 'Вы уже проголосовали по этому вопросу'
                      : _isActive
                          ? 'Голосование доступно только подтвержденным жильцам дома'
                          : 'Голосование закрыто',
                  _hasVoted ? Colors.green : Colors.orange,
                  card,
                  isDark,
                ),
              if (_canGenerateProtocol) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _generateOfficialProtocol,
                    icon: const Icon(LucideIcons.fileText),
                    label: const Text('Скачать протокол PDF'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _questionCard(Color card, bool isDark) {
    final endAt = DateTime.tryParse(_proposal?['end_at']?.toString() ?? '');
    return _card(
      card,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusPill(_status),
              const Spacer(),
              Text(
                DateFormat('dd.MM.yyyy').format(_votingStartDate),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentTitle,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((_proposal?['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _proposal!['description'].toString(),
              style: const TextStyle(color: Colors.grey, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _buildingAddress.isEmpty
                      ? 'Адрес дома не указан'
                      : _buildingAddress,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          if (endAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.clock, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Срок до ${DateFormat('dd.MM.yyyy HH:mm').format(endAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsCard(Color card, bool isDark) {
    return _card(
      card,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.activity, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text('Явка и решения',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCol('За', _yesCount, Colors.green),
              _statCol('Против', _noCount, Colors.redAccent),
              _statCol('Воздерж.', _abstainCount, Colors.orange),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _turnout.clamp(0, 1),
            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE6E8EC),
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          Text(
            'Проголосовало ${(_turnout * 100).toStringAsFixed(1)}% квартир',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _votingForm(Color card, bool isDark) {
    return _card(
      card,
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ваш голос',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              _voteOption('yes', 'За', Colors.green),
              const SizedBox(width: 8),
              _voteOption('no', 'Против', Colors.redAccent),
              const SizedBox(width: 8),
              _voteOption('abstain', 'Воздерж.', Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Подпись',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6E8EC)),
            ),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.transparent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: _signatureController.clear,
                icon: const Icon(LucideIcons.eraser, size: 16),
                label: const Text('Очистить'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _submitVote,
                icon:
                    const Icon(LucideIcons.send, color: Colors.white, size: 16),
                label: const Text('Отправить голос'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(Color card, bool isDark, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE6E8EC)),
        ),
        child: child,
      );

  Widget _message(String text, Color color, Color card, bool isDark) => _card(
        card,
        isDark,
        child: Row(
          children: [
            Icon(LucideIcons.info, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );

  Widget _statCol(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      );

  Widget _voteOption(String key, String label, Color color) {
    final selected = _voteSelection == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _voteSelection = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = status == 'closed'
        ? Colors.grey
        : status == 'draft'
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

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

  String _choiceLabel(String? choice) {
    switch (choice) {
      case 'yes':
        return 'ЗА';
      case 'no':
        return 'ПРОТИВ';
      case 'abstain':
        return 'ВОЗДЕРЖ.';
      default:
        return 'Не голосовал';
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}

class _Participant {
  const _Participant({
    required this.userId,
    this.apartmentNumber,
    this.fullName,
  });

  final String userId;
  final String? apartmentNumber;
  final String? fullName;
}
