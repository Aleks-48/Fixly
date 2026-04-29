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
              "Лист голосования собственников квартир, нежилых помещений, проголосовавших на собрании (проводимый путем письменного порядка)",
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
}