import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ============================================================
//  VotingPage — страница голосования ОСИ
//  • Для жителей  : 3 кнопки (За / Против / Воздержался) + подпись
//  • Для председателя : тап по вопросу для редактирования,
//                       создать вопрос, скачать официальный PDF-бланк
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

class _VotingPageState extends State<VotingPage> {
  late SignatureController _signatureController;

  bool _isUploading    = false;
  bool _isChairman     = false;
  bool _isLoadingRole  = true;
  bool _hasVoted       = false;

  // 'yes' | 'no' | 'abstain'
  String? _voteSelection;
  late String _currentTitle;

  // Статистика голосования
  int _yesCount     = 0;
  int _noCount      = 0;
  int _abstainCount = 0;

  // Информация о доме
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
    _checkUserRole();
    _loadStats();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // ── ПРОВЕРКА РОЛИ ──────────────────────────────────────────
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('role, building_id')
            .eq('id', user.id)
            .maybeSingle();

        final vote = await Supabase.instance.client
            .from('votes')
            .select('id')
            .eq('proposal_id', widget.proposalId)
            .eq('user_id', user.id)
            .maybeSingle();

        final isChairman = data != null && data['role'] == 'chairman';

        if (mounted) {
          setState(() {
            _isChairman    = isChairman;
            _hasVoted      = vote != null;
            _isLoadingRole = false;
          });
        }

