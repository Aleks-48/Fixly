import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; // Предполагается, что здесь appLanguage
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ============================================================
//  VotingPage — профессиональная страница голосования ОСИ
//  ============================================================
//  Возможности:
//  • Жители: выбор (За/Против/Воздержался), электронная подпись,
//            автоматическая генерация PDF-квитанции после голоса.
//  • Председатель: редактирование вопроса, создание новых опросов,
//                  просмотр детальной статистики, генерация
//                  официального реестра (протокола) голосования.
// ============================================================

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
  
  // Состояния загрузки и ролей
  bool _isUploading    = false;
  bool _isChairman     = false;
  bool _isLoadingRole  = true;
  bool _hasVoted       = false;

  // Данные голосования
  String? _voteSelection;
  late String _currentTitle;

  // Статистика
  int _yesCount     = 0;
  int _noCount      = 0;
  int _abstainCount = 0;

  // Информация о здании
  String _buildingId      = '';
  String _buildingAddress = '';
  int    _totalApartments = 0;

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
    super.dispose();
  }

  // ── ИНИЦИАЛИЗАЦИЯ ДАННЫХ ────────────────────────────────────
  Future<void> _initializeData() async {
    await _checkUserRole();
    await _loadStats();
  }

  // ── ПРОВЕРКА РОЛИ И СТАТУСА ГОЛОСОВАНИЯ ──────────────────────
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingRole = false);
        return;
      }

      // Запрос профиля и статуса голоса одним разом (оптимизация)
      final profileFuture = Supabase.instance.client
          .from('profiles')
          .select('role, building_id')
          .eq('id', user.id)
          .maybeSingle();

      final voteFuture = Supabase.instance.client
          .from('votes')
          .select('id')
          .eq('proposal_id', widget.proposalId)
          .eq('user_id', user.id)
          .maybeSingle();

      final results = await Future.wait([profileFuture, voteFuture]);
      final profile = results[0];
      final vote    = results[1];

      final isChairman = profile != null && profile['role'] == 'chairman';

      if (mounted) {
        setState(() {
          _isChairman    = isChairman;
          _hasVoted      = vote != null;
          _isLoadingRole = false;
        });
      }

      if (profile != null && profile['building_id'] != null) {
        await _loadBuildingInfo(profile['building_id'] as String);
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  // ── ЗАГРУЗКА ИНФОРМАЦИИ О ДОМЕ ──────────────────────────────
  Future<void> _loadBuildingInfo(String buildingId) async {
    try {
      final building = await Supabase.instance.client
          .from('buildings')
          .select('id, address, total_apartments')
          .eq('id', buildingId)
          .maybeSingle();

      if (mounted && building != null) {
        setState(() {
          _buildingId      = buildingId;
          _buildingAddress = building['address'] as String? ?? '';
          _totalApartments = building['total_apartments'] as int? ?? 0;
        });
      }
    } catch (e) {
      debugPrint('loadBuildingInfo error: $e');
    }
  }

  // ── ЗАГРУЗКА СТАТИСТИКИ ────────────────────────────────────
  Future<void> _loadStats() async {
    try {
      final votes = await Supabase.instance.client
          .from('votes')
          .select('choice')
          .eq('proposal_id', widget.proposalId);

      int yes = 0, no = 0, abstain = 0;
      for (final v in votes) {
        final c = v['choice'] as String? ?? '';
        if (c == 'yes') yes++;
        else if (c == 'no') no++;
        else if (c == 'abstain') abstain++;
      }
      if (mounted) {
        setState(() {
          _yesCount     = yes;
          _noCount      = no;
          _abstainCount = abstain;
        });
      }
    } catch (e) {
      debugPrint("Stats load error: $e");
    }
  }

  // ── РЕДАКТИРОВАНИЕ ВОПРОСА (Для председателя) ──────────────
  Future<void> _editTitle() async {
    final editController = TextEditingController(text: _currentTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(LucideIcons.edit, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Text(
              appLanguage.value == 'ru' ? "Редактировать вопрос" : "Сұрақты өңдеу",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: appLanguage.value == 'ru' ? "Текст вопроса..." : "Сұрақ мәтіні...",
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appLanguage.value == 'ru' ? "Отмена" : "Бас тарту"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty && newTitle != _currentTitle) {
                try {
                  await Supabase.instance.client
                      .from('proposals')
                      .update({'title': newTitle})
                      .eq('id', widget.proposalId);
                  if (mounted) setState(() => _currentTitle = newTitle);
                  Navigator.pop(ctx);
                  _showSnackBar(appLanguage.value == 'ru' ? "Вопрос обновлен" : "Жаңартылды", Colors.green);
                } catch (e) {
                  _showSnackBar("Ошибка: $e", Colors.red);
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text(appLanguage.value == 'ru' ? "Сохранить" : "Сақтау"),
          ),
        ],
      ),
    );
  }

  // ── СОЗДАНИЕ НОВОГО ГОЛОСОВАНИЯ ────────────────────────────
  Future<void> _createNewProposal() async {
    final titleCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          appLanguage.value == 'ru' ? "Новое голосование" : "Жаңа дауыс беру",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: appLanguage.value == 'ru' ? "Введите вопрос..." : "Сұрақты енгізіңіз...",
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appLanguage.value == 'ru' ? "Отмена" : "Бас тарту")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                final user = Supabase.instance.client.auth.currentUser;
                await Supabase.instance.client.from('proposals').insert({
                  'title': titleCtrl.text.trim(),
                  'created_by': user?.id,
                  'building_id': _buildingId.isEmpty ? null : _buildingId,
                  'status': 'active',
                  'created_at': DateTime.now().toIso8601String(),
                });
                Navigator.pop(ctx);
                _showSnackBar("Голосование создано", Colors.green);
              } catch (e) {
                _showSnackBar("Ошибка: $e", Colors.red);
              }
            },
            child: Text(appLanguage.value == 'ru' ? "Создать" : "Жасау"),
          )
        ],
      ),
    );
  }

  // ── ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ PDF ──────────────────────────
  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        return await consolidateHttpClientResponseBytes(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── ГЕНЕРАЦИЯ ПОЛНОГО ОТЧЕТА (PDF) ──────────────────────────
  Future<void> _downloadFullReport() async {
    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Загрузка жителей
      final List<dynamic> residents = await supabase
          .from('profiles')
          .select('id, full_name, apartment_number')
          .eq('building_id', _buildingId)
          .eq('role', 'resident')
          .order('apartment_number', ascending: true);

      // 2. Загрузка голосов
      final List<dynamic> allVotes = await supabase
          .from('votes')
          .select('user_id, choice, signature_url')
          .eq('proposal_id', widget.proposalId);

      final Map<String, dynamic> voteMap = {for (var v in allVotes) v['user_id']: v};

      // 3. Предзагрузка подписей (параллельно)
      final Map<String, Uint8List> sigs = {};
      await Future.wait(allVotes.map((v) async {
        final url = v['signature_url'];
        if (url != null && url.isNotEmpty) {
          final bytes = await _fetchImageBytes(url);
          if (bytes != null) sigs[v['user_id']] = bytes;
        }
      }));

      // 4. Генерация PDF
      final pdf = pw.Document();
      final fontNormal = await PdfGoogleFonts.robotoRegular();
      final fontBold   = await PdfGoogleFonts.robotoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),
          header: (ctx) => pw.Column(
            children: [
              pw.Text("ЛИСТ ГОЛОСОВАНИЯ СОБСТВЕННИКОВ", style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1),
            ],
          ),
          build: (ctx) => [
            pw.SizedBox(height: 10),
            pw.Text("Адрес: $_buildingAddress", style: pw.TextStyle(font: fontNormal, fontSize: 10)),
            pw.Text("Вопрос: $_currentTitle", style: pw.TextStyle(font: fontBold, fontSize: 11)),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(40),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(60),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell("№", fontBold, 8, align: pw.TextAlign.center),
                    _pdfCell("ФИО собственника", fontBold, 8),
                    _pdfCell("Кв.", fontBold, 8, align: pw.TextAlign.center),
                    _pdfCell("За", fontBold, 8, align: pw.TextAlign.center),
                    _pdfCell("Против", fontBold, 8, align: pw.TextAlign.center),
                    _pdfCell("Возд.", fontBold, 8, align: pw.TextAlign.center),
                  ],
                ),
                ...residents.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final vote = voteMap[r['id']];
                  final sig = sigs[r['id']];
                  final choice = vote?['choice'];

                  return pw.TableRow(
                    children: [
                      _pdfCell("${i + 1}", fontNormal, 8, align: pw.TextAlign.center),
                      _pdfCell(r['full_name'] ?? "-", fontNormal, 8),
                      _pdfCell(r['apartment_number']?.toString() ?? "-", fontNormal, 8, align: pw.TextAlign.center),
                      _pdfSigCell(choice == 'yes' ? sig : null),
                      _pdfSigCell(choice == 'no' ? sig : null),
                      _pdfSigCell(choice == 'abstain' ? sig : null),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildPdfSummary(fontBold, fontNormal),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Protocol_${widget.proposalId}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      _showSnackBar("Ошибка PDF: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  pw.Widget _pdfCell(String txt, pw.Font f, double s, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(txt, style: pw.TextStyle(font: f, fontSize: s), textAlign: align),
    );
  }

  pw.Widget _pdfSigCell(Uint8List? bytes) {
    if (bytes == null) return pw.SizedBox(height: 25);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Center(child: pw.Image(pw.MemoryImage(bytes), height: 20, fit: pw.BoxFit.contain)),
    );
  }

  pw.Widget _buildPdfSummary(pw.Font bold, pw.Font normal) {
    final total = _yesCount + _noCount + _abstainCount;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("ИТОГИ ГОЛОСОВАНИЯ:", style: pw.TextStyle(font: bold, fontSize: 10)),
        pw.Text("За: $_yesCount | Против: $_noCount | Воздержались: $_abstainCount", style: pw.TextStyle(font: normal, fontSize: 9)),
        pw.Text("Всего проголосовало: $total из $_totalApartments квартир", style: pw.TextStyle(font: normal, fontSize: 9)),
        pw.SizedBox(height: 10),
        pw.Text("Председатель ОСИ: ____________________ / ________________", style: pw.TextStyle(font: normal, fontSize: 10)),
      ],
    );
  }

  // ── ОТПРАВКА ГОЛОСА ────────────────────────────────────────
  Future<void> _submitVote() async {
    if (_voteSelection == null) {
      _showSnackBar("Выберите вариант ответа", Colors.orange);
      return;
    }
    if (_signatureController.isEmpty) {
      _showSnackBar("Поставьте подпись", Colors.orange);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) throw "Ошибка подписи";

      final path = 'sigs/${widget.proposalId}/$userId.png';
      await supabase.storage.from('documents').uploadBinary(path, sigBytes);
      final sigUrl = supabase.storage.from('documents').getPublicUrl(path);

      await supabase.from('votes').insert({
        'proposal_id': widget.proposalId,
        'user_id': userId,
        'choice': _voteSelection,
        'signature_url': sigUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Генерация квитанции пользователю
      await _generateReceipt(sigBytes);

      if (mounted) {
        setState(() => _hasVoted = true);
        _loadStats();
        _showSnackBar("Ваш голос учтен!", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Ошибка отправки: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _generateReceipt(Uint8List sig) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoBold();
    pdf.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Column(children: [
      pw.Text("ПОДТВЕРЖДЕНИЕ ГОЛОСА", style: pw.TextStyle(font: font, fontSize: 18)),
      pw.SizedBox(height: 20),
      pw.Text("Вопрос: $_currentTitle"),
      pw.Text("Ваш выбор: ${_voteSelection?.toUpperCase()}"),
      pw.SizedBox(height: 20),
      pw.Image(pw.MemoryImage(sig), height: 100),
      pw.SizedBox(height: 10),
      pw.Text("Дата: ${DateTime.now()}"),
    ]))));
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Receipt_${DateTime.now().ms}.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── BUILD UI ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(appLanguage.value == 'ru' ? "Голосование ОСИ" : "ОСИ Дауыс беру"),
        backgroundColor: cardColor,
        elevation: 0,
        actions: [
          if (_isChairman) ...[
            IconButton(icon: const Icon(LucideIcons.plus, color: Colors.green), onPressed: _createNewProposal),
            IconButton(
              icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.fileDown, color: Colors.blueAccent),
              onPressed: _isUploading ? null : _downloadFullReport,
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeaderCard(isDark, cardColor),
            const SizedBox(height: 20),
            if (_isChairman) _buildChairmanStats(isDark, cardColor),
            if (!_isChairman && !_hasVoted) _buildVotingInterface(isDark, cardColor),
            if (!_isChairman && _hasVoted) _buildSuccessBanner(isDark, cardColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLanguage.value == 'ru' ? "ТЕКУЩИЙ ВОПРОС" : "СҰРАҚ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              if (_isChairman) IconButton(icon: const Icon(LucideIcons.edit3, size: 18), onPressed: _editTitle),
            ],
          ),
          const SizedBox(height: 8),
          Text(_currentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(_buildingAddress, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChairmanStats(bool isDark, Color color) {
    final total = _yesCount + _noCount + _abstainCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLanguage.value == 'ru' ? "Статистика" : "Статистика", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("$total / $_totalApartments", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          _statBar("За", _yesCount, total, Colors.green),
          const SizedBox(height: 10),
          _statBar("Против", _noCount, total, Colors.red),
          const SizedBox(height: 10),
          _statBar("Воздержались", _abstainCount, total, Colors.orange),
        ],
      ),
    );
  }

  Widget _statBar(String label, int count, int total, Color color) {
    final progress = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12)), Text("$count")]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 8, borderRadius: BorderRadius.circular(10)),
      ],
    );
  }

  Widget _buildVotingInterface(bool isDark, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(appLanguage.value == 'ru' ? "ВАШ ВЫБОР" : "ТАҢДАУЫҢЫЗ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 15),
        Row(
          children: [
            _voteBtn("yes", LucideIcons.check, Colors.green),
            const SizedBox(width: 10),
            _voteBtn("no", LucideIcons.x, Colors.red),
            const SizedBox(width: 10),
            _voteBtn("abstain", LucideIcons.minus, Colors.orange),
          ],
        ),
        const SizedBox(height: 30),
        Text(appLanguage.value == 'ru' ? "ПОДПИСЬ" : "ҚОЛТАҢБА", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
          child: Column(
            children: [
              Signature(controller: _signatureController, height: 150, backgroundColor: Colors.transparent),
              IconButton(icon: const Icon(LucideIcons.rotateCcw, color: Colors.red, size: 20), onPressed: () => _signatureController.clear()),
            ],
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: _isUploading ? null : _submitVote,
            child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : Text(appLanguage.value == 'ru' ? "ГОЛОСОВАТЬ" : "ДАУЫС БЕРУ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        )
      ],
    );
  }

  Widget _voteBtn(String val, IconData icon, Color color) {
    final selected = _voteSelection == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _voteSelection = val),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : color.withOpacity(0.2), width: 2),
          ),
          child: Icon(icon, color: selected ? Colors.white : color, size: 30),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(bool isDark, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.green.withOpacity(0.3))),
      child: Column(
        children: [
          const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 60),
          const SizedBox(height: 15),
          Text(appLanguage.value == 'ru' ? "Голос принят" : "Дауыс қабылданды", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 10),
          Text(appLanguage.value == 'ru' ? "Спасибо за участие в жизни дома!" : "Үй өміріне қатысқаныңыз үшін рахмет!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

extension DateTimeExt on DateTime {
  int get ms => millisecondsSinceEpoch;
}