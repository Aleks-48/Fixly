// lib/screens/voting_page.dart

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
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _showVoteForm   = false; 

  String? _voteSelection;
  late String _currentTitle;
  final DateTime _votingStartDate = DateTime.now();

  int _yesCount = 0, _noCount = 0, _abstainCount = 0;
  String _buildingId = '', _buildingAddress = '', _osiName = '';
  int _totalApartments = 0;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.proposalTitle;
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF0F172A), 
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

  Future<void> _createNewProposal() async {
    final lang = appLanguage.value;
    final titleCtrl = TextEditingController();
    final c = AppColors.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.textTertiary.withOpacity(0.12)),
        ),
        title: Text(
          AppTexts.get('new_voting', lang),
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleCtrl,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: AppTexts.get('voting_question', lang),
            hintStyle: TextStyle(color: c.textTertiary.withOpacity(0.7)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.textTertiary.withOpacity(0.3))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTexts.get('cancel', lang), style: TextStyle(color: c.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              try {
                await VotingService.createProposal(title: titleCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnackBar(AppTexts.get('create_voting', lang), c.success);
              } catch (e) {
                _showSnackBar("Ошибка: $e", c.danger);
              }
            },
            child: Text(
              lang == 'ru' ? "Создать" : "Жасау", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _generateOfficialProtocol() async {
    setState(() => _isUploading = true);
    final lang = appLanguage.value;
    final c = AppColors.of(context);

    try {
      final residents = await ProfileService.getResidentsByBuilding(_buildingId);
      final votes = await VotingService.votesForProposal(widget.proposalId);
      final Map voteMap = {for (var v in votes) v['user_id']: v};

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      final pdfTitle = lang == 'ru' 
          ? "ПРОТОКОЛ ВНЕОЧЕРЕДНОГО СОБРАНИЯ СОБСТВЕННИКОВ" 
          : "МЕНШІК ИЕЛЕРІНІҢ КЕЗЕКТЕН ТЫС ЖИНАЛЫСЫНЫҢ ХАТТАМАСЫ";
      final osiLabel = lang == 'ru' ? "ОСИ:" : "МТБ:";
      final addressLabel = lang == 'ru' ? "Адрес:" : "Мекенжайы:";
      final dateLabel = lang == 'ru' ? "Дата начала:" : "Басталу күні:";
      final agendaLabel = lang == 'ru' ? "ПОВЕСТКА ДНЯ:" : "КҮН ТӘРТІБІ:";
      final headerApt = lang == 'ru' ? "Кв." : "Пәт.";
      final headerName = lang == 'ru' ? "ФИО Собственника" : "Меншік иесінің А.Ә.Т.";
      final headerDecision = lang == 'ru' ? "Решение" : "Шешім";
      final headerSignature = lang == 'ru' ? "Подпись" : "Қолтаңба";
      
      final voteYes = lang == 'ru' ? "ЗА" : "ҚОЛДАЙДЫ";
      final voteNo = lang == 'ru' ? "ПРОТИВ" : "ҚАРСЫ";
      final voteAbstain = lang == 'ru' ? "ВОЗД." : "ҚАЛЫС";
      final noVote = lang == 'ru' ? "Не голосовал" : "Дауыс бермеді";
      final sigLabel = lang == 'ru' ? "ЭЦП/Моб." : "ЭЦҚ/Ұялы";
      
      final resultsLabel = lang == 'ru' 
          ? "ИТОГИ: ЗА - $_yesCount, ПРОТИВ - $_noCount, ВОЗДЕРЖАЛИСЬ - $_abstainCount" 
          : "ҚОРЫТЫНДЫ: ҚОЛДАЙДЫ - $_yesCount, ҚАРСЫ - $_noCount, ҚАЛЫС ҚАЛДЫ - $_abstainCount";

      pdf.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: bold),
        ),
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              pdfTitle, 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text("$osiLabel $_osiName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text("$addressLabel $_buildingAddress", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("$dateLabel ${DateFormat('dd.MM.yyyy HH:mm').format(_votingStartDate)}", style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 5),
          pw.Text("$agendaLabel $_currentTitle", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 15),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
            columnWidths: {
              0: const pw.FixedColumnWidth(40),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(headerApt, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(headerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(headerDecision, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(headerSignature, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              for (var res in residents) 
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${res['apartment_number'] ?? res['apartment'] ?? '-'}", style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${res['full_name'] ?? res['first_name'] ?? '---'}", style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                    voteMap[res['id']]?['choice'] == 'yes' ? voteYes : 
                    voteMap[res['id']]?['choice'] == 'no' ? voteNo : 
                    voteMap[res['id']]?['choice'] == 'abstain' ? voteAbstain : noVote,
                    style: pw.TextStyle(
                      fontSize: 9, 
                      fontWeight: voteMap[res['id']] != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  )),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(sigLabel, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                ]),
            ],
          ),
          pw.SizedBox(height: 25),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.grey400)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(resultsLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ));

      final bytes = await pdf.save();
      final fileName = "Protocol_${DateTime.now().millisecondsSinceEpoch}.pdf";

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: fileName,
        );
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$fileName");
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

    } catch (e) {
      _showSnackBar("Ошибка PDF: $e", c.danger);
      debugPrint("PDF Gen Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Center(child: CircularProgressIndicator(color: AppColors.of(context).primary)),
      );
    }

    final colors = AppColors.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          title: Text(
            _osiName, 
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          iconTheme: IconThemeData(color: colors.textPrimary),
          actions: [
            if (_isChairman)
              IconButton(
                icon: Icon(LucideIcons.plusCircle, color: colors.primary), 
                onPressed: _createNewProposal,
              )
          ],
          shape: Border(bottom: BorderSide(color: colors.textTertiary.withOpacity(0.12))),
        ),
        body: _isUploading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Карточка вопроса
                    _StaggeredEntrance(
                      index: 0,
                      child: _card(
                        context: context, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
Text(
  AppTexts.get('current_question', lang).toUpperCase(), 
  style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
),
                                Text(
                                  DateFormat('dd.MM.yyyy').format(_votingStartDate), 
                                  style: TextStyle(color: colors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentTitle, 
                              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Divider(color: colors.textTertiary.withOpacity(0.12), height: 30),
                            Row(
                              children: [
                                Icon(LucideIcons.mapPin, size: 16, color: colors.textTertiary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _buildingAddress, 
                                    style: TextStyle(color: colors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Статистика
                    _StaggeredEntrance(
                      index: 1,
                      child: _buildLiveStats(lang),
                    ),

                    const SizedBox(height: 20),

                    // Форма голосования
                    _StaggeredEntrance(
                      index: 2,
                      child: Column(
                        children: [
                          if (!_hasVoted || _showVoteForm) 
                            _buildVotingForm(lang)
                          else
                            _card(
                              context: context, 
                              child: Row(
                                children: [
                                  Icon(LucideIcons.checkCircle, color: colors.success, size: 22),
                                  const SizedBox(width: 15),
                                  Text(
                                    AppTexts.get('already_voted', lang), 
                                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_isChairman && !_showVoteForm && !_hasVoted)
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: TextButton.icon(
                                onPressed: () => setState(() => _showVoteForm = true),
                                icon: Icon(LucideIcons.userCheck, color: colors.primary, size: 18),
                                label: Text(
                                  AppTexts.get('vote_as_resident', lang),
                                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          if (_isChairman) 
                            Padding(
                              padding: const EdgeInsets.only(top: 25),
                              child: _actionButton(
                                AppTexts.get('download_protocol', lang), 
                                LucideIcons.fileText, 
                                _generateOfficialProtocol,
                                color: colors.textTertiary.withOpacity(0.08),
                                textColor: colors.textPrimary,
                              ),
                            ),
                        ],
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
    final double votedRatio = (_yesCount + _noCount + _abstainCount) / math.max(1, _totalApartments);
    final String percentText = (votedRatio * 100).toStringAsFixed(1);

    return _card(
      context: context, 
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, color: colors.primary, size: 18),
              const SizedBox(width: 10),
              Text(
                AppTexts.get('live_stats', lang), 
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol(AppTexts.get('vote_yes', lang), _yesCount, colors.success),
              _statCol(AppTexts.get('vote_no', lang), _noCount, colors.danger),
              _statCol(AppTexts.get('vote_abstain', lang), _abstainCount, colors.warning),
            ],
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: votedRatio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colors.primary.withOpacity(0.08),
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppTexts.get('voted_percentage', lang).replaceAll('{percent}', percentText), 
            style: TextStyle(color: colors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingForm(String lang) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _voteOption("yes", AppTexts.get('vote_yes', lang), colors.success),
            const SizedBox(width: 12),
            _voteOption("no", AppTexts.get('vote_no', lang), colors.danger),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            AppTexts.get('your_signature', lang), 
            style: TextStyle(color: colors.textTertiary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Stack(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade50, 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.textTertiary.withOpacity(0.15), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Signature(
                  controller: _signatureController, 
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: const CircleBorder(),
                child: IconButton(
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(LucideIcons.eraser, size: 16, color: Color(0xFF0F172A)),
                  onPressed: () => _signatureController.clear(),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        _actionButton(
          AppTexts.get('send_vote', lang), 
          LucideIcons.send, 
          () => _submitVote(lang), 
          color: colors.primary,
        ),
      ],
    );
  }

  Future<void> _submitVote(String lang) async {
    final colors = AppColors.of(context);
    if (_voteSelection == null || _signatureController.isEmpty) {
      _showSnackBar(AppTexts.get('select_and_sign', lang), colors.warning);
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
        _showSnackBar(AppTexts.get('vote_success', lang), colors.success);
      }
    } catch (e) {
      debugPrint('submitVote error: $e');
      _showSnackBar("Ошибка отправки голоса: $e", colors.danger);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _card({required BuildContext context, required Widget child}) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.textTertiary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

Widget _statCol(String label, int val, Color color) {
  final colors = AppColors.of(context);
  return Column(
    children: [
      Text(
        val.toString(), 
        style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800),
      ),
        const SizedBox(height: 4),
        Text(
          label, 
          style: TextStyle(color: colors.textTertiary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _voteOption(String key, String label, Color color) {
    bool sel = _voteSelection == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _voteSelection = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            color: sel ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sel ? color : color.withOpacity(0.3), 
              width: sel ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: sel ? Colors.white : color, 
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    String title, 
    IconData icon, 
    VoidCallback tap, {
    required Color color, 
    Color textColor = Colors.white,
  }) => 
    SizedBox(
      width: double.infinity, 
      height: 55, 
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isUploading ? null : tap,
        icon: Icon(icon, color: textColor, size: 18),
        label: Text(
          title, 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация появления элементов
// ============================================================
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}