import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/utils/app_texts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Нужно для проверки на веб-сайт
import 'package:fixly_app/services/voting_service.dart';
import 'package:fixly_app/services/profile_service.dart';
import 'package:fixly_app/services/building_service.dart';
import 'package:fixly_app/theme/app_theme.dart';
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

class _VotingPageState extends State<VotingPage> with TickerProviderStateMixin {
  late SignatureController _signatureController;
  StreamSubscription<List<Map<String, dynamic>>>? _votesSubscription;
  
  bool _isUploading    = false;
  bool _isChairman     = false;
  bool _isLoadingRole  = true;
  bool _hasVoted       = false;
  bool _showVoteForm   = false; // Для председателя, чтобы вызвать форму голосования

  String? _voteSelection;
  late String _currentTitle;
  DateTime _votingStartDate = DateTime.now();

  int _yesCount = 0, _noCount = 0, _abstainCount = 0;
  String _buildingId = '', _buildingAddress = '', _osiName = '';
  int _totalApartments = 0;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.proposalTitle;
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.blueAccent,
      exportBackgroundColor: Colors.white,
    );
    _initializeData();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _votesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _checkUserRole();
    _setupRealtimeStats();
  }

  // ── ЖИВАЯ СТАТИСТИКА ──────────────────────────────────────
  void _setupRealtimeStats() {
    _votesSubscription = Supabase.instance.client
        .from('votes')
        .stream(primaryKey: ['id'])
        .eq('proposal_id', widget.proposalId)
        .listen((data) {
      int yes = 0, no = 0, abstain = 0;
      for (final v in data) {
        final c = v['choice'] as String? ?? '';
        if (c == 'yes') yes++;
        else if (c == 'no') no++;
        else if (c == 'abstain') abstain++;
      }
      if (mounted) {
        setState(() {
          _yesCount = yes; _noCount = no; _abstainCount = abstain;
        });
      }
    });
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profileModel = await ProfileService.getById(user.id);
    final vote = await VotingService.getUserVote(proposalId: widget.proposalId, userId: user.id);
    
    // Получаем детали ОСИ и здания
    if (profileModel != null && profileModel.buildingId != null) {
      _buildingId = profileModel.buildingId!;
      final bdata = await BuildingService.getBuildingDetails(_buildingId);
      if (bdata != null) {
        _buildingAddress = bdata['address'] ?? '';
        _osiName = bdata['osi_name'] ?? 'ОСИ';
        _totalApartments = bdata['total_apartments'] ?? 0;
      }
    }

    setState(() {
      _isChairman = (profileModel?.role == 'osi' || profileModel?.role == 'chairman');
      _hasVoted = vote != null;
      _isLoadingRole = false;
    });
  }

  // ── СОЗДАНИЕ НОВОГО ГОЛОСОВАНИЯ (ДЛЯ ПРЕДСЕДАТЕЛЯ) ──────────
  Future<void> _createNewProposal() async {
    final lang = appLanguage.value;
    final titleCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTexts.get('new_voting', lang)),
        content: TextField(controller: titleCtrl, decoration: InputDecoration(hintText: AppTexts.get('voting_question', lang))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTexts.get('cancel', lang))),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              try {
                await VotingService.createProposal(title: titleCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnackBar(AppTexts.get('create_voting', lang), Colors.green);
              } catch (e) {
                _showSnackBar("Ошибка: $e", Colors.red);
              }
            },
            child: const Text("Создать"),
          )
        ],
      ),
    );
  }

  // ── ГЕНЕРАЦИЯ ОФИЦИАЛЬНОГО ДОКУМЕНТА (PDF) ──────────────────
  // ── ГЕНЕРАЦИЯ ОФИЦИАЛЬНОГО ДОКУМЕНТА (PDF) ──────────────────
  Future<void> _generateOfficialProtocol() async {
    setState(() => _isUploading = true);
    try {
      final residents = await ProfileService.getResidentsByBuilding(_buildingId);
      final votes = await VotingService.votesForProposal(widget.proposalId);
      final Map voteMap = {for (var v in votes) v['user_id']: v};

      final pdf = pw.Document();
      
      // Загружаем шрифты с поддержкой кириллицы
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      pdf.addPage(pw.MultiPage(
        // ЭТО ИСПРАВЛЯЕТ "КВАДРАТЫ" - Применяем шрифт КО ВСЕМУ документу
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(
            base: font,
            bold: bold,
          ),
        ),
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Center(child: pw.Text("ПРОТОКОЛ ВНЕОЧЕРЕДНОГО СОБРАНИЯ СОБСТВЕННИКОВ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
          pw.SizedBox(height: 10),
          pw.Text("ОСИ: $_osiName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Адрес: $_buildingAddress"),
          pw.Text("Дата начала: ${DateFormat('dd.MM.yyyy HH:mm').format(_votingStartDate)}"),
          pw.Divider(),
          pw.Text("ПОВЕСТКА ДНЯ: $_currentTitle", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Кв.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ФИО Собственника", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Решение", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Подпись", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ]),
              for (var res in residents) 
                pw.TableRow(children: [
                  // Убираем null, если номер квартиры или имя пустые
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${res['apartment_number'] ?? res['apartment'] ?? '-_-'}")),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${res['full_name'] ?? res['first_name'] ?? 'Не указано'}")),
                  
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(
                    voteMap[res['id']]?['choice'] == 'yes' ? 'ЗА' : 
                    voteMap[res['id']]?['choice'] == 'no' ? 'ПРОТИВ' : 
                    voteMap[res['id']]?['choice'] == 'abstain' ? 'ВОЗД.' : 'Не голосовал'
                  )),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ЭЦП/Моб.")),
                ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text("ИТОГИ: ЗА - $_yesCount, ПРОТИВ - $_noCount, ВОЗДЕРЖАЛИСЬ - $_abstainCount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ));

      final bytes = await pdf.save();
      final fileName = "Protocol_${DateTime.now().millisecondsSinceEpoch}.pdf";

      // ЭТО ИСПРАВЛЯЕТ КРАСНУЮ ОШИБКУ НА САЙТЕ
      if (kIsWeb) {
        // На вебе используем пакет printing для сохранения/просмотра
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: fileName,
        );
      } else {
        // На Android/iOS сохраняем во временную папку и открываем
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$fileName");
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

    } catch (e) {
      _showSnackBar("Ошибка PDF: $e", Colors.red);
      debugPrint("PDF Gen Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── UI СТРАНИЦЫ ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final colors = AppColors.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(_osiName, style: TextStyle(color: colors.textPrimary)),
          iconTheme: IconThemeData(color: colors.textPrimary),
          actions: [
            if (_isChairman)
              IconButton(icon: Icon(LucideIcons.plusCircle, color: colors.primary), onPressed: _createNewProposal)
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Карточка вопроса
              _card(context: context, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppTexts.get('current_question', lang), style: TextStyle(color: colors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd.MM.yyyy').format(_votingStartDate), style: TextStyle(color: colors.textSecondary, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_currentTitle, style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  Divider(color: colors.divider, height: 30),
                  Row(children: [
                    Icon(LucideIcons.mapPin, size: 14, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(_buildingAddress, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ]),
                ],
              )),

              const SizedBox(height: 20),

              // Статистика (всегда видна председателю)
              _buildLiveStats(lang),

              const SizedBox(height: 20),

              // Интерфейс голосования
              if (!_hasVoted || _showVoteForm) 
                _buildVotingForm(lang)
              else
                _card(context: context, child: Row(
                  children: [
                    const Icon(LucideIcons.checkCircle, color: Colors.green),
                    const SizedBox(width: 15),
                    Text(AppTexts.get('already_voted', lang), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                )),
              
              if (_isChairman && !_showVoteForm && !_hasVoted)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showVoteForm = true),
                    icon: const Icon(LucideIcons.userCheck),
                    label: Text(AppTexts.get('vote_as_resident', lang)),
                  ),
                ),

              if (_isChairman) 
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: _actionButton(
                    AppTexts.get('download_protocol', lang), 
                    LucideIcons.fileText, 
                    _generateOfficialProtocol,
                    color: Colors.white10
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStats(String lang) {
    final colors = AppColors.of(context);
    return _card(context: context, child: Column(
      children: [
        Row(children: [
          Icon(LucideIcons.activity, color: colors.primary, size: 18),
          const SizedBox(width: 10),
          Text(AppTexts.get('live_stats', lang), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCol(AppTexts.get('vote_yes', lang), _yesCount, colors.success),
            _statCol(AppTexts.get('vote_no', lang), _noCount, colors.danger),
            _statCol(AppTexts.get('vote_abstain', lang), _abstainCount, colors.warning),
          ],
        ),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: (_yesCount + _noCount + _abstainCount) / math.max(1, _totalApartments),
          backgroundColor: colors.surfaceVariant,
          color: colors.primary,
        ),
        const SizedBox(height: 10),
        Text(AppTexts.get('voted_percentage', lang).replaceAll('{percent}', (((_yesCount + _noCount + _abstainCount) / math.max(1, _totalApartments)) * 100).toStringAsFixed(1)), 
          style: TextStyle(color: colors.textSecondary, fontSize: 14)),
      ],
    ));
  }

  Widget _buildVotingForm(String lang) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Row(children: [
          _voteOption("yes", AppTexts.get('vote_yes', lang), colors.success),
          const SizedBox(width: 10),
          _voteOption("no", AppTexts.get('vote_no', lang), colors.danger),
        ]),
        const SizedBox(height: 20),
        Text(AppTexts.get('your_signature', lang), style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Signature(controller: _signatureController, backgroundColor: Colors.transparent),
        ),
        const SizedBox(height: 20),
        _actionButton(AppTexts.get('send_vote', lang), LucideIcons.send, () => _submitVote(lang), color: colors.primary),
      ],
    );
  }

  Future<void> _submitVote(String lang) async {
    if (_voteSelection == null || _signatureController.isEmpty) {
      _showSnackBar(AppTexts.get('select_and_sign', lang), Colors.orange);
      return;
    }
    setState(() => _isUploading = true);

    try {
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) {
        throw StateError('Не удалось получить изображение подписи');
      }

      await VotingService.submitVote(
        proposalId: widget.proposalId,
        choice: _voteSelection!,
        signatureBytes: sigBytes,
      );

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _showVoteForm = false;
        });
        _showSnackBar(AppTexts.get('vote_success', lang), Colors.green);
      }
    } catch (e) {
      debugPrint('submitVote error: $e');
      _showSnackBar("Ошибка отправки голоса: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Вспомогательные виджеты
  Widget _card({required BuildContext context, required Widget child}) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _statCol(String label, int val, Color color) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(val.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _voteOption(String key, String label, Color color) {
    bool sel = _voteSelection == key;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _voteSelection = key),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: sel ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : color, fontWeight: FontWeight.bold))),
      ),
    ));
  }

  Widget _actionButton(String title, IconData icon, VoidCallback tap, {Color color = Colors.blueAccent}) => 
    SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      onPressed: _isUploading ? null : tap,
      icon: Icon(icon, color: Colors.white),
      label: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ));

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}