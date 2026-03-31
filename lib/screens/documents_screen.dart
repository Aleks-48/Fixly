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
      'desc_ru': 'Форма Р-1 согласно приложению 50.', 
      'desc_kk': '50-қосымшаға сәйкес Р-1 нысаны.',
      'is_premium': true, 
      'price': 1500, 
      'ext': 'PDF',
      'fields': ['Заказчик (ОСИ)', 'БИН Заказчика', 'Исполнитель (ИП)', 'ИИН/БИН Исполнителя', 'Описание работ', 'Сумма']
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
    
    // Подгрузка шрифтов для кириллицы
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoMedium();
    
    final String docId = doc['id'];
    final String title = lang == 'ru' ? doc['title_ru'] : doc['title_kk'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (pw.Context context) {
          
          // ==========================================
          // ШАБЛОН: АКТ ВЫПОЛНЕННЫХ РАБОТ (ФОРМА Р-1)
          // ==========================================
          if (docId == 'a1') {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Text(
                    "Приложение 50 к приказу Министра финансов\nРеспублики Казахстан от 20 декабря 2012 года № 562\n\nФорма Р-1",
                    style: pw.TextStyle(font: font, fontSize: 8), 
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: "Исполнитель: ", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.TextSpan(text: "${userInput['Исполнитель (ИП)']} (ИИН/БИН: ${userInput['ИИН/БИН Исполнителя']})", style: pw.TextStyle(font: font, fontSize: 10, decoration: pw.TextDecoration.underline)),
                ])),
                pw.SizedBox(height: 8),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: "Заказчик: ", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.TextSpan(text: "${userInput['Заказчик (ОСИ)']} (БИН: ${userInput['БИН Заказчика']})", style: pw.TextStyle(font: font, fontSize: 10, decoration: pw.TextDecoration.underline)),
                ])),
                pw.SizedBox(height: 25),
                pw.Center(
                  child: pw.Text(
                    "АКТ ВЫПОЛНЕННЫХ РАБОТ (ОКАЗАННЫХ УСЛУГ) № ____\nот «___» ____________ 202__ г.", 
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                    textAlign: pw.TextAlign.center
                  )
                ),
                pw.SizedBox(height: 15),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.center,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(6),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(2),
                    5: const pw.FlexColumnWidth(2),
                  },
                  headers: ['№', 'Наименование работ (услуг)', 'Ед.\nизм.', 'Кол-во', 'Цена\n(тенге)', 'Стоимость\n(тенге)'],
                  data: [
                    ['1', userInput['Описание работ'] ?? '', 'усл.', '1', userInput['Сумма'] ?? '', userInput['Сумма'] ?? ''],
                    ['', 'ИТОГО', '', '', '', userInput['Сумма'] ?? ''],
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Text("Сведения об использовании запасов, полученных от заказчика: отсутствуют", style: pw.TextStyle(font: font, fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text("Приложение: Перечень документации на 0 листах", style: pw.TextStyle(font: font, fontSize: 9)),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Сдал (Исполнитель)", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.SizedBox(height: 25),
                          pw.Text("____________________", style: pw.TextStyle(font: font)),
                          pw.Text("(подпись)", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                        ]
                      )
                    ),
                    pw.SizedBox(width: 40),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Принял (Заказчик)", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.SizedBox(height: 25),
                          pw.Text("____________________", style: pw.TextStyle(font: font)),
                          pw.Text("(подпись)", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                        ]
                      )
                    ),
                  ],
                ),
              ],
            );
          } 
          
          // ==========================================
          // ШАБЛОН: ПРОТОКОЛ СОБРАНИЯ (ОБНОВЛЕННЫЙ)
          // ==========================================
          else if (docId == 'p1') {
            
            // Обработка пользовательских вопросов
            String rawAgenda = userInput['Вопросы (через запятую)'] ?? '';
            List<String> agendaItems = rawAgenda.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            
            // Если председатель ничего не ввел, даем дефолтные вопросы из твоего документа
            if (agendaItems.isEmpty) {
              agendaItems = [
                "Отказ от управляющей компании КСП в связи с ненадлежащим исполнением обязанностей.",
                "Выбор формы управления: объединение собственников имущества (ОСИ).",
                "Выбор из числа собственников квартир председателя ОСИ.",
                "Избрание из числа собственников квартир Совета дома.",
                "Утверждение типового Устава ОСИ."
              ];
            }

            // Функция для создания аккуратной строки подписи
            pw.Widget buildSignatureRow(String role) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(width: 140, child: pw.Text(role, style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Text("____________________", style: pw.TextStyle(font: font)),
                        pw.SizedBox(width: 20),
                        pw.Text("_________________", style: pw.TextStyle(font: font)),
                      ]
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 160),
                        pw.Text("(Ф.И.О)", style: pw.TextStyle(font: font, fontSize: 8)),
                        pw.SizedBox(width: 80),
                        pw.Text("(Подпись)", style: pw.TextStyle(font: font, fontSize: 8)),
                      ]
                    )
                  ]
                )
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("Протокол № ${userInput['Номер протокола']}", style: pw.TextStyle(font: fontBold, fontSize: 12))),
                pw.Center(
                  child: pw.Text(
                    "Собрания собственников квартир, жилых помещений многоквартирного жилого дома\n(проводимый путем письменного опроса)", 
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                    textAlign: pw.TextAlign.center
                  )
                ),
                pw.SizedBox(height: 15),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Время: ${userInput['Время']}", style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text("«${userInput['Дата']}»", style: pw.TextStyle(font: font, fontSize: 10)),
                ]),
                pw.SizedBox(height: 15),
                pw.Text("1) Местонахождение многоквартирного жилого дома: ${userInput['Адрес дома']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 5),
                pw.Text("2) Общие количество собственников квартир: ${userInput['Кол-во квартир']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 5),
                pw.Text("3) Общие количество собственников нежилого помещения: ${userInput['Кол-во нежилых']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 5),
                pw.Text("4) Количество принимавших участие в письменном опросе: ${userInput['Кол-во участников']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 5),
                pw.Text("5) Форма собрания: путем письменного опроса", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 15),
                pw.Text("Повестка дня собрания:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.SizedBox(height: 5),
                
                // Динамический вывод вопросов повестки
                ...agendaItems.asMap().entries.map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text("${e.key + 1}. ${e.value}", style: pw.TextStyle(font: font, fontSize: 10)),
                )),
                
                pw.Spacer(),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
                
                // Вывод блока подписей
                buildSignatureRow("Председатель собрания:"),
                buildSignatureRow("Секретарь собрания:"),
                buildSignatureRow("Член совета дома:"),
                buildSignatureRow("Член совета дома:"),
                buildSignatureRow("Исполнительный орган:"),
              ],
            );
          }

          // ==========================================
          // ШАБЛОН: ЛИСТ ГОЛОСОВАНИЯ
          // ==========================================
          else if (docId == 'l1') {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("ЛИСТ ГОЛОСОВАНИЯ", style: pw.TextStyle(font: fontBold, fontSize: 14))),
                pw.Center(child: pw.Text("собственников квартир, нежилых помещений", style: pw.TextStyle(font: font, fontSize: 11))),
                pw.SizedBox(height: 15),
                pw.Text("Адрес: ${userInput['Адрес дома']}", style: pw.TextStyle(font: fontBold)),
                pw.SizedBox(height: 5),
                pw.Text("Вопрос, поставленный на голосование: ${userInput['Вопрос для голосования']}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 15),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.center,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                    5: const pw.FlexColumnWidth(2),
                  },
                  headers: ['№', 'ФИО собственника', '№ кв.', 'ЗА\n(подпись)', 'ПРОТИВ\n(подпись)', 'ВОЗД.\n(подпись)'],
                  data: List.generate(20, (i) => ['${i + 1}', '', '', '', '', '']),
                ),
              ],
            );
          }

          // ==========================================
          // ШАБЛОН: УВЕДОМЛЕНИЕ ДОЛЖНИКУ
          // ==========================================
          else {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Text("Собственнику квартиры № ${userInput['Номер квартиры']}\n${userInput['ФИО Должника']}", style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ),
                pw.SizedBox(height: 40),
                pw.Center(child: pw.Text("ДОСУДЕБНАЯ ПРЕТЕНЗИЯ\n(УВЕДОМЛЕНИЕ О ЗАДОЛЖЕННОСТИ)", style: pw.TextStyle(font: fontBold, fontSize: 14), textAlign: pw.TextAlign.center)),
                pw.SizedBox(height: 30),
                pw.Text("Уважаемый(ая) ${userInput['ФИО Должника']}!", style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Text("Уведомляем Вас о том, что по состоянию на текущую дату за вашей квартирой № ${userInput['Номер квартиры']} числится задолженность по расходам на содержание общего имущества объекта кондоминиума (ОСИ).", style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: "Сумма задолженности составляет: ", style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.TextSpan(text: "${userInput['Сумма долга']} тенге.", style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ])),
                pw.SizedBox(height: 10),
                pw.Text("Просим Вас в срок до ${userInput['Срок оплаты']} добровольно погасить указанную задолженность. В случае неоплаты в указанный срок, мы будем вынуждены обратиться к нотариусу для совершения исполнительной надписи или в суд для принудительного взыскания суммы долга, а также судебных издержек.", style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 50),
                pw.Text("С уважением,\nПредседатель ОСИ ____________________", style: pw.TextStyle(font: fontBold, fontSize: 12)),
              ],
            );
          }
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fixly_document_${DateTime.now().millisecondsSinceEpoch}.pdf");
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
            title: Text(AppTexts.get('documents', lang), 
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
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
            
            // Если полей много, лучше сделать их скроллируемыми внутри BottomSheet
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
                        hintText: f.contains('через запятую') ? 'Напр: Выбор ОСИ, Утверждение устава' : null,
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