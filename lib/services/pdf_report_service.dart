import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class PdfReportService {
  /// ОСНОВНОЙ МЕТОД: Создает официальный PDF-лист голосования и возвращает байты
  static Future<Uint8List> createPdfDocument({
    required String proposalTitle,
    required List<Map<String, dynamic>> votes,
    String address = "укажите адрес", // Можно передавать адрес дома из UI
  }) async {
    final pdf = pw.Document();

    // Загружаем шрифты Google Fonts для поддержки кириллицы
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40), // Стандартные поля документа
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          // Официальный заголовок документа
          pw.Center(
            child: pw.Text(
              // Раньше здесь было "путем письменного порядка" — не
              // соответствует реальному юридическому шаблону, который
              // однозначно использует термин "явочного порядка".
              "Лист голосования собственников квартир, нежилых помещений, проголосовавших на собрании (проводимый путем явочного порядка)",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Мета-данные голосования
          pw.Text('Дата: "${DateTime.now().day}" ${DateTime.now().month} ${DateTime.now().year} года      Время: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Text("Местонахождение многоквартирного жилого дома: $address", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Text("Вопрос внесенный для обсуждения: $proposalTitle", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 15),

          // Официальная таблица
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),  // №
              1: const pw.FlexColumnWidth(3),    // ФИО
              2: const pw.FlexColumnWidth(1.5),  // ЗА
              3: const pw.FlexColumnWidth(1.5),  // ПРОТИВ
              4: const pw.FlexColumnWidth(1.5),  // ВОЗДЕРЖ.
            },
            children: [
              // Шапка таблицы
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildCell("№", isHeader: true),
                  _buildCell("Фамилия Имя Отчество\n(при его наличии)", isHeader: true),
                  _buildCell("\"За\"\n(подпись)", isHeader: true),
                  _buildCell("\"Против\"\n(подпись)", isHeader: true),
                  _buildCell("\"Воздержусь\"\n(подпись)", isHeader: true),
                ],
              ),
              // Строки таблицы (Данные пользователей)
              ...votes.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final vote = entry.value;
                
                // Подготавливаем виджет подписи, если она есть
                final sigWidget = vote['sig_bytes'] != null 
                    ? pw.Image(pw.MemoryImage(vote['sig_bytes'])) 
                    : null;

                // ФИО или ID (если ФИО нет в базе)
                final residentName = vote['full_name'] ?? 'Пользователь ${vote['user_id'].toString().substring(0, 5)}';

                return pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    _buildCell(index.toString()),
                    _buildCell(residentName, alignLeft: true), // Имя прижимаем влево
                    
                    // Логика: ставим подпись только в ту колонку, за которую проголосовали
                    _buildSigCell(vote['choice'] == 'yes' ? sigWidget : null),
                    _buildSigCell(vote['choice'] == 'no' ? sigWidget : null),
                    _buildSigCell(vote['choice'] == 'abstain' ? sigWidget : null),
                  ],
                );
              }).toList(),
            ],
          ),
          
          pw.SizedBox(height: 40),

          // Блок для подписей правления (Председатель, Секретарь, Члены совета)
          _buildSignatureLine("Председатель собрания:"),
          pw.SizedBox(height: 15),
          _buildSignatureLine("Секретарь собрания:"),
          pw.SizedBox(height: 15),
          _buildSignatureLine("Член совета дома:"),
          pw.SizedBox(height: 15),
          _buildSignatureLine("Член совета дома:"),
          pw.SizedBox(height: 15),
          _buildSignatureLine("Член совета дома:"),
          
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("Сформировано в системе Fixly", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    // Возвращаем итоговый файл в виде набора байтов
    return await pdf.save();
  }

  /// Вспомогательный метод для текстовых ячеек таблицы
  static pw.Widget _buildCell(String text, {bool isHeader = false, bool alignLeft = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
        ),
      ),
    );
  }

  /// Вспомогательный метод для ячеек с подписями
  static pw.Widget _buildSigCell(pw.Image? sigImage) {
    return pw.Container(
      height: 35,
      padding: const pw.EdgeInsets.all(2),
      alignment: pw.Alignment.center,
      child: sigImage ?? pw.SizedBox(), // Если подписи нет для этой колонки - пустота
    );
  }

  /// Вспомогательный метод для линий подписей внизу документа
  static pw.Widget _buildSignatureLine(String title) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(width: 150, child: pw.Text(title, style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Text("(Ф.И.О.)", style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Text("(подпись)", style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ],
    );
  }

  /// Метод для скачивания картинок подписей из Supabase Storage
  static Future<Uint8List?> downloadSignature(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print("Исключение при загрузке подписи: $e");
    }
    return null;
  }
  /// МЕТОД ДЛЯ ЗАПУСКА ПЕЧАТИ/СОХРАНЕНИЯ (Исправляет ошибку в Web)
  static Future<void> exportAndOpenPdf({
    required String proposalTitle,
    required List<Map<String, dynamic>> votes,
  }) async {
    // 1. Генерируем байты документа через твой существующий метод
    final pdfBytes = await createPdfDocument(
      proposalTitle: proposalTitle,
      votes: votes,
    );

    // 2. Используем библиотеку printing для отображения
    // Она сама понимает: в вебе — открыть печать, на мобилке — через натив
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Акт_голосования_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// МЕТОД ДЛЯ ГЕНЕРАЦИИ ФИНАНСОВОГО ОТЧЕТА (PDF)
  static Future<Uint8List> createFinancialReportPdf({
    required double eosiBalance,
    required double capitalBalance,
    required double totalSpent,
    required List<Map<String, dynamic>> expenses,
    String address = "Не указан",
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // Форматирование даты
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "ФИНАНСОВЫЙ ОТЧЕТ ОБЪЕДИНЕНИЯ СОБСТВЕННИКОВ ИМУЩЕСТВА (ОСИ)",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          
          pw.Text("Адрес: $address", style: const pw.TextStyle(fontSize: 10)),
          pw.Text("Дата формирования отчета: $dateStr", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 15),

          // Блок сводных балансов
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("СВОДНАЯ ИНФОРМАЦИЯ ПО СЧЕТАМ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Счет текущего содержания (ЕОСИ):"),
                    pw.Text("${eosiBalance.toStringAsFixed(2)} ₸", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Счет капитального ремонта:"),
                    pw.Text("${capitalBalance.toStringAsFixed(2)} ₸", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("ИТОГО ОСВОЕНО СРЕДСТВ:"),
                    pw.Text("${totalSpent.toStringAsFixed(2)} ₸", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]
                ),
              ],
            )
          ),
          
          pw.SizedBox(height: 20),
          pw.Text("ДЕТАЛИЗАЦИЯ РАСХОДОВ (Выполненные работы)", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          // Таблица расходов
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),   // №
              1: const pw.FlexColumnWidth(3),     // Наименование
              2: const pw.FlexColumnWidth(2),     // Дата
              3: const pw.FlexColumnWidth(2),     // Сумма
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildCell("№", isHeader: true),
                  _buildCell("Наименование работ / Заявка", isHeader: true, alignLeft: true),
                  _buildCell("Дата завершения", isHeader: true),
                  _buildCell("Сумма (₸)", isHeader: true),
                ],
              ),
              if (expenses.isEmpty)
                pw.TableRow(
                  children: [
                    _buildCell("-"),
                    _buildCell("Нет расходов за период", alignLeft: true),
                    _buildCell("-"),
                    _buildCell("-"),
                  ]
                )
              else
                ...expenses.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final exp = entry.value;
                  final title = exp['title'] ?? 'Ремонтные работы';
                  final date = exp['completed_at'] != null 
                    ? DateTime.tryParse(exp['completed_at'].toString()) 
                    : null;
                  final dateFormatted = date != null 
                    ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
                    : 'Н/Д';
                  final price = double.tryParse(exp['final_price']?.toString() ?? '0') ?? 0;

                  return pw.TableRow(
                    children: [
                      _buildCell(index.toString()),
                      _buildCell(title, alignLeft: true),
                      _buildCell(dateFormatted),
                      _buildCell(price.toStringAsFixed(2)),
                    ]
                  );
                }),
            ],
          ),

          pw.SizedBox(height: 40),
          _buildSignatureLine("Председатель ОСИ:"),
          
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("Сформировано в системе Fixly", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  /// Обёртка для вызова и скачивания фин отчета
  static Future<void> exportAndOpenFinancialPdf({
    required double eosiBalance,
    required double capitalBalance,
    required double totalSpent,
    required List<Map<String, dynamic>> expenses,
    String address = "Не указан",
  }) async {
    final pdfBytes = await createFinancialReportPdf(
      eosiBalance: eosiBalance,
      capitalBalance: capitalBalance,
      totalSpent: totalSpent,
      expenses: expenses,
      address: address,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Финансовый_отчет_ОСИ_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}