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

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategoryId = 'all';

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'name_ru': 'Все', 'name_kk': 'Барлығы'},
    {'id': 'meetings', 'name_ru': 'Собрания', 'name_kk': 'Жиналыстар'},
    {'id': 'finance', 'name_ru': 'Финансы', 'name_kk': 'Қаржы'},
    {'id': 'debtors', 'name_ru': 'Должники', 'name_kk': 'Қарызгерлер'},
  ];

  final List<Map<String, dynamic>> _documents = [
    {
      'id': 'p1', 
      'categoryId': 'meetings',
      'title_ru': 'Протокол собрания ОСИ', 
      'title_kk': 'МҮБ жиналыс хаттамасы',
      'desc_ru': 'Официальный протокол (письменный опрос).', 
      'desc_kk': 'Ресми хаттама (жазбаша сауалнама).',
      'is_premium': false, 
      'price': 0, 
      'ext': 'PDF', 
      'fields': ['Номер протокола', 'Дата', 'Время', 'Адрес дома', 'Кол-во квартир', 'Кол-во нежилых', 'Кол-во участников', 'Вопросы (через запятую)']
    },
    {
      'id': 'l1', 
      'categoryId': 'meetings',
      'title_ru': 'Лист голосования', 
      'title_kk': 'Дауыс беру парағы',
      'desc_ru': 'Таблица для сбора подписей (За/Против/Воздержался).', 
      'desc_kk': 'Қол жинауға арналған кесте.',
      'is_premium': true, 
      'price': 500, 
      'ext': 'PDF',
      'fields': ['Адрес дома', 'Вопрос для голосования']
    },
    {
      'id': 'a1', 
      'categoryId': 'finance',
      'title_ru': 'Акт выполненных работ (Р-1)', 
      'title_kk': 'Орындалған жұмыс актісі (Р-1)',
      'desc_ru': 'Строгая форма Р-1 согласно Приказу 562.', 
      'desc_kk': '50-қосымшаға сәйкес Р-1 нысаны.',
      'is_premium': true, 
      'price': 1500, 
      'ext': 'PDF',
      'fields': ['Заказчик (ОСИ)', 'БИН Заказчика', 'Исполнитель (ИП)', 'ИИН/БИН Исполнителя', 'Номер договора', 'Дата договора', 'Наименование работ', 'Сумма']
    },
    {
      'id': 'd1', 
      'categoryId': 'debtors',
      'title_ru': 'Уведомление должнику', 
      'title_kk': 'Қарызгерге хабарлама',
      'desc_ru': 'Претензия о погашении задолженности.', 
      'desc_kk': 'Берешекті өтеу туралы талап-арыз.',
      'is_premium': true, 
      'price': 700, 
      'ext': 'PDF',
      'fields': ['ФИО Должника', 'Номер квартиры', 'Сумма долга', 'Срок оплаты']
    },
  ];

  Future<void> _generateAndOpenDocument(Map<String, dynamic> doc, Map<String, String> userInput, String lang) async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoMedium();
    
    final String docId = doc['id'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          
          // ==========================================
          // ШАБЛОН: АКТ ВЫПОЛНЕННЫХ РАБОТ (ФОРМА Р-1)
          // СТРОГО ПО ШАБЛОНУ ИЗ СКРИНШОТА
          // ==========================================
          if (docId == 'a1') {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Шапка справа сверху
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Приложение 50", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      pw.Text("к приказу Министра финансов", style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text("Республики Казахстан", style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.Text("от 20 декабря 2012 года № 562", style: pw.TextStyle(font: font, fontSize: 7)),
                      pw.SizedBox(height: 5),
                      pw.Text("Форма Р-1", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ],
                  ),
                ),
                
                // Таблица ИИН/БИН справа
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Container(
                    width: 120,
                    margin: const pw.EdgeInsets.only(top: 5, bottom: 10),
                    child: pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      children: [
                        pw.TableRow(children: [
                          pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text("ИИН/БИН", style: pw.TextStyle(font: font, fontSize: 7)))),
                        ]),
                        pw.TableRow(children: [
                          pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(userInput['БИН Заказчика'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 9)))),
                        ]),
                        pw.TableRow(children: [
                          pw.SizedBox(height: 4),
                        ]),
                        pw.TableRow(children: [
                          pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(userInput['ИИН/БИН Исполнителя'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 9)))),
                        ]),
                      ],
                    ),
                  ),
                ),

                // Заказчик и Исполнитель
                pw.Table(
                  columnWidths: {0: const pw.FixedColumnWidth(70), 1: const pw.FlexColumnWidth()},
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.only(top: 5), child: pw.Text("Заказчик", style: pw.TextStyle(font: font, fontSize: 8))),
                      pw.Column(children: [
                        pw.Center(child: pw.Text(userInput['Заказчик (ОСИ)'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                        pw.Divider(thickness: 0.5, height: 1),
                        pw.Text("полное наименование, адрес, данные о средствах связи", style: pw.TextStyle(font: font, fontSize: 6)),
                      ]),
                    ]),
                    pw.TableRow(children: [pw.SizedBox(height: 10), pw.SizedBox()]),
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.only(top: 5), child: pw.Text("Исполнитель", style: pw.TextStyle(font: font, fontSize: 8))),
                      pw.Column(children: [
                        pw.Center(child: pw.Text(userInput['Исполнитель (ИП)'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                        pw.Divider(thickness: 0.5, height: 1),
                        pw.Text("полное наименование, адрес, данные о средствах связи", style: pw.TextStyle(font: font, fontSize: 6)),
                      ]),
                    ]),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Договор и Номер документа
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Row(children: [
                        pw.Text("Договор (контракт)", style: pw.TextStyle(font: font, fontSize: 8)),
                        pw.SizedBox(width: 5),
                        pw.Expanded(child: pw.Column(children: [
                          pw.Text(userInput['Номер договора'] ?? "________", style: pw.TextStyle(font: font, fontSize: 8)),
                          pw.Divider(thickness: 0.5, height: 1),
                        ])),
                      ]),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Container(
                      width: 150,
                      child: pw.Table(
                        border: pw.TableBorder.all(width: 0.5),
                        children: [
                          pw.TableRow(children: [
                            pw.Center(child: pw.Text("Номер документа", style: pw.TextStyle(font: font, fontSize: 7))),
                            pw.Center(child: pw.Text("Дата составления", style: pw.TextStyle(font: font, fontSize: 7))),
                          ]),
                          pw.TableRow(children: [
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text("1", style: pw.TextStyle(font: fontBold, fontSize: 8)))),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(userInput['Дата договора'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 8)))),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text("АКТ ВЫПОЛНЕННЫХ РАБОТ (ОКАЗАННЫХ УСЛУГ)", style: pw.TextStyle(font: fontBold, fontSize: 10))),
                pw.SizedBox(height: 10),

                // ГЛАВНАЯ ТАБЛИЦА Р-1 (8 КОЛОНОК)
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(25),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FixedColumnWidth(50),
                    3: const pw.FixedColumnWidth(40),
                    4: const pw.FixedColumnWidth(40),
                    5: const pw.FixedColumnWidth(35),
                    6: const pw.FixedColumnWidth(45),
                    7: const pw.FixedColumnWidth(50),
                  },
                  children: [
                    // Заголовки
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text("Номер по порядку", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center))),
                        pw.Center(child: pw.Text("Наименование работ (услуг)", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Дата выполнения", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Сведения об отчете", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Ед. изм.", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Кол-во", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Цена за ед.", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                        pw.Center(child: pw.Text("Стоимость", style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center)),
                      ],
                    ),
                    // Нумерация (1-8)
                    pw.TableRow(
                      children: List.generate(8, (i) => pw.Center(child: pw.Text("${i + 1}", style: pw.TextStyle(font: font, fontSize: 6)))),
                    ),
                    // Строка с данными
                    pw.TableRow(
                      children: [
                        pw.Center(child: pw.Text("1", style: pw.TextStyle(font: font, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(userInput['Наименование работ'] ?? "", style: pw.TextStyle(font: font, fontSize: 8))),
                        pw.Center(child: pw.Text(userInput['Дата договора'] ?? "", style: pw.TextStyle(font: font, fontSize: 7))),
                        pw.Text(""),
                        pw.Center(child: pw.Text("усл.", style: pw.TextStyle(font: font, fontSize: 8))),
                        pw.Center(child: pw.Text("1", style: pw.TextStyle(font: font, fontSize: 8))),
                        pw.Center(child: pw.Text(userInput['Сумма'] ?? "", style: pw.TextStyle(font: font, fontSize: 8))),
                        pw.Center(child: pw.Text(userInput['Сумма'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ],
                    ),
                    // Итого
                    pw.TableRow(
                      children: [
                        pw.Text(""), pw.Text(""), pw.Text(""), pw.Text(""),
                        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Padding(padding: const pw.EdgeInsets.only(right: 4), child: pw.Text("Итого", style: pw.TextStyle(font: fontBold, fontSize: 8)))),
                        pw.Center(child: pw.Text("1", style: pw.TextStyle(font: fontBold, fontSize: 8))),
                        pw.Text(""),
                        pw.Center(child: pw.Text(userInput['Сумма'] ?? "", style: pw.TextStyle(font: fontBold, fontSize: 8))),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Text("Сведения об использовании запасов, полученных от заказчика: отсутствуют", style: pw.TextStyle(font: font, fontSize: 7)),
                pw.Divider(thickness: 0.5),

                pw.SizedBox(height: 20),
                // Подписи сторон
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Сдал (Исполнитель)", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          pw.SizedBox(height: 10),
                          pw.Row(children: [
                            pw.Column(children: [pw.SizedBox(width: 70, child: pw.Divider(thickness: 0.5)), pw.Text("должность", style: pw.TextStyle(fontSize: 5))]),
                            pw.SizedBox(width: 5),
                            pw.Column(children: [pw.SizedBox(width: 60, child: pw.Divider(thickness: 0.5)), pw.Text("подпись", style: pw.TextStyle(fontSize: 5))]),
                          ]),
                          pw.SizedBox(height: 5),
                          pw.Text(userInput['Исполнитель (ИП)'] ?? "", style: pw.TextStyle(font: font, fontSize: 8)),
                          pw.Text("М.П.", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        ]
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Принял (Заказчик)", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          pw.SizedBox(height: 10),
                          pw.Row(children: [
                            pw.Column(children: [pw.SizedBox(width: 70, child: pw.Divider(thickness: 0.5)), pw.Text("должность", style: pw.TextStyle(fontSize: 5))]),
                            pw.SizedBox(width: 5),
                            pw.Column(children: [pw.SizedBox(width: 60, child: pw.Divider(thickness: 0.5)), pw.Text("подпись", style: pw.TextStyle(fontSize: 5))]),
                          ]),
                          pw.SizedBox(height: 5),
                          pw.Text("Дата принятия работ: ________________", style: pw.TextStyle(font: font, fontSize: 7)),
                          pw.Text("М.П.", style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        ]
                      ),
                    ),
                  ],
                ),
              ],
            );
          } 
          
          // ==========================================
          // ШАБЛОН: ПРОТОКОЛ СОБРАНИЯ (БЕЗ ИЗМЕНЕНИЙ)
          // ==========================================
          else if (docId == 'p1') {
            String rawAgenda = userInput['Вопросы (через запятую)'] ?? '';
            List<String> agendaItems = rawAgenda.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (agendaItems.isEmpty) {
              agendaItems = ["Отказ от КСП", "Выбор формы ОСИ", "Выбор председателя", "Утверждение Устава"];
            }

            pw.Widget buildSignatureRow(String role) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  children: [
                    pw.Container(width: 140, child: pw.Text(role, style: pw.TextStyle(font: font, fontSize: 10))),
                    pw.Text("____________________", style: pw.TextStyle(font: font)),
                    pw.SizedBox(width: 10),
                    pw.Text("(Ф.И.О / Подпись)", style: pw.TextStyle(font: font, fontSize: 8)),
                  ]
                )
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("Протокол № ${userInput['Номер протокола']}", style: pw.TextStyle(font: fontBold, fontSize: 12))),
                pw.Center(child: pw.Text("Собрания собственников имущества (письменный опрос)", style: pw.TextStyle(font: fontBold, fontSize: 10))),
                pw.SizedBox(height: 15),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Время: ${userInput['Время']}", style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text("Дата: ${userInput['Дата']}", style: pw.TextStyle(font: font, fontSize: 10)),
                ]),
                pw.SizedBox(height: 10),
                pw.Text("Адрес: ${userInput['Адрес дома']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text("Всего квартир: ${userInput['Кол-во квартир']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text("Участвовало: ${userInput['Кол-во участников']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 15),
                pw.Text("Повестка дня:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                ...agendaItems.asMap().entries.map((e) => pw.Text("${e.key + 1}. ${e.value}", style: pw.TextStyle(font: font, fontSize: 10))),
                pw.Spacer(),
                buildSignatureRow("Председатель:"),
                buildSignatureRow("Секретарь:"),
                buildSignatureRow("Совет дома:"),
              ],
            );
          }

          // ==========================================
          // ШАБЛОН: ЛИСТ ГОЛОСОВАНИЯ (БЕЗ ИЗМЕНЕНИЙ)
          // ==========================================
          else if (docId == 'l1') {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("ЛИСТ ГОЛОСОВАНИЯ", style: pw.TextStyle(font: fontBold, fontSize: 14))),
                pw.SizedBox(height: 15),
                pw.Text("Адрес: ${userInput['Адрес дома']}", style: pw.TextStyle(font: fontBold)),
                pw.Text("Вопрос: ${userInput['Вопрос для голосования']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 15),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  headers: ['№', 'ФИО собственника', '№ кв.', 'ЗА', 'ПРОТИВ', 'ВОЗД.'],
                  data: List.generate(15, (i) => ['${i + 1}', '', '', '', '', '']),
                ),
              ],
            );
          }

          // ==========================================
          // ШАБЛОН: УВЕДОМЛЕНИЕ (БЕЗ ИЗМЕНЕНИЙ)
          // ==========================================
          else {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Align(alignment: pw.Alignment.topRight, child: pw.Text("Квартира № ${userInput['Номер квартиры']}\n${userInput['ФИО Должника']}", style: pw.TextStyle(font: fontBold, fontSize: 11))),
                pw.SizedBox(height: 30),
                pw.Center(child: pw.Text("УВЕДОМЛЕНИЕ О ЗАДОЛЖЕННОСТИ", style: pw.TextStyle(font: fontBold, fontSize: 14))),
                pw.SizedBox(height: 20),
                pw.Text("Уважаемый(ая) ${userInput['ФИО Должника']}!", style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Text("Сообщаем Вам, что по вашей квартире числится долг в размере ${userInput['Сумма долга']} тенге. Просим погасить его до ${userInput['Срок оплаты']}.", style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 40),
                pw.Text("Председатель ОСИ ____________________", style: pw.TextStyle(font: fontBold, fontSize: 12)),
              ],
            );
          }
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fixly_${docId}_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("Ошибка генерации PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        final filteredDocs = _selectedCategoryId == 'all'
            ? _documents
            : _documents.where((d) => d['categoryId'] == _selectedCategoryId).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(AppTexts.get('documents', lang), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Column(
            children: [
              _buildCategoriesRow(isDark, lang),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) => _buildDocumentCard(filteredDocs[index], isDark, lang),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesRow(bool isDark, String lang) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
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
              onSelected: (val) => setState(() => _selectedCategoryId = cat['id']!),
              selectedColor: Colors.blueAccent,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, bool isDark, String lang) {
    final bool isPremium = doc['is_premium'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPremium ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isPremium ? Colors.orange.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(_getFileIcon(doc['ext']), color: isPremium ? Colors.orange : Colors.blueAccent),
        ),
        title: Text(lang == 'ru' ? doc['title_ru'] : doc['title_kk'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lang == 'ru' ? doc['desc_ru'] : doc['desc_kk'], style: const TextStyle(fontSize: 12)),
        trailing: isPremium ? Text("${doc['price']} ₸", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)) : const Icon(LucideIcons.chevronRight),
        onTap: () => _showWizard(doc, isDark, lang),
      ),
    );
  }

  void _showWizard(Map<String, dynamic> doc, bool isDark, String lang) {
    final List<String> fields = List<String>.from(doc['fields']);
    final Map<String, TextEditingController> controllers = { for (var f in fields) f : TextEditingController() };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang == 'ru' ? 'Заполните данные' : 'Деректерді толтырыңыз', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[f],
                      decoration: InputDecoration(
                        labelText: f,
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: doc['is_premium'] ? Colors.orange : Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final data = controllers.map((k, v) => MapEntry(k, v.text));
                  Navigator.pop(context);
                  _generateAndOpenDocument(doc, data, lang);
                },
                child: Text(lang == 'ru' ? 'Создать PDF' : 'PDF жасау', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) => ext == 'PDF' ? LucideIcons.fileText : LucideIcons.file;
}