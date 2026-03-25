import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; // Для доступа к appLanguage

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

  // ФУНКЦИЯ СОХРАНЕНИЯ
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ваш голос принят!")));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
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