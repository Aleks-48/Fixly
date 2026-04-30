import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/utils/app_texts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ВАЖНО: Правильный импорт для Web, который не ломает мобильную сборку
import 'package:universal_html/html.dart' as html;

// ============================================================
//  DocumentsScreen — экран документов для председателя ОСИ
//
//  Шаблоны по законодательству РК:
//  1. Протокол собрания ОСИ (Закон РК «О жилищных отношениях»)
//  2. Лист голосования (форма письменного опроса)
//  3. Акт выполненных работ (Форма Р-1, Приказ МФ РК №562)
//  4. Уведомление должнику (претензия о задолженности)
// ============================================================
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategoryId = 'all';

  final List<Map<String, String>> _categories = [
    {'id': 'all',      'name_ru': 'Все',        'name_kk': 'Барлығы'},
    {'id': 'meetings', 'name_ru': 'Собрания',   'name_kk': 'Жиналыстар'},
    {'id': 'finance',  'name_ru': 'Финансы',    'name_kk': 'Қаржы'},
    {'id': 'debtors',  'name_ru': 'Должники',   'name_kk': 'Қарызгерлер'},
  ];

  // Каждый документ содержит поля для заполнения председателем
  final List<Map<String, dynamic>> _documents = [
    {
      'id': 'p1',
      'categoryId': 'meetings',
      'title_ru': 'Протокол собрания ОСИ',
      'title_kk': 'МҮБ жиналыс хаттамасы',
      'desc_ru': 'Официальный протокол (форма письменного опроса, ОСИ).',
      'desc_kk': 'Ресми хаттама (жазбаша сауалнама нысаны, МҮБ).',
      'ext': 'PDF',
      'fields': [
        'Наименование ОСИ',
        'Адрес многоквартирного дома',
        'Номер протокола',
        'Дата проведения',
        'Время начала',
        'Кол-во квартир в доме',
        'Кол-во нежилых помещений',
        'Кол-во участников голосования',
        'Кол-во голосов «ЗА»',
        'Кол-во голосов «Против»',
        'Кол-во воздержавшихся',
        'Повестка дня (каждый вопрос с новой строки)',
        'ФИО Председателя ОСИ',
        'ФИО Секретаря',
      ],
    },
    {
      'id': 'l1',
      'categoryId': 'meetings',
      'title_ru': 'Лист голосования',
      'title_kk': 'Дауыс беру парағы',
      'desc_ru': 'Форма для сбора подписей собственников (явочный/письменный опрос).',
      'desc_kk': 'Иелерінің қолдарын жинауға арналған нысан.',
      'ext': 'PDF',
      'fields': [
        'Наименование ОСИ',
        'Адрес многоквартирного дома',
        'Дата и время проведения',
        'Вопрос, вынесенный на голосование',
        'Кол-во строк (собственников)',
      ],
    },
    {
      'id': 'a1',
      'categoryId': 'finance',
      'title_ru': 'Акт выполненных работ (Р-1)',
      'title_kk': 'Орындалған жұмыс актісі (Р-1)',
      'desc_ru': 'Строгая форма Р-1 согласно Приказу МФ РК № 562 от 20.12.2012.',
      'desc_kk': '2012.12.20 № 562 ҚМ бұйрығына сәйкес Р-1 нысаны.',
      'ext': 'PDF',
      'fields': [
        'Заказчик (полное наименование ОСИ, адрес)',
        'БИН Заказчика',
        'Исполнитель (полное наименование ИП/ТОО, адрес)',
        'ИИН/БИН Исполнителя',
        'Номер акта',
        'Дата составления акта',
        'Наименование выполненных работ (услуг)',
        'Единица измерения',
        'Количество',
        'Цена за единицу (тенге)',
        'Итоговая сумма (тенге)',
        'ФИО Исполнителя (расшифровка подписи)',
        'ФИО Заказчика (расшифровка подписи)',
        'Дата подписания акта Заказчиком',
      ],
    },
    {
      'id': 'd1',
      'categoryId': 'debtors',
      'title_ru': 'Уведомление должнику',
      'title_kk': 'Қарызгерге хабарлама',
      'desc_ru': 'Официальная претензия о погашении задолженности по ОСИ.',
      'desc_kk': 'МҮБ бойынша берешекті өтеу туралы ресми талап-арыз.',
      'ext': 'PDF',
      'fields': [
        'Наименование ОСИ',
        'Адрес ОСИ',
        'ФИО Должника',
        'Номер квартиры',
        'Сумма задолженности (тенге)',
        'Период задолженности (например: январь–март 2025)',
        'Дата составления уведомления',
        'Срок погашения (до какой даты)',
        'ФИО Председателя ОСИ',
        'Контактный телефон ОСИ',
      ],
    },
  ];
  

  @override
  void initState() {
    super.initState();
  }

  // ── ГЕНЕРАЦИЯ PDF ──────────────────────────────────────────
Future<void> _generateAndOpenDocument(
    Map<String, dynamic> doc, Map<String, String> data, String lang) async {
  
  final pdf = pw.Document();
  final String docId = doc['id'];

  // Загружаем шрифты один раз для всех
  final font = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      build: (pw.Context ctx) {
        if (docId == 'p1') return _buildProtocolPages(data, font, fontBold);
        if (docId == 'l1') return _buildVotingSheetPages(data, font, fontBold);
        if (docId == 'a1') return _buildActR1Pages(data, font, fontBold);
        return _buildDebtorNoticePage(data, font, fontBold);
      },
    ),
  );

  try {
    if (kIsWeb) {
      // ИСПОЛЬЗУЕМ PRINTING ВМЕСТО HTML BLOB
      // Это исключает ошибку "Null check operator" в браузере
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'fixly_${docId}.pdf',
      );
    } else {
      // Логика для Android/iOS остается как была
      final bytes = await pdf.save();
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fixly_${docId}_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  } catch (e) {
    debugPrint("PDF error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }
}

  // ── ПРОТОКОЛ СОБРАНИЯ ──────────────────────────────────────
  List<pw.Widget> _buildProtocolPages(
      Map<String, String> d, pw.Font font, pw.Font fontBold) {
    final agendaRaw = d['Повестка дня (каждый вопрос с новой строки)'] ?? '';
    final agendaItems = agendaRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (agendaItems.isEmpty) {
      agendaItems.addAll(['Вопрос 1', 'Вопрос 2']);
    }

    final total = int.tryParse(d['Кол-во участников голосования'] ?? '0') ?? 0;
    final yes = int.tryParse(d["Кол-во голосов «ЗА»"] ?? '0') ?? 0;
    final no = int.tryParse(d["Кол-во голосов «Против»"] ?? '0') ?? 0;
    final abstain = int.tryParse(d['Кол-во воздержавшихся'] ?? '0') ?? 0;

    pw.Widget signLine(String role) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(children: [
            pw.Container(
                width: 160,
                child: pw.Text(role, style: pw.TextStyle(font: font, fontSize: 10))),
            pw.Text("______________________",
                style: pw.TextStyle(font: font, fontSize: 10)),
            pw.SizedBox(width: 10),
            pw.Text("(Ф.И.О. / подпись)",
                style: pw.TextStyle(font: font, fontSize: 8)),
          ]),
        );

    return [
      pw.Center(
        child: pw.Text(
          "ПРОТОКОЛ № ${d['Номер протокола'] ?? '___'}",
          style: pw.TextStyle(font: fontBold, fontSize: 14),
        ),
      ),
      pw.Center(
        child: pw.Text(
          "Общего собрания собственников имущества\n(проводимого путём письменного опроса)",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text(
          d['Наименование ОСИ'] ?? '',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
      ),
      pw.Divider(thickness: 1),
      pw.SizedBox(height: 8),

      pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(160),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          _tableRow2("Адрес дома:", d['Адрес многоквартирного дома'] ?? '', font, fontBold),
          _tableRow2("Дата:", d['Дата проведения'] ?? '', font, fontBold),
          _tableRow2("Время начала:", d['Время начала'] ?? '', font, fontBold),
          _tableRow2("Всего квартир:", d['Кол-во квартир в доме'] ?? '', font, fontBold),
          _tableRow2("Нежилых помещений:", d['Кол-во нежилых помещений'] ?? '', font, fontBold),
          _tableRow2("Участников голосования:", d['Кол-во участников голосования'] ?? '', font, fontBold),
        ],
      ),
      pw.SizedBox(height: 16),

      pw.Text("ПОВЕСТКА ДНЯ:", style: pw.TextStyle(font: fontBold, fontSize: 11)),
      pw.SizedBox(height: 6),
      ...agendaItems.asMap().entries.map((e) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
            child: pw.Text("${e.key + 1}. ${e.value}",
                style: pw.TextStyle(font: font, fontSize: 10)),
          )),
      pw.SizedBox(height: 16),

      pw.Text("ИТОГИ ГОЛОСОВАНИЯ:", style: pw.TextStyle(font: fontBold, fontSize: 11)),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FixedColumnWidth(60),
          2: const pw.FixedColumnWidth(80),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _cellPad("Вариант решения", fontBold, 9),
              _cellPad("Голосов", fontBold, 9),
              _cellPad("% от участников", fontBold, 9),
            ],
          ),
          pw.TableRow(children: [
            _cellPad("ЗА", font, 10),
            _cellPad("$yes", fontBold, 10),
            _cellPad(total > 0 ? "${(yes / total * 100).toStringAsFixed(1)}%" : "—", font, 10),
          ]),
          pw.TableRow(children: [
            _cellPad("ПРОТИВ", font, 10),
            _cellPad("$no", fontBold, 10),
            _cellPad(total > 0 ? "${(no / total * 100).toStringAsFixed(1)}%" : "—", font, 10),
          ]),
          pw.TableRow(children: [
            _cellPad("ВОЗДЕРЖАЛИСЬ", font, 10),
            _cellPad("$abstain", fontBold, 10),
            _cellPad(total > 0 ? "${(abstain / total * 100).toStringAsFixed(1)}%" : "—", font, 10),
          ]),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cellPad("ИТОГО", fontBold, 10),
              _cellPad("$total", fontBold, 10),
              _cellPad("100%", fontBold, 10),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),

      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          yes > (total / 2)
              ? "РЕШЕНИЕ: ПРИНЯТО. Большинство собственников проголосовали «ЗА»."
              : "РЕШЕНИЕ: НЕ ПРИНЯТО. Большинство собственников не набрано.",
          style: pw.TextStyle(font: fontBold, fontSize: 10),
        ),
      ),
      pw.SizedBox(height: 30),

      pw.Text("ПОДПИСИ:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
      pw.SizedBox(height: 10),
      signLine("Председатель ОСИ:"),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 160, bottom: 14),
        child: pw.Text("(${d['ФИО Председателя ОСИ'] ?? ''})",
            style: pw.TextStyle(font: font, fontSize: 9)),
      ),
      signLine("Секретарь собрания:"),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 160, bottom: 14),
        child: pw.Text("(${d['ФИО Секретаря'] ?? ''})",
            style: pw.TextStyle(font: font, fontSize: 9)),
      ),
    ];
  }

  // ── ЛИСТ ГОЛОСОВАНИЯ ───────────────────────────────────────
  List<pw.Widget> _buildVotingSheetPages(
      Map<String, String> d, pw.Font font, pw.Font fontBold) {
    final rowCount = int.tryParse(d['Кол-во строк (собственников)'] ?? '20') ?? 20;

    return [
      pw.Center(
        child: pw.Text(
          "ЛИСТ ГОЛОСОВАНИЯ",
          style: pw.TextStyle(font: fontBold, fontSize: 14),
        ),
      ),
      pw.Center(
        child: pw.Text(
          "собственников квартир и нежилых помещений",
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
      ),
      pw.Center(
        child: pw.Text(
          "проголосовавших на общем собрании (путём письменного опроса)",
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ),
      pw.Divider(thickness: 1),
      pw.SizedBox(height: 8),
      pw.Text(
        "Наименование ОСИ: ${d['Наименование ОСИ'] ?? ''}",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        "Адрес многоквартирного жилого дома: ${d['Адрес многоквартирного дома'] ?? ''}",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        "Дата и время проведения: ${d['Дата и время проведения'] ?? ''}",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        "Вопрос, вынесенный на голосование:",
        style: pw.TextStyle(font: fontBold, fontSize: 10),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(top: 4, bottom: 14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          d['Вопрос, вынесенный на голосование'] ?? '',
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
      ),

      pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(width: 0.5),
        headerStyle: pw.TextStyle(font: fontBold, fontSize: 8),
        cellStyle: pw.TextStyle(font: font, fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        headerAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
          5: pw.Alignment.center,
        },
        cellAlignments: {
          0: pw.Alignment.center,
          2: pw.Alignment.center,
        },
        columnWidths: {
          0: const pw.FixedColumnWidth(22),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FixedColumnWidth(30),
          3: const pw.FlexColumnWidth(1.2),
          4: const pw.FlexColumnWidth(1.2),
          5: const pw.FlexColumnWidth(1.4),
        },
        data: [
          ['№', 'Фамилия Имя Отчество\n(при его наличии)', '№\nкв.', 'ЗА\n(подпись)', 'ПРОТИВ\n(подпись)', 'ВОЗДЕРЖАЛСЯ\n(подпись)'],
          ...List.generate(rowCount, (i) => ['${i + 1}', '', '', '', '', '']),
        ],
      ),

      pw.SizedBox(height: 24),
      pw.Text(
        "Председатель собрания: ____________________________     __________",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        "                                                                       (Ф.И.О.)                           (подпись)",
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        "Секретарь собрания:   ____________________________     __________",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        "                                                                       (Ф.И.О.)                           (подпись)",
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    ];
  }

  // ── АКТ ВЫПОЛНЕННЫХ РАБОТ (Р-1) ───────────────────────────
  List<pw.Widget> _buildActR1Pages(
      Map<String, String> d, pw.Font font, pw.Font fontBold) {
    return [
      pw.Align(
        alignment: pw.Alignment.topRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Приложение 50", style: pw.TextStyle(font: fontBold, fontSize: 8)),
            pw.Text("к приказу Министра финансов", style: pw.TextStyle(font: font, fontSize: 7)),
            pw.Text("Республики Казахстан", style: pw.TextStyle(font: font, fontSize: 7)),
            pw.Text("от 20 декабря 2012 года № 562", style: pw.TextStyle(font: font, fontSize: 7)),
            pw.SizedBox(height: 4),
            pw.Text("Форма Р-1", style: pw.TextStyle(font: fontBold, fontSize: 9)),
          ],
        ),
      ),
      pw.SizedBox(height: 8),

      pw.Align(
        alignment: pw.Alignment.topRight,
        child: pw.Container(
          width: 140,
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(children: [
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text("ИИН/БИН", style: pw.TextStyle(font: font, fontSize: 7)),
                  ),
                ),
              ]),
              pw.TableRow(children: [
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      d['БИН Заказчика'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                  ),
                ),
              ]),
              pw.TableRow(children: [pw.SizedBox(height: 2)]),
              pw.TableRow(children: [
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      d['ИИН/БИН Исполнителя'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),

      pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(70),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(children: [
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text("Заказчик", style: pw.TextStyle(font: font, fontSize: 9))),
            pw.Column(children: [
              pw.Center(
                  child: pw.Text(d['Заказчик (полное наименование ОСИ, адрес)'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center)),
              pw.Divider(thickness: 0.5, height: 1),
              pw.Text("полное наименование, адрес",
                  style: pw.TextStyle(font: font, fontSize: 6)),
            ]),
          ]),
          pw.TableRow(children: [pw.SizedBox(height: 10), pw.SizedBox()]),
          pw.TableRow(children: [
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text("Исполнитель", style: pw.TextStyle(font: font, fontSize: 9))),
            pw.Column(children: [
              pw.Center(
                  child: pw.Text(d['Исполнитель (полное наименование ИП/ТОО, адрес)'] ?? '',
                      style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center)),
              pw.Divider(thickness: 0.5, height: 1),
              pw.Text("полное наименование, адрес",
                  style: pw.TextStyle(font: font, fontSize: 6)),
            ]),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),

      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Row(children: [
              pw.Text("Договор (контракт)", style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(width: 4),
              pw.Expanded(child: pw.Column(children: [
                pw.Text(
                  d['Номер акта'] != null && (d['Номер акта'] ?? '').isNotEmpty
                      ? "№ ${d['Номер акта']}"
                      : "Без договора",
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Divider(thickness: 0.5, height: 1),
              ])),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 160,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                pw.TableRow(children: [
                  pw.Center(child: pw.Text("Номер документа",
                      style: pw.TextStyle(font: font, fontSize: 7))),
                  pw.Center(child: pw.Text("Дата составления",
                      style: pw.TextStyle(font: font, fontSize: 7))),
                ]),
                pw.TableRow(children: [
                  pw.Center(
                      child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d['Номер акта'] ?? '1',
                              style: pw.TextStyle(font: fontBold, fontSize: 8)))),
                  pw.Center(
                      child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(d['Дата составления акта'] ?? '',
                              style: pw.TextStyle(font: fontBold, fontSize: 8)))),
                ]),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 14),
      pw.Center(
          child: pw.Text("АКТ ВЫПОЛНЕННЫХ РАБОТ (ОКАЗАННЫХ УСЛУГ)",
              style: pw.TextStyle(font: fontBold, fontSize: 10))),
      pw.SizedBox(height: 10),

      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(22),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FixedColumnWidth(48),
          3: const pw.FixedColumnWidth(38),
          4: const pw.FixedColumnWidth(38),
          5: const pw.FixedColumnWidth(32),
          6: const pw.FixedColumnWidth(48),
          7: const pw.FixedColumnWidth(52),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cellCenter("Номер по порядку", font, 6),
              _cellCenter("Наименование работ (услуг)\nв соответствии с технической спецификацией", font, 6),
              _cellCenter("Дата выполнения работ", font, 6),
              _cellCenter("Сведения об отчёте", font, 6),
              _cellCenter("Ед. изм.", font, 6),
              _cellCenter("Кол-во", font, 6),
              _cellCenter("Цена за единицу", font, 6),
              _cellCenter("Стоимость", font, 6),
            ],
          ),
          pw.TableRow(
            children: List.generate(8, (i) => _cellCenter("${i + 1}", font, 6)),
          ),
          pw.TableRow(children: [
            _cellCenter("1", font, 9),
            pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(d['Наименование выполненных работ (услуг)'] ?? '',
                    style: pw.TextStyle(font: font, fontSize: 8))),
            _cellCenter(d['Дата составления акта'] ?? '', font, 7),
            _cellCenter("—", font, 8),
            _cellCenter(d['Единица измерения'] ?? 'усл.', font, 8),
            _cellCenter(d['Количество'] ?? '1', font, 8),
            _cellCenter(d['Цена за единицу (тенге)'] ?? '', font, 8),
            _cellCenter(d['Итоговая сумма (тенге)'] ?? '', fontBold, 8),
          ]),
          pw.TableRow(children: [
            pw.Text(""), pw.Text(""), pw.Text(""), pw.Text(""),
            pw.Padding(
                padding: const pw.EdgeInsets.only(right: 4),
                child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("Итого", style: pw.TextStyle(font: fontBold, fontSize: 8)))),
            _cellCenter(d['Количество'] ?? '1', fontBold, 8),
            pw.Text(""),
            _cellCenter(d['Итоговая сумма (тенге)'] ?? '', fontBold, 8),
          ]),
        ],
      ),

      pw.SizedBox(height: 8),
      pw.Text(
        "Сведения об использовании запасов, полученных от заказчика: ___________________________",
        style: pw.TextStyle(font: font, fontSize: 7),
      ),
      pw.SizedBox(height: 2),
      pw.Center(
          child: pw.Text("наименование, количество, стоимость",
              style: pw.TextStyle(font: font, fontSize: 6))),
      pw.Divider(thickness: 0.5),
      pw.Text(
        "Приложение: Перечень документации _____ страниц",
        style: pw.TextStyle(font: font, fontSize: 7),
      ),
      pw.SizedBox(height: 16),

      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text("Сдал (Исполнитель)", style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Column(children: [
                  pw.SizedBox(width: 60, child: pw.Divider(thickness: 0.5)),
                  pw.Text("должность", style: pw.TextStyle(font: font, fontSize: 5)),
                ]),
                pw.SizedBox(width: 5),
                pw.Column(children: [
                  pw.SizedBox(width: 50, child: pw.Divider(thickness: 0.5)),
                  pw.Text("подпись", style: pw.TextStyle(font: font, fontSize: 5)),
                ]),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(d['ФИО Исполнителя (расшифровка подписи)'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text("М.П.", style: pw.TextStyle(font: fontBold, fontSize: 8)),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text("Принял (Заказчик)", style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Column(children: [
                  pw.SizedBox(width: 60, child: pw.Divider(thickness: 0.5)),
                  pw.Text("должность", style: pw.TextStyle(font: font, fontSize: 5)),
                ]),
                pw.SizedBox(width: 5),
                pw.Column(children: [
                  pw.SizedBox(width: 50, child: pw.Divider(thickness: 0.5)),
                  pw.Text("подпись", style: pw.TextStyle(font: font, fontSize: 5)),
                ]),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(d['ФИО Заказчика (расшифровка подписи)'] ?? '',
                  style: pw.TextStyle(font: font, fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text(
                "Дата подписания (принятия) работ: ${d['Дата подписания акта Заказчиком'] ?? '____________'}",
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
              pw.SizedBox(height: 4),
              pw.Text("М.П.", style: pw.TextStyle(font: fontBold, fontSize: 8)),
            ]),
          ),
        ],
      ),
    ];
  }

  // ── УВЕДОМЛЕНИЕ ДОЛЖНИКУ ───────────────────────────────────
  List<pw.Widget> _buildDebtorNoticePage(
      Map<String, String> d, pw.Font font, pw.Font fontBold) {
    return [
      pw.Align(
        alignment: pw.Alignment.topRight,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("Собственнику квартиры № ${d['Номер квартиры'] ?? '___'}",
              style: pw.TextStyle(font: fontBold, fontSize: 10)),
          pw.Text(d['ФИО Должника'] ?? '',
              style: pw.TextStyle(font: fontBold, fontSize: 10)),
        ]),
      ),
      pw.SizedBox(height: 6),
      pw.Align(
        alignment: pw.Alignment.topLeft,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("От: ${d['Наименование ОСИ'] ?? ''}",
              style: pw.TextStyle(font: font, fontSize: 9)),
          pw.Text("Адрес: ${d['Адрес ОСИ'] ?? ''}",
              style: pw.TextStyle(font: font, fontSize: 9)),
          pw.Text("Тел.: ${d['Контактный телефон ОСИ'] ?? ''}",
              style: pw.TextStyle(font: font, fontSize: 9)),
        ]),
      ),
      pw.SizedBox(height: 20),
      pw.Divider(thickness: 1),

      pw.Center(
        child: pw.Text(
          "УВЕДОМЛЕНИЕ О НАЛИЧИИ ЗАДОЛЖЕННОСТИ",
          style: pw.TextStyle(font: fontBold, fontSize: 13),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          "по обязательным взносам на содержание общего имущества многоквартирного жилого дома",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ),
      pw.SizedBox(height: 20),

      pw.Text(
        "Уважаемый(ая) ${d['ФИО Должника'] ?? '_______________'}!",
        style: pw.TextStyle(font: fontBold, fontSize: 11),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        "Настоящим уведомляем Вас о том, что по Вашей квартире/нежилому помещению "
        "№ ${d['Номер квартиры'] ?? '___'} образовалась задолженность по обязательным "
        "взносам на содержание общего имущества многоквартирного жилого дома:",
        style: pw.TextStyle(font: font, fontSize: 11),
      ),
      pw.SizedBox(height: 14),

      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _cellPad("Показатель", fontBold, 10),
              _cellPad("Значение", fontBold, 10),
            ],
          ),
          pw.TableRow(children: [
            _cellPad("Период задолженности", font, 10),
            _cellPad(d['Период задолженности (например: январь–март 2025)'] ?? '', fontBold, 10),
          ]),
          pw.TableRow(children: [
            _cellPad("Сумма задолженности", font, 10),
            _cellPad("${d['Сумма задолженности (тенге)'] ?? ''} тенге", fontBold, 11),
          ]),
          pw.TableRow(children: [
            _cellPad("Срок погашения", font, 10),
            _cellPad("до ${d['Срок погашения (до какой даты)'] ?? ''}",
                fontBold, 10),
          ]),
        ],
      ),
      pw.SizedBox(height: 14),

      pw.Text(
        "В случае непогашения указанной задолженности в установленный срок, "
        "${d['Наименование ОСИ'] ?? 'ОСИ'} оставляет за собой право обратиться "
        "в суд с иском о взыскании задолженности и судебных расходов в соответствии "
        "с законодательством Республики Казахстан.",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        "Для уточнения суммы задолженности и реквизитов оплаты, а также "
        "заключения соглашения о рассрочке просим обратиться к председателю ОСИ.",
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 30),

      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Дата: ${d['Дата составления уведомления'] ?? '____________'}",
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.SizedBox(width: 40),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("Председатель ОСИ: ____________________________",
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text("                             ${d['ФИО Председателя ОСИ'] ?? ''}",
                style: pw.TextStyle(font: font, fontSize: 9)),
          ]),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Text("М.П.", style: pw.TextStyle(font: fontBold, fontSize: 10)),
    ];
  }

  // ── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ PDF ────────────────────────────
  pw.Widget _cellPad(String text, pw.Font font, double size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: size)),
    );
  }

  pw.Widget _cellCenter(String text, pw.Font font, double size) {
    return pw.Center(
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: size),
            textAlign: pw.TextAlign.center),
      ),
    );
  }

  pw.TableRow _tableRow2(
      String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ),
    ]);
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final filteredDocs = _selectedCategoryId == 'all'
            ? _documents
            : _documents.where((d) => d['categoryId'] == _selectedCategoryId).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(
              AppTexts.get('documents', lang),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1),
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shield, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang == 'ru'
                            ? "Раздел председателя ОСИ • Документы по законодательству РК"
                            : "МҮБ төрағасының бөлімі • ҚР заңнамасы бойынша құжаттар",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildCategoriesRow(isDark, lang),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) =>
                      _buildDocumentCard(filteredDocs[index], isDark, lang),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── СТРОКА КАТЕГОРИЙ ───────────────────────────────────────
  Widget _buildCategoriesRow(bool isDark, String lang) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategoryId == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(lang == 'ru' ? cat['name_ru']! : cat['name_kk']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategoryId = cat['id']!),
              selectedColor: Colors.blueAccent,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── КАРТОЧКА ДОКУМЕНТА ─────────────────────────────────────
  Widget _buildDocumentCard(Map<String, dynamic> doc, bool isDark, String lang) {
    final Color accentColor = _getDocColor(doc['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getDocIcon(doc['id']), color: accentColor, size: 22),
        ),
        title: Text(
          lang == 'ru' ? doc['title_ru'] : doc['title_kk'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lang == 'ru' ? doc['desc_ru'] : doc['desc_kk'],
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(doc['ext'],
                    style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lang == 'ru' ? "Форма РК" : "ҚР нысаны",
                  style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ],
        ),
        trailing: Icon(LucideIcons.chevronRight, color: isDark ? Colors.white38 : Colors.black26),
        onTap: () {
          _showWizard(doc, isDark, lang);
        },
      ),
    );
  }

  // ── МАСТЕР ЗАПОЛНЕНИЯ ПОЛЕЙ ────────────────────────────────
  void _showWizard(Map<String, dynamic> doc, bool isDark, String lang) {
    final List<String> fields = List<String>.from(doc['fields']);
    final Map<String, TextEditingController> controllers = {
      for (final f in fields) f: TextEditingController(),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Text(
              lang == 'ru' ? doc['title_ru'] : doc['title_kk'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              lang == 'ru' ? "Заполните все поля" : "Барлық өрістерді толтырыңыз",
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[f],
                      maxLines: f.contains('Повестка') || f.contains('Наименование выполненных')
                          ? 3
                          : 1,
                      keyboardType: (f.contains('Кол-во') ||
                              f.contains('Сумма') ||
                              f.contains('БИН') ||
                              f.contains('ИИН') ||
                              f.contains('Цена') ||
                              f.contains('Количество'))
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: f,
                        labelStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.fileDown, size: 18, color: Colors.white),
                label: Text(
                  lang == 'ru' ? "Создать PDF документ" : "PDF құжатын жасау",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  final inputData = controllers.map((k, v) => MapEntry(k, v.text));
                  Navigator.pop(ctx);
                  _generateAndOpenDocument(doc, inputData, lang);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDocColor(String id) {
    switch (id) {
      case 'p1': return Colors.blueAccent;
      case 'l1': return Colors.purple;
      case 'a1': return Colors.orange;
      case 'd1': return Colors.redAccent;
      default:   return Colors.grey;
    }
  }

  IconData _getDocIcon(String id) {
    switch (id) {
      case 'p1': return LucideIcons.clipboardList;
      case 'l1': return LucideIcons.vote;
      case 'a1': return LucideIcons.receipt;
      case 'd1': return LucideIcons.alertCircle;
      default:   return LucideIcons.file;
    }
  }
}