import 'dart:io';
import 'dart:typed_data';
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

class VotingPage extends StatefulWidget {
  final String proposalId; 
  final String proposalTitle;

  const VotingPage({
    super.key, 
    required this.proposalId, 
    required this.proposalTitle
  });

  @override
  State<VotingPage> createState() => _VotingPageState();
}

class _VotingPageState extends State<VotingPage> {
  // Контроллер подписи
  late SignatureController _signatureController;

  bool _isUploading = false;
  bool _isChairman = false; 
  String? _voteSelection;
  late String _currentTitle;
  bool _isLoadingRole = true;

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
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // ПРОВЕРКА РОЛИ
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        
        if (mounted) {
          setState(() {
            _isChairman = data != null && data['role'] == 'chairman';
            _isLoadingRole = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  // ИСПРАВЛЕННОЕ РЕДАКТИРОВАНИЕ ТЕМЫ
  Future<void> _editTitle() async {
    TextEditingController editController = TextEditingController(text: _currentTitle);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        title: Text(
          appLanguage.value == 'ru' ? "Изменить тему" : "Тақырыпты өзгерту",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "Введите новую тему",
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26) // ОШИБКА БЫЛА ТУТ, ИСПРАВЛЕНО
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Отмена", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty) {
                try {
                  await Supabase.instance.client
                      .from('proposals')
                      .update({'title': newTitle})
                      .eq('id', widget.proposalId);
                  setState(() => _currentTitle = newTitle);
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint("Update error: $e");
                }
              }
            },
            child: const Text("Сохранить", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ГЕНЕРАЦИЯ ОТЧЕТА (PDF)
  Future<void> _downloadFullReport() async {
    setState(() => _isUploading = true);
    try {
      final List<dynamic> allVotes = await Supabase.instance.client
          .from('votes')
          .select('choice, created_at, profiles(full_name, apartment_number)')
          .eq('proposal_id', widget.proposalId);

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) => [
            pw.Header(level: 0, child: pw.Text("Protocol: $_currentTitle", style: pw.TextStyle(font: fontBold, fontSize: 18))),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              data: [
                ['ФИО', 'Кв.', 'Решение', 'Дата'],
                ...allVotes.map((v) => [
                  v['profiles']['full_name'] ?? '---',
                  v['profiles']['apartment_number'] ?? '-',
                  v['choice'] == 'yes' ? 'ЗА' : 'ПРОТИВ',
                  DateFormat('dd.MM.yyyy').format(DateTime.parse(v['created_at']))
                ]),
              ],
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Report_${widget.proposalId}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка отчета: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ОТПРАВКА ГОЛОСА
  Future<void> _submitVote() async {
    if (_voteSelection == null || _signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appLanguage.value == 'ru' ? "Выберите вариант и поставьте подпись" : "Нұсқаны таңдап, қол қойыңыз"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      final existing = await supabase.from('votes').select().eq('proposal_id', widget.proposalId).eq('user_id', userId!).maybeSingle();
      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Вы уже проголосовали"), backgroundColor: Colors.redAccent));
        setState(() => _isUploading = false);
        return;
      }

      final Uint8List? signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        final path = 'signatures/$userId/${DateTime.now().millisecondsSinceEpoch}.png';
        await supabase.storage.from('documents').uploadBinary(path, signatureBytes);
        final sigUrl = supabase.storage.from('documents').getPublicUrl(path);

        await supabase.from('votes').insert({
          'proposal_id': widget.proposalId,
          'user_id': userId,
          'choice': _voteSelection,
          'signature_url': sigUrl,
        });

        await _generateReceiptPDF(signatureBytes, _voteSelection!);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _generateReceiptPDF(Uint8List sig, String choice) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(children: [
        pw.Text("Receipt: $_currentTitle", style: pw.TextStyle(font: font, fontSize: 18)),
        pw.SizedBox(height: 20),
        pw.Text("Vote: ${choice == 'yes' ? 'YES' : 'NO'}", style: pw.TextStyle(font: font)),
        pw.SizedBox(height: 20),
        pw.Image(pw.MemoryImage(sig), width: 150),
      ]);
    }));
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(lang == 'ru' ? "Голосование" : "Дауыс беру", 
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            actions: [
              if (_isChairman) 
                IconButton(
                  icon: const Icon(LucideIcons.fileText, color: Colors.blueAccent),
                  onPressed: _isUploading ? null : _downloadFullReport,
                )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // КАРТОЧКА ТЕМЫ
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
                        blurRadius: 15
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_currentTitle, 
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3, color: textColor)),
                          ),
                          if (_isChairman)
                            IconButton(
                              icon: const Icon(LucideIcons.edit3, color: Colors.orange, size: 22),
                              onPressed: _editTitle,
                            )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(lang == 'ru' ? "Выберите ваш вариант решения" : "Шешім нұсқасын таңдаңыз",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // КНОПКИ ВЫБОРА
                Row(
                  children: [
                    Expanded(child: _buildChoiceCard("yes", lang == 'ru' ? "ЗА" : "ИӘ", Colors.green, isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildChoiceCard("no", lang == 'ru' ? "ПРОТИВ" : "ҚАРСЫ", Colors.red, isDark)),
                  ],
                ),

                const SizedBox(height: 40),
                Text(lang == 'ru' ? "ВАША ПОДПИСЬ:" : "ҚОЛТАҢБАҢЫЗ:", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.blueGrey, fontSize: 13)),
                const SizedBox(height: 16),

                // ЗОНА ПОДПИСИ (Фон всегда белый для PDF)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.blueAccent.withOpacity(0.5) : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Signature(
                        controller: _signatureController,
                        height: 180,
                        backgroundColor: Colors.transparent,
                      ),
                      const Divider(height: 1, color: Colors.black12),
                      TextButton.icon(
                        onPressed: () => _signatureController.clear(),
                        icon: const Icon(Icons.refresh, size: 20, color: Colors.redAccent),
                        label: Text(lang == 'ru' ? "Очистить" : "Тазалау", style: const TextStyle(color: Colors.redAccent)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // КНОПКА ОТПРАВКИ
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isUploading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(lang == 'ru' ? "ОТПРАВИТЬ ГОЛОС" : "ДАУЫСТЫ ЖІБЕРУ", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoiceCard(String value, String label, Color color, bool isDark) {
    bool isSelected = _voteSelection == value;
    return GestureDetector(
      onTap: () => setState(() => _voteSelection = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1F2937) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade300), width: 2),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Column(
          children: [
            Icon(value == 'yes' ? LucideIcons.checkCircle : LucideIcons.xCircle, 
              color: isSelected ? Colors.white : color, size: 30),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
              fontSize: 16
            )),
          ],
        ),
      ),
    );
  }
}