import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'package:fixly_app/screens/voting_page.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:fixly_app/services/voting_service.dart';

import 'package:flutter/material.dart';

class VotingListScreen extends StatelessWidget {
  const VotingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Голосования'),
      ),
      body: const Center(
        child: Text('Здесь будет список голосований'),
      ),
    );
  }
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

  // ── ЖИВАЯ СТАТИСТИКА С СУПЕР-ОПТИМИЗАЦИЕЙ ─────────────────
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
          _yesCount = yes; 
          _noCount = no; 
          _abstainCount = abstain;
        });
      }
    });
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', user.id).maybeSingle();
      final vote = await Supabase.instance.client.from('votes').select().eq('proposal_id', widget.proposalId).eq('user_id', user.id).maybeSingle();
      
      if (profile != null && profile['building_id'] != null) {
        _buildingId = profile['building_id'];
        final bdata = await Supabase.instance.client.from('buildings').select().eq('id', _buildingId).maybeSingle();
        if (bdata != null) {
          _buildingAddress = bdata['address'] ?? '';
          _osiName = bdata['osi_name'] ?? 'ОСИ';
          _totalApartments = bdata['total_apartments'] ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          // Учитываем обе вариации роли председателя из бэкенда
          _isChairman = (profile?['role'] == 'osi' || profile?['role'] == 'chairman');
          _hasVoted = vote != null;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  // ── СОЗДАНИЕ НОВОГО ГОЛОСОВАНИЯ (ДЛЯ ПРЕДСЕДАТЕЛЯ) ──────────
  Future<void> _createNewProposal() async {
    final titleCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLanguage.value == 'ru' ? "Новое голосование" : "Жаңа дауыс беру"),
        content: TextField(
          controller: titleCtrl, 
          decoration: const InputDecoration(hintText: "Тема вопроса / Повестка дня")
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              await Supabase.instance.client.from('proposals').insert({
                'title': titleCtrl.text.trim(),
                'building_id': _buildingId,
                'created_by': Supabase.instance.client.auth.currentUser!.id,
                'created_at': DateTime.now().toIso8601String(),
              });
              Navigator.pop(ctx);
              _showSnackBar("Голосование успешно создано", Colors.green);
            },
            child: const Text("Создать"),
          )
        ],
      ),
    );
  }

  // ── ГЕНЕРАЦИЯ ОФИЦИАЛЬНОГО ДОКУМЕНТА (ПРОТОКОЛ И ЛИСТ) ─────
  Future<void> _generateOfficialProtocol() async {
    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final residents = await supabase.from('profiles').select().eq('building_id', _buildingId).order('apartment_number', ascending: true);
      final votes = await supabase.from('votes').select().eq('proposal_id', widget.proposalId);
      final Map voteMap = {for (var v in votes) v['user_id']: v};

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      pdf.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(35),
          theme: pw.ThemeData.withFont(base: font, bold: bold),
        ),
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          // Шапка документа
          pw.Center(
            child: pw.Text(
              "ЛИСТ ПИСЬМЕННОГО ОПРОСА И ПРОТОКОЛ СОБРАНИЯ",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 15),
          
          // Метаданные ОСИ
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Организация: $_osiName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text("Дата: ${DateFormat('dd.MM.yyyy').format(_votingStartDate)}", style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text("Объект кондоминиума (Адрес): $_buildingAddress", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("Всего квартир по проекту: $_totalApartments", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 5),

          // Повестка дня
          pw.Text("ПОВЕСТКА ДНЯ:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(_currentTitle, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
          pw.SizedBox(height: 15),

          // Таблица голосования жителей
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),  // №
              1: const pw.FixedColumnWidth(35),  // Кв.
              2: const pw.FlexColumnWidth(3),    // ФИО
              3: const pw.FixedColumnWidth(65),  // Решение
              4: const pw.FlexColumnWidth(2),    // Цифровой след / Подпись
            },
            children: [
              // Заголовок таблицы
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("№", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("Кв.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ФИО Собственника", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("Решение", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Способ / Подпись", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ],
              ),
              // Строки жильцов
              for (int i = 0; i < residents.length; i++) ...[
                (() {
                  final res = residents[i];
                  final userVote = voteMap[res['id']];
                  final String choiceText = userVote?['choice'] == 'yes' ? 'ЗА' : 
                                            userVote?['choice'] == 'no' ? 'ПРОТИВ' : 
                                            userVote?['choice'] == 'abstain' ? 'ВОЗДЕРЖ.' : 'НЕ ГОЛОСОВАЛ';
                  
                  final String signText = userVote != null 
                      ? "Моб. ЭЦП\n${DateFormat('dd.MM HH:mm').format(DateTime.parse(userVote['created_at'] ?? DateTime.now().toIso8601String()))}"
                      : "—";

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("${i + 1}", style: const pw.TextStyle(fontSize: 9)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text("${res['apartment_number'] ?? res['apartment'] ?? '—'}", style: const pw.TextStyle(fontSize: 9)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${res['full_name'] ?? 'Не указано'}", style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5), 
                        child: pw.Center(child: pw.Text(
                          choiceText, 
                          style: pw.TextStyle(
                            fontSize: 9, 
                            fontWeight: choiceText != 'НЕ ГОЛОСОВАЛ' ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: choiceText == 'ЗА' ? PdfColors.green700 : choiceText == 'ПРОТИВ' ? PdfColors.red700 : PdfColors.black
                          )
                        )),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(signText, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    ],
                  );
                })(),
              ],
            ],
          ),
          pw.SizedBox(height: 20),

          // Итоги голосования
          pw.Text("ИТОГИ ГОЛОСОВАНИЯ:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Bullet(text: "Всего проголосовало квартир: ${_yesCount + _noCount + _abstainCount} из $_totalApartments"),
          pw.Bullet(text: "Результаты: ЗА — $_yesCount, ПРОТИВ — $_noCount, ВОЗДЕРЖАЛИСЬ — $_abstainCount"),
          pw.Bullet(text: "Кворум: ${(((_yesCount + _noCount + _abstainCount) / math.max(1, _totalApartments)) * 100).toStringAsFixed(1)}% (Собрание считается состоявшимся при >50%)"),
          
          pw.SizedBox(height: 30),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 10),

          // Подписи ответственных лиц
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Председатель ОСИ / Доверенное лицо:", style: const pw.TextStyle(fontSize: 10)),
pw.Container(
  width: 150,
  decoration: const pw.BoxDecoration( // ДОБАВЛЕНО
    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
  ),
  child: pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Text(" / Подпись", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600), textAlign: pw.TextAlign.right),
                ),
              ),
            ],
          ),
        ],
      ));

      final bytes = await pdf.save();
      final fileName = "Protocol_Voting_${widget.proposalId}.pdf";

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: fileName);
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$fileName");
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

    } catch (e) {
      _showSnackBar("Ошибка при формировании PDF: $e", Colors.red);
      debugPrint("PDF Gen Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── UI СТРАНИЦЫ ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B2E),
        elevation: 0,
        title: Text(_osiName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isChairman)
            IconButton(
              icon: const Icon(LucideIcons.plusCircle, color: Colors.blueAccent), 
              onPressed: _createNewProposal,
              tooltip: "Создать новое голосование",
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Карточка повестки дня
            _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("ТЕКУЩИЙ ВОПРОС СЛУШАНИЯ", style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text(DateFormat('dd.MM.yyyy').format(_votingStartDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4)),
                const Divider(color: Colors.white10, height: 30, thickness: 1),
                Row(children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_buildingAddress, style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
              ],
            )),

            const SizedBox(height: 20),

            // Live-статистика
            _buildLiveStats(),

            const SizedBox(height: 20),

            // Форма голосования или статус
            if (!_hasVoted || _showVoteForm) 
              _buildVotingForm()
            else
              _card(
                child: const Row(
                  children: [
                    Icon(LucideIcons.checkCircle, color: Colors.green, size: 28),
                    SizedBox(width: 15),
                    Text("Ваш голос успешно зафиксирован!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            
            if (_isChairman && !_showVoteForm && !_hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: TextButton.icon(
                  onPressed: () => setState(() => _showVoteForm = true),
                  icon: const Icon(LucideIcons.userCheck, size: 18),
                  label: const Text("Проголосовать как житель", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            if (_isChairman) 
              Padding(
                padding: const EdgeInsets.only(top: 25),
                child: _actionButton(
                  "СФОРМИРОВАТЬ ОФИЦИАЛЬНЫЙ ПРОТОКОЛ", 
                  LucideIcons.fileText, 
                  _generateOfficialProtocol,
                  color: Colors.blueAccent.withOpacity(0.2),
                  textColor: Colors.blueAccent
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStats() {
    final int totalVotes = _yesCount + _noCount + _abstainCount;
    final double progress = totalVotes / math.max(1, _totalApartments);

    return _card(child: Column(
      children: [
        const Row(children: [
          Icon(LucideIcons.activity, color: Colors.blueAccent, size: 18),
          SizedBox(width: 10),
          Text("МОНИТОРИНГ ГОЛОСОВАНИЯ (LIVE)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCol("ЗА", _yesCount, Colors.green),
            _statCol("ПРОТИВ", _noCount, Colors.red),
            _statCol("ВОЗДЕРЖАЛИСЬ", _abstainCount, Colors.orange),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 1.0 ? 1.0 : progress,
            backgroundColor: Colors.white10,
            color: Colors.blueAccent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Проголосовало: $totalVotes из $_totalApartments кв.", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("${(progress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    ));
  }

  Widget _buildVotingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ВЫБЕРИТЕ ВАШЕ РЕШЕНИЕ:", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Row(children: [
          _voteOption("yes", "ЗА", Colors.green),
          const SizedBox(width: 10),
          _voteOption("no", "ПРОТИВ", Colors.red),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _voteOption("abstain", "ВОЗДЕРЖАТЬСЯ", Colors.orange),
        ]),
        const SizedBox(height: 20),
        const Text("ЛИЧНАЯ ПОДПИСЬ СУБЪЕКТА (ЭЦП КЛЮЧ / ЭКРАН):", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1)
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Signature(controller: _signatureController, backgroundColor: Colors.transparent),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _signatureController.clear(),
              icon: const Icon(LucideIcons.eraser, size: 14, color: Colors.grey),
              label: const Text("Очистить поле подписи", style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 10),
        _actionButton("ПОДПИСАТЬ И ОТПРАВИТЬ ГОЛОС", LucideIcons.send, _submitVote),
      ],
    );
  }

  Future<void> _submitVote() async {
    if (_voteSelection == null) {
      _showSnackBar("Пожалуйста, выберите ваше решение (За/Против/Воздержался)", Colors.orange);
      return;
    }
    if (_signatureController.isEmpty) {
      _showSnackBar("Пожалуйста, оставьте графическую подпись на холсте", Colors.orange);
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) {
        throw StateError('Ошибка кодирования подписи');
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
        _showSnackBar("Ваш голос успешно сохранен в реестре кондоминиума!", Colors.green);
      }
    } catch (e) {
      debugPrint('submitVote error: $e');
      _showSnackBar("Ошибка при отправке: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Вспомогательные графические компоненты
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF161B2E), 
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.03), width: 1)
    ),
    child: child,
  );

  Widget _statCol(String label, int val, Color color) => Column(
    children: [
      Text(val.toString(), style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _voteOption(String key, String label, Color color) {
    bool sel = _voteSelection == key;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _voteSelection = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 55,
        decoration: BoxDecoration(
          color: sel ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
border: Border.all(color: sel ? color : color.withOpacity(0.3), width: sel ? 2.0 : 1.0), // ИСПРАВЛЕНО
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
    ));
  }

  Widget _actionButton(
    String title, 
    IconData icon, 
    VoidCallback tap, {
    Color color = Colors.blueAccent, 
    Color textColor = Colors.white
  }) => 
    SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
      ),
      onPressed: _isUploading ? null : tap,
      icon: _isUploading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon, color: textColor, size: 18),
      label: _isUploading 
          ? const Text("Обработка...", style: TextStyle(color: Colors.white))
          : Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    ));

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));
  }
}