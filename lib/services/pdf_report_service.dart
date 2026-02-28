import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfReportService {
  static Future<void> generateAndShareReport(List<Map<String, dynamic>> tasks, String reportTitle) async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd.MM.yyyy');

    // 1. Сначала подготовим данные отдельно, чтобы избежать ошибок типизации
    final List<List<String>> tableData = [
      ['Дата', 'Категория', 'Сумма (₸)'],
      ...tasks.where((t) => t['status'] == 'completed').map((task) {
        final date = DateTime.tryParse(task['created_at']?.toString() ?? '') ?? DateTime.now();
        final category = (task['category'] ?? 'Ремонт').toString();
        final price = (double.tryParse(task['final_price']?.toString() ?? '0') ?? 0).toStringAsFixed(0);
        return [formatter.format(date), category, price];
      }).toList(),
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(reportTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              // 2. Используем уже подготовленный список
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Отчет_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}