        // Загружаем информацию о доме (нужна для обеих ролей)
        if (data != null && data['building_id'] != null) {
          await _loadBuildingInfo(data['building_id'] as String);
        }
      } else {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
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
    } catch (_) {}
  }

  // ── РЕДАКТИРОВАТЬ ТЕМУ ─────────────────────────────────────
  // Вызывается и по тапу на карточку, и по иконке карандаша
  Future<void> _editTitle() async {
    final editController = TextEditingController(text: _currentTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          appLanguage.value == 'ru'
              ? "Изменить вопрос голосования"
              : "Дауыс беру сұрағын өзгерту",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: appLanguage.value == 'ru'
                ? "Введите вопрос для голосования..."
                : "Дауыс беру сұрағын енгізіңіз...",
            hintStyle:
                TextStyle(color: isDark ? Colors.white54 : Colors.black38),
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              appLanguage.value == 'ru' ? "Отмена" : "Бас тарту",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty) {
                try {
                  await Supabase.instance.client
                      .from('proposals')
                      .update({'title': newTitle})
                      .eq('id', widget.proposalId);
                  if (mounted) setState(() => _currentTitle = newTitle);
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(appLanguage.value == 'ru'
                          ? "Вопрос голосования обновлён!"
                          : "Дауыс беру сұрағы жаңартылды!"),
                      backgroundColor: Colors.blueAccent,
                    ));
                  }
                } catch (e) {
                  debugPrint("Update error: $e");
                }
              }
            },
            child: Text(
              appLanguage.value == 'ru' ? "Сохранить" : "Сақтау",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── СОЗДАТЬ НОВОЕ ГОЛОСОВАНИЕ ──────────────────────────────
  Future<void> _createNewProposal() async {
    final titleCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          appLanguage.value == 'ru'
              ? "Создать новое голосование"
              : "Жаңа дауыс беру жасау",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appLanguage.value == 'ru'
                  ? "Введите вопрос, который будет вынесен на голосование собственников дома:"
                  : "Үй иелерінің дауысына шығарылатын сұрақты енгізіңіз:",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: appLanguage.value == 'ru'
                    ? "Например: Утверждение сметы расходов на 2025 год"
                    : "Мысалы: 2025 жылға арналған шығыс сметасын бекіту",
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              appLanguage.value == 'ru' ? "Отмена" : "Бас тарту",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                try {
                  final user = Supabase.instance.client.auth.currentUser;
                  await Supabase.instance.client.from('proposals').insert({
                    'title'      : title,
                    'created_by' : user?.id,
                    'building_id': _buildingId.isEmpty ? null : _buildingId,
                    'created_at' : DateTime.now().toIso8601String(),
                    'status'     : 'active',
                  });
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(appLanguage.value == 'ru'
                            ? "Голосование создано!"
                            : "Дауыс беру жасалды!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Create proposal error: $e");
                }
              }
            },
            child: Text(
              appLanguage.value == 'ru' ? "Создать" : "Жасау",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── СКАЧАТЬ ИЗОБРАЖЕНИЕ ПО URL ─────────────────────────────
  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        return await consolidateHttpClientResponseBytes(response);
      }
      client.close();
      return null;
    } catch (e) {
      debugPrint('fetchImage error: $e');
      return null;
    }
  }

  // ── ОФИЦИАЛЬНЫЙ ЛИСТ ГОЛОСОВАНИЯ (PDF по форме ОСИ) ────────
  Future<void> _downloadFullReport() async {
    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Все жители дома (из profiles)
      List<dynamic> residents = [];
      if (_buildingId.isNotEmpty) {
        residents = await supabase
            .from('profiles')
            .select('id, full_name, apartment_number')
            .eq('building_id', _buildingId)
            .eq('role', 'resident')
            .order('apartment_number', ascending: true);
      }

      // 2. Все голоса с подписями
      final List<dynamic> allVotes = await supabase
          .from('votes')
          .select('user_id, choice, signature_url, created_at')
          .eq('proposal_id', widget.proposalId);

      // Карта: user_id → vote
      final Map<String, dynamic> voteByUser = {
        for (final v in allVotes) v['user_id'] as String: v,
      };

      // 3. Скачиваем подписи для проголосовавших
      final Map<String, Uint8List> sigByUser = {};
      for (final v in allVotes) {
        final uid    = v['user_id'] as String? ?? '';
        final sigUrl = v['signature_url'] as String?;
        if (sigUrl != null && sigUrl.isNotEmpty) {
          final bytes = await _fetchImageBytes(sigUrl);
          if (bytes != null) sigByUser[uid] = bytes;
        }
      }

      // 4. Подсчёт итогов
      int yes = 0, no = 0, abstain = 0;
      for (final v in allVotes) {
        final c = v['choice'] as String? ?? '';
        if (c == 'yes') yes++;
        else if (c == 'no') no++;
        else if (c == 'abstain') abstain++;
      }
      final int totalVoted   = allVotes.length;
      final int totalApts    = _totalApartments > 0
          ? _totalApartments
          : residents.length;

      // 5. Строим PDF
      final pdf      = pw.Document();
      final font     = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final now      = DateFormat('dd.MM.yyyy').format(DateTime.now());
      final timeStr  = DateFormat('HH:mm').format(DateTime.now());

      // ── ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ────────────────────────────
      pw.Widget cellTxt(String text, pw.Font f, double size,
          {pw.TextAlign align = pw.TextAlign.left}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: f, fontSize: size),
            textAlign: align,
          ),
        );
      }

      pw.Widget cellSig(Uint8List? bytes) {
        if (bytes != null) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: 60,
              height: 32,
              fit: pw.BoxFit.contain,
            ),
          );
        }
        return pw.SizedBox(height: 38);
      }

      pw.Widget headerCell(String line1, String? line2, pw.Font f) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(line1,
                  style: pw.TextStyle(font: f, fontSize: 7),
                  textAlign: pw.TextAlign.center),
              if (line2 != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(line2,
                    style: pw.TextStyle(font: f, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ],
            ],
          ),
        );
      }

      // ── СТРАНИЦЫ ДОКУМЕНТА ─────────────────────────────────
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(30, 30, 20, 30),
          build: (pw.Context ctx) => [

            // ── ЗАГОЛОВОК ──────────────────────────────────
            pw.Text(
              "Лист голосования собственников квартир, нежилых помещений,\n"
              "проголосовавших на собрании (проводимый путем явочного порядка)",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 10),

            // ── ДАТА / АДРЕС ───────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '"__" ___________ 20___ года',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  'время $timeStr',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Местонахождение многоквартирного жилого дома: $_buildingAddress",
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Всего квартир в доме: $totalApts",
              style: pw.TextStyle(font: fontBold, fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 6),

            // ── ВОПРОС ─────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Вопрос, внесённый для обсуждения:",
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "1)   $_currentTitle",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
            pw.SizedBox(height: 12),

            // ── ТАБЛИЦА ГОЛОСОВАНИЯ ────────────────────────
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
              columnWidths: {
                0: const pw.FixedColumnWidth(22),  // №
                1: const pw.FlexColumnWidth(2.8),  // ФИО
                2: const pw.FixedColumnWidth(35),  // № кв
                3: const pw.FixedColumnWidth(68),  // ЗА
                4: const pw.FixedColumnWidth(68),  // ПРОТИВ
                5: const pw.FixedColumnWidth(68),  // ВОЗДЕРЖУСЬ
              },
              children: [
                // Заголовок таблицы
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    headerCell("№", null, fontBold),
                    headerCell("Фамилия Имя Отчество",
                        "(при его наличии)", fontBold),
                    headerCell("№", "квар-\nтиры", fontBold),
                    headerCell("Голосую", '"За"\n(подпись)', fontBold),
                    headerCell('"Против"', '(подпись)', fontBold),
                    headerCell('"Воздержусь"', '(подпись)', fontBold),
                  ],
                ),

                // Строки по жителям из базы
                ...residents.asMap().entries.map((entry) {
                  final index    = entry.key;
                  final resident = entry.value;
                  final uid      = resident['id'] as String? ?? '';
                  final vote     = voteByUser[uid];
                  final choice   = vote?['choice'] as String?;
                  final sigBytes = sigByUser[uid];

                  return pw.TableRow(
                    children: [
                      cellTxt('${index + 1}.', font, 8,
                          align: pw.TextAlign.center),
                      cellTxt(
                          resident['full_name'] as String? ?? '—', font, 8),
                      cellTxt(
                          resident['apartment_number']?.toString() ?? '—',
                          font,
                          8,
                          align: pw.TextAlign.center),
                      cellSig(choice == 'yes' ? sigBytes : null),
                      cellSig(choice == 'no' ? sigBytes : null),
                      cellSig(choice == 'abstain' ? sigBytes : null),
                    ],
                  );
                }),

                // Дополнительные пустые строки до totalApts
                ...List.generate(
                  (totalApts - residents.length).clamp(0, 200),
                  (i) {
                    final num = residents.length + i + 1;
                    return pw.TableRow(
                      children: [
                        cellTxt('$num.', font, 8,
                            align: pw.TextAlign.center),
                        pw.SizedBox(height: 26),
                        pw.SizedBox(),
                        pw.SizedBox(),
                        pw.SizedBox(),
                        pw.SizedBox(),
                      ],
                    );
                  },
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // ── ИТОГОВАЯ СТАТИСТИКА ────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Итоги голосования:",
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FixedColumnWidth(60),
                      2: const pw.FixedColumnWidth(80),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200),
                        children: [
                          cellTxt("Решение", fontBold, 9,
                              align: pw.TextAlign.center),
                          cellTxt("Количество", fontBold, 9,
                              align: pw.TextAlign.center),
                          cellTxt("% от проголосовавших", fontBold, 8,
                              align: pw.TextAlign.center),
                        ],
                      ),
                      pw.TableRow(children: [
                        cellTxt("ЗА", font, 9,
                            align: pw.TextAlign.center),
                        cellTxt("$yes", fontBold, 10,
                            align: pw.TextAlign.center),
                        cellTxt(
                            totalVoted > 0
                                ? "${(yes / totalVoted * 100).toStringAsFixed(1)}%"
                                : "—",
                            font,
                            9,
                            align: pw.TextAlign.center),
                      ]),
                      pw.TableRow(children: [
                        cellTxt("ПРОТИВ", font, 9,
                            align: pw.TextAlign.center),
                        cellTxt("$no", fontBold, 10,
                            align: pw.TextAlign.center),
                        cellTxt(
                            totalVoted > 0
                                ? "${(no / totalVoted * 100).toStringAsFixed(1)}%"
                                : "—",
                            font,
                            9,
                            align: pw.TextAlign.center),
                      ]),
                      pw.TableRow(children: [
                        cellTxt("ВОЗДЕРЖАЛСЯ", font, 9,
                            align: pw.TextAlign.center),
                        cellTxt("$abstain", fontBold, 10,
                            align: pw.TextAlign.center),
                        cellTxt(
                            totalVoted > 0
                                ? "${(abstain / totalVoted * 100).toStringAsFixed(1)}%"
                                : "—",
                            font,
                            9,
                            align: pw.TextAlign.center),
                      ]),
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100),
                        children: [
                          cellTxt("ВСЕГО ПРОГОЛОСОВАЛО", fontBold, 9,
                              align: pw.TextAlign.center),
                          cellTxt("$totalVoted", fontBold, 10,
                              align: pw.TextAlign.center),
                          cellTxt("из $totalApts квартир", font, 9,
                              align: pw.TextAlign.center),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: yes > (totalVoted / 2)
                          ? PdfColors.green50
                          : PdfColors.red50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(children: [
                      pw.Text("РЕШЕНИЕ: ",
                          style:
                              pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.Text(
                        yes > (totalVoted / 2)
                            ? "ПРИНЯТО (большинство голосов «ЗА»)"
                            : "НЕ ПРИНЯТО",
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 12),

            // ── ПОДПИСИ ПРЕДСЕДАТЕЛЯ И СЕКРЕТАРЯ ──────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _signBlock("Председатель собрания:", font, fontBold),
                _signBlock("Секретарь собрания:", font, fontBold),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _signBlock("Член совета дома:", font, fontBold),
                _signBlock("Член совета дома:", font, fontBold),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text("Член совета дома: ________________________  ________",
                style: pw.TextStyle(font: font, fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text("(фамилия, имя, отчество (при его наличии))            (подпись)",
                style: pw.TextStyle(
                    font: font, fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      );

      // 6. Сохраняем и открываем
      final output = await getTemporaryDirectory();
      final safeTitle = _currentTitle
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(' ', '_')
          .substring(0, _currentTitle.length.clamp(0, 30));
      final file = File(
          "${output.path}/Лист_голосования_$safeTitle.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка генерации: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Блок подписи в PDF
  pw.Widget _signBlock(
      String label, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(font: fontBold, fontSize: 9)),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          pw.Container(width: 130, child: pw.Divider(thickness: 0.5)),
          pw.SizedBox(width: 6),
          pw.Container(width: 60, child: pw.Divider(thickness: 0.5)),
        ]),
        pw.Row(children: [
          pw.SizedBox(width: 5),
          pw.Text(
              "(фамилия, имя, отчество (при его наличии))",
              style: pw.TextStyle(
                  font: font, fontSize: 6, color: PdfColors.grey600)),
          pw.SizedBox(width: 8),
          pw.Text("(подпись)",
              style: pw.TextStyle(
                  font: font, fontSize: 6, color: PdfColors.grey600)),
        ]),
      ],
    );
  }

  // ── ОТПРАВКА ГОЛОСА ────────────────────────────────────────
  Future<void> _submitVote() async {
    if (_voteSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appLanguage.value == 'ru'
            ? "Выберите один вариант: За, Против или Воздержался"
            : "Бір нұсқаны таңдаңыз: Иә, Қарсы немесе Қалыс қалу"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appLanguage.value == 'ru'
            ? "Пожалуйста, поставьте вашу подпись"
            : "Қолтаңбаңызды қойыңыз"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId   = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Не авторизован");

      final existing = await supabase
          .from('votes')
          .select('id')
          .eq('proposal_id', widget.proposalId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Вы уже проголосовали по данному вопросу"),
          backgroundColor: Colors.redAccent,
        ));
        setState(() => _isUploading = false);
        return;
      }

      final Uint8List? signatureBytes =
          await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception("Ошибка получения подписи");

      final path =
          'signatures/$userId/${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage
          .from('documents')
          .uploadBinary(path, signatureBytes);
      final sigUrl =
          supabase.storage.from('documents').getPublicUrl(path);

      await supabase.from('votes').insert({
        'proposal_id'  : widget.proposalId,
        'user_id'      : userId,
        'choice'       : _voteSelection,
        'signature_url': sigUrl,
        'created_at'   : DateTime.now().toIso8601String(),
      });

      // Генерируем квитанцию жителю
      await _generateReceiptPDF(signatureBytes, _voteSelection!);

      if (mounted) {
        setState(() => _hasVoted = true);
        _loadStats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru'
                ? "Ваш голос принят! Спасибо."
                : "Дауысыңыз қабылданды! Рахмет."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Ошибка: $e"),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── КВИТАНЦИЯ ЖИТЕЛЮ (PDF) ─────────────────────────────────
  Future<void> _generateReceiptPDF(Uint8List sig, String choice) async {
    final pdf      = pw.Document();
    final font     = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final now      = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    String    choiceLabel;
    PdfColor  choiceColor;
    if (choice == 'yes') {
      choiceLabel = 'ЗА';
      choiceColor = PdfColors.green700;
    } else if (choice == 'no') {
      choiceLabel = 'ПРОТИВ';
      choiceColor = PdfColors.red700;
    } else {
      choiceLabel = 'ВОЗДЕРЖАЛСЯ';
      choiceColor = PdfColors.orange700;
    }

    // Получаем данные жителя для квитанции
    String residentName = '';
    String residentApt  = '';
    try {
      final uid  = Supabase.instance.client.auth.currentUser?.id;
      final prof = uid != null
          ? await Supabase.instance.client
              .from('profiles')
              .select('full_name, apartment_number')
              .eq('id', uid)
              .maybeSingle()
          : null;
      residentName = prof?['full_name'] as String? ?? '';
      residentApt  = prof?['apartment_number']?.toString() ?? '';
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                "ПОДТВЕРЖДЕНИЕ ГОЛОСОВАНИЯ",
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
            ),
            pw.Center(
              child: pw.Text(
                "Объединение собственников имущества (ОСИ)",
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 12),

            if (residentName.isNotEmpty) ...[
              pw.Text("Собственник: $residentName",
                  style: pw.TextStyle(font: fontBold, fontSize: 11)),
              pw.SizedBox(height: 4),
            ],
            if (residentApt.isNotEmpty) ...[
              pw.Text("Квартира № $residentApt",
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 12),
            ],

            pw.Text("Вопрос голосования:",
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(_currentTitle,
                  style: pw.TextStyle(font: font, fontSize: 11)),
            ),
            pw.SizedBox(height: 20),

            pw.Text("Ваш голос:",
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: choiceColor, width: 1.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Center(
                child: pw.Text(
                  choiceLabel,
                  style:
                      pw.TextStyle(font: fontBold, fontSize: 20, color: choiceColor),
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text("Дата и время: $now",
                style: pw.TextStyle(font: font, fontSize: 10)),
            pw.SizedBox(height: 30),

            pw.Text("Подпись собственника:",
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Image(
                pw.MemoryImage(sig),
                width: 180,
                height: 80,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Text(
              "Данный документ является подтверждением участия в голосовании.\n"
              "Сохраните его для своих записей.",
              style: pw.TextStyle(
                  font: font, fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File(
          "${output.path}/Квитанция_голосования_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("Receipt PDF error: $e");
    }
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white : Colors.black87;
    final cardColor  = isDark ? const Color(0xFF1F2937) : Colors.white;
    final bgColor    = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              lang == 'ru' ? "Голосование ОСИ" : "ОСИ дауыс беруі",
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_isChairman) ...[
                IconButton(
                  tooltip: lang == 'ru'
                      ? "Новое голосование"
                      : "Жаңа дауыс беру",
                  icon: const Icon(LucideIcons.plusCircle,
                      color: Colors.green),
                  onPressed:
                      _isUploading ? null : _createNewProposal,
                ),
                IconButton(
                  tooltip: lang == 'ru'
                      ? "Скачать лист голосования (PDF)"
                      : "Дауыс парағын жүктеу (PDF)",
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blueAccent),
                        )
                      : const Icon(LucideIcons.fileText,
                          color: Colors.blueAccent),
                  onPressed:
                      _isUploading ? null : _downloadFullReport,
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── КАРТОЧКА ВОПРОСА ────────────────────────
                _buildQuestionCard(lang, isDark, cardColor, textColor),

                const SizedBox(height: 20),

                // ── СТАТИСТИКА (только председатель) ────────
                if (_isChairman)
                  _buildStatsCard(lang, isDark, cardColor, textColor),

                if (_isChairman) const SizedBox(height: 20),

                // ── КНОПКА ГОЛОСОВАНИЯ / БАННЕР ─────────────
                if (_hasVoted && !_isChairman)
                  _buildAlreadyVotedBanner(lang, isDark, cardColor)
                else if (!_isChairman) ...[
                  Text(
                    lang == 'ru' ? "Ваш выбор:" : "Сіздің таңдауыңыз:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.blueGrey,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildThreeChoiceButtons(lang, isDark),

                  const SizedBox(height: 28),

                  Text(
                    lang == 'ru' ? "ВАША ПОДПИСЬ:" : "ҚОЛТАҢБАҢЫЗ:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.blueGrey,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSignatureArea(lang, isDark),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          _isUploading ? null : _submitVote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: _isUploading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              lang == 'ru'
                                  ? "ОТПРАВИТЬ ГОЛОС"
                                  : "ДАУЫСТЫ ЖІБЕРУ",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── КАРТОЧКА С ВОПРОСОМ ────────────────────────────────────
  // Для председателя — тап по всей карточке открывает редактор
  Widget _buildQuestionCard(
      String lang, bool isDark, Color cardColor, Color textColor) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.vote,
                    color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang == 'ru'
                      ? "Вопрос голосования"
                      : "Дауыс беру сұрағы",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Иконка-карандаш всегда видна для председателя
              if (_isChairman)
                IconButton(
                  icon: const Icon(LucideIcons.edit3,
                      color: Colors.orange, size: 20),
                  onPressed: _editTitle,
                  tooltip: lang == 'ru'
                      ? "Редактировать вопрос"
                      : "Сұрақты өңдеу",
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
              color: textColor,
            ),
          ),
          if (_isChairman) ...[
            const SizedBox(height: 10),
            // Подсказка «нажмите чтобы изменить»
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.shield,
                      color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    lang == 'ru'
                        ? "Режим председателя · Нажмите ✏️ для изменения вопроса"
                        : "Төрағаның режимі · Сұрақты өзгерту үшін ✏️ басыңыз",
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          // Инфо о доме
          if (_buildingAddress.isNotEmpty || _totalApartments > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.building2,
                    size: 14, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buildingAddress.isNotEmpty
                        ? "$_buildingAddress · $_totalApartments кв."
                        : "$_totalApartments квартир в доме",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    // Для председателя — тап на карточку тоже открывает редактор
    if (_isChairman) {
      return GestureDetector(
        onTap: _editTitle,
        child: card,
      );
    }
    return card;
  }

  // ── СТАТИСТИКА ДЛЯ ПРЕДСЕДАТЕЛЯ ────────────────────────────
  Widget _buildStatsCard(
      String lang, bool isDark, Color cardColor, Color textColor) {
    final total = _yesCount + _noCount + _abstainCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ru' ? "Текущие результаты" : "Ағымдағы нәтижелер",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              // Кнопка обновить статистику
              GestureDetector(
                onTap: _loadStats,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh,
                      color: Colors.blueAccent, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lang == 'ru'
                ? "Проголосовало: $total из $_totalApartments квартир"
                : "Дауыс берді: $total из $_totalApartments пәтер",
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey),
          ),
          if (_totalApartments > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: total / _totalApartments,
              backgroundColor:
                  isDark ? Colors.white10 : Colors.grey.shade200,
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 2),
            Text(
              "${(total / _totalApartments * 100).toStringAsFixed(0)}% явка",
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.blueGrey),
            ),
          ],
          const SizedBox(height: 16),
          _buildStatBar(
              lang == 'ru' ? "За" : "Иә", _yesCount, total,
              Colors.green, isDark),
          const SizedBox(height: 8),
          _buildStatBar(
              lang == 'ru' ? "Против" : "Қарсы", _noCount, total,
              Colors.redAccent, isDark),
          const SizedBox(height: 8),
          _buildStatBar(
              lang == 'ru' ? "Воздержался" : "Қалыс қалды",
              _abstainCount, total, Colors.orange, isDark),
        ],
      ),
    );
  }

  Widget _buildStatBar(
      String label, int count, int total, Color color, bool isDark) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color:
                      isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$count",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
      ],
    );
  }

  // ── 3 КНОПКИ: ЗА / ПРОТИВ / ВОЗДЕРЖАЛСЯ ──────────────────
  Widget _buildThreeChoiceButtons(String lang, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildChoiceCard(
            value: 'yes',
            label: lang == 'ru' ? "ЗА" : "ИӘ",
            icon: LucideIcons.thumbsUp,
            color: Colors.green,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildChoiceCard(
            value: 'no',
            label: lang == 'ru' ? "ПРОТИВ" : "ҚАРСЫ",
            icon: LucideIcons.thumbsDown,
            color: Colors.redAccent,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildChoiceCard(
            value: 'abstain',
            label: lang == 'ru' ? "ВОЗДЕР-\nЖАЛСЯ" : "ҚАЛЫС\nҚАЛДЫ",
            icon: LucideIcons.minusCircle,
            color: Colors.orange,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _voteSelection == value;
    return GestureDetector(
      onTap: () => setState(() => _voteSelection = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1F2937) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : color, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ЗОНА ПОДПИСИ ───────────────────────────────────────────
  Widget _buildSignatureArea(String lang, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.blueAccent.withOpacity(0.4)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Signature(
            controller: _signatureController,
            height: 160,
            backgroundColor: Colors.transparent,
          ),
          Divider(
              height: 1,
              color: isDark ? Colors.black26 : Colors.grey.shade300),
          TextButton.icon(
            onPressed: () => _signatureController.clear(),
            icon: const Icon(Icons.refresh,
                size: 18, color: Colors.redAccent),
            label: Text(
              lang == 'ru'
                  ? "Очистить подпись"
                  : "Қолтаңбаны тазалау",
              style:
                  const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── БАННЕР "УЖЕ ПРОГОЛОСОВАЛ" ─────────────────────────────
  Widget _buildAlreadyVotedBanner(
      String lang, bool isDark, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.checkCircle,
              color: Colors.green, size: 48),
          const SizedBox(height: 12),
          Text(
            lang == 'ru'
                ? "Вы уже проголосовали"
                : "Сіз дауысыңызды бердіңіз",
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'ru'
                ? "Ваш голос был успешно учтён. Спасибо за участие!"
                : "Дауысыңыз сәтті есепке алынды. Қатысқаныңызға рахмет!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}