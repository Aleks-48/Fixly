import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; // Для доступа к appLanguage
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VotingPage extends StatefulWidget {
  final String proposalId; // ID вопроса, за который голосуем
  final String proposalTitle;

  const VotingPage({
    super.key, 
    this.proposalId = "123", 
    this.proposalTitle = "Капитальный ремонт крыши"
  });

  @override
  State<VotingPage> createState() => _VotingPageState();
}

class _VotingPageState extends State<VotingPage> {
  // Контроллер для рисования
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isUploading = false;
  String? _voteSelection; // 'yes' или 'no'

  // ФУНКЦИЯ СОХРАНЕНИЯ ГОЛОСА И ГЕНЕРАЦИИ PDF
  Future<void> _submitVote() async {
    if (_voteSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите вариант ответа")));
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Пожалуйста, поставьте подпись")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id ?? "anonymous";

      // 1. Конвертируем подпись в картинку (PNG)
      final Uint8List? signatureBytes = await _signatureController.toPngBytes();

      if (signatureBytes != null) {
        // 2. Загружаем в Storage
        final String fileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
        final String path = 'signatures/$userId/$fileName';

        await supabase.storage.from('documents').uploadBinary(
          path,
          signatureBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

        // 3. Получаем URL подписи
        final String signatureUrl = supabase.storage.from('documents').getPublicUrl(path);

        // 4. Сохраняем голос в таблицу 'votes'
        await supabase.from('votes').insert({
          'proposal_id': widget.proposalId,
          'user_id': userId,
          'choice': _voteSelection,
          'signature_url': signatureUrl,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 5. ГЕНЕРИРУЕМ И ОТКРЫВАЕМ PDF-КВИТАНЦИЮ
        await _generateAndSavePDF(signatureBytes, _voteSelection!, appLanguage.value);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Ваш голос принят! Квитанция сохранена."),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ЛОГИКА СОЗДАНИЯ PDF ФАЙЛА С КИРИЛЛИЦЕЙ И СОХРАНЕНИЯ НА УСТРОЙСТВО
  Future<void> _generateAndSavePDF(Uint8List signatureBytes, String choice, String lang) async {
    final pdf = pw.Document();
    
    // Загружаем шрифты из Google Fonts для поддержки кириллицы
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final String choiceText = choice == 'yes'
        ? (lang == 'ru' ? 'ЗА' : 'ИӘ')
        : (lang == 'ru' ? 'ПРОТИВ' : 'ҚАРСЫ');

    // Формируем страницу
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Квитанция электронного голосования", style: pw.TextStyle(font: fontBold, fontSize: 22)),
              pw.SizedBox(height: 10),
              pw.Text("Форма для предоставления в ОСИ / EOSI", style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              
              pw.Text("Повестка дня:", style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text(widget.proposalTitle, style: pw.TextStyle(font: font, fontSize: 14)),
              pw.SizedBox(height: 20),
              
              pw.Text("Дата и время голосования: ${DateTime.now().toString().split('.')[0]}", style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 20),

              // Создаем таблицу результатов (как в официальных бланках)
              pw.TableHelper.fromTextArray(
                context: context,
                cellStyle: pw.TextStyle(font: font, fontSize: 12),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                data: [
                  ['Статус пользователя', 'Решение', 'Подпись'],
                  ['Верифицирован\n(UID: ${Supabase.instance.client.auth.currentUser?.id?.substring(0,8) ?? "Anon"})', choiceText, ''],
                ],
              ),
              
              // Накладываем картинку подписи поверх пустой ячейки таблицы
              pw.SizedBox(height: -45), 
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Image(pw.MemoryImage(signatureBytes), width: 100, height: 50),
                  pw.SizedBox(width: 10),
                ]
              ),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Text("Документ сформирован автоматически в приложении Fixly.", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    // Находим правильную папку на устройстве
    Directory? directory;
    if (Platform.isAndroid) {
      // Для Android используем внешнее хранилище, чтобы файл можно было найти
      directory = await getExternalStorageDirectory();
    } else {
      // Для iOS используем папку документов
      directory = await getApplicationDocumentsDirectory();
    }
    
    // Если папка не найдена, используем временную
    final path = directory?.path ?? (await getTemporaryDirectory()).path;
    final file = File("$path/Vote_Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf");

    // Записываем данные в файл
    await file.writeAsBytes(await pdf.save());

    // Вызываем системное приложение для открытия PDF
    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(title: Text(lang == 'ru' ? "Голосование" : "Дауыс беру")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.proposalTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  lang == 'ru' ? "Ознакомьтесь с деталями и примите решение." : "Мән-жаймен танысып, шешім қабылдаңыз.",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // ВЫБОР ВАРИАНТА
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceCard("yes", lang == 'ru' ? "ЗА" : "ИӘ", Colors.green),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildChoiceCard("no", lang == 'ru' ? "ПРОТИВ" : "ҚАРСЫ", Colors.red),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                Text(lang == 'ru' ? "Ваша подпись:" : "Қолыңыз:"),
                const SizedBox(height: 10),

                // ПОЛЕ ДЛЯ ПОДПИСИ
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Signature(
                        controller: _signatureController,
                        height: 200,
                        backgroundColor: Colors.transparent,
                      ),
                      TextButton.icon(
                        onPressed: () => _signatureController.clear(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(lang == 'ru' ? "Очистить" : "Тазалау"),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // КНОПКА ОТПРАВКИ
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isUploading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(lang == 'ru' ? "ОТПРАВИТЬ ГОЛОС" : "ДАУЫС БЕРУ", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoiceCard(String value, String label, Color color) {
    bool isSelected = _voteSelection == value;
    return GestureDetector(
      onTap: () => setState(() => _voteSelection = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(value == 'yes' ? Icons.check_circle : Icons.cancel, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }
}