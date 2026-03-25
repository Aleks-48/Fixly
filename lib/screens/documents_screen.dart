import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; // Импорт для доступа к appLanguage
import 'package:fixly_app/utils/app_texts.dart'; // Импорт твоего файла переводов

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  // Данные теперь с ключами для перевода
  final List<Map<String, dynamic>> _documents = [
    {
      'id': '1',
      'title_ru': 'Протокол общего собрания',
      'title_kk': 'Жалпы жиналыс хаттамасы',
      'desc_ru': 'Стандартный шаблон для проведения собраний жильцов.',
      'desc_kk': 'Тұрғындар жиналысын өткізуге арналған стандартты үлгі.',
      'is_premium': false,
      'price': 0,
      'ext': 'DOCX',
    },
    {
      'id': '2',
      'title_ru': 'Договор с подрядчиком',
      'title_kk': 'Мердігермен шарт',
      'desc_ru': 'Типовой договор на оказание ремонтных услуг.',
      'desc_kk': 'Жөндеу қызметтерін көрсетуге арналған типтік шарт.',
      'is_premium': false,
      'price': 0,
      'ext': 'PDF',
    },
    {
      'id': '3',
      'title_ru': 'Смета на капитальный ремонт',
      'title_kk': 'Күрделі жөндеуге арналған смета',
      'desc_ru': 'Детализированная таблица с формулами для расчета.',
      'desc_kk': 'Есептеуге арналған формулалары бар егжей-тегжейлі кесте.',
      'is_premium': true,
      'price': 1500,
      'ext': 'XLSX',
    },
    {
      'id': '4',
      'title_ru': 'Акт выполненных работ',
      'title_kk': 'Орындалған жұмыстар актісі',
      'desc_ru': 'Юридически выверенный акт приема-передачи.',
      'desc_kk': 'Заңды түрде тексерілген қабылдау-тапсыру актісі.',
      'is_premium': true,
      'price': 990,
      'ext': 'DOCX',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(
              AppTexts.get('documents', lang), // Перевод заголовка
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1),
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final doc = _documents[index];
              return _buildDocumentCard(doc, isDark, lang);
            },
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, bool isDark, String lang) {
    final bool isPremium = doc['is_premium'];
    // Выбираем текст в зависимости от языка
    final String title = lang == 'ru' ? doc['title_ru'] : doc['title_kk'];
    final String desc = lang == 'ru' ? doc['desc_ru'] : doc['desc_kk'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (isPremium) {
              _showTestPaymentDialog(doc, lang);
            } else {
              _downloadDocument(title, lang);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPremium 
                        ? (isDark ? Colors.amber.withOpacity(0.1) : Colors.orange.shade50) 
                        : (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getFileIcon(doc['ext']),
                    color: isPremium ? Colors.orange : Colors.blueAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFF57C00)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.lock, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${doc['price']} ₸',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.download, color: Colors.blueAccent, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTestPaymentDialog(Map<String, dynamic> doc, String lang) {
    final String title = lang == 'ru' ? doc['title_ru'] : doc['title_kk'];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.fileLock2, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                lang == 'ru' ? 'Купить шаблон\n"$title"' : 'Үлгіні сатып алу\n"$title"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'ru' 
                  ? 'Это тестовый режим оплаты. Документ будет доступен для скачивания после оплаты.'
                  : 'Бұл тесттік төлем режимі. Құжат төлем жасалғаннан кейін жүктеп алуға қолжетімді болады.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(lang == 'ru' ? '✅ Оплата прошла успешно!' : '✅ Төлем сәтті өтті!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(
                    lang == 'ru' ? 'Оплатить ${doc['price']} ₸' : 'Төлеу ${doc['price']} ₸',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _downloadDocument(String title, String lang) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang == 'ru' ? '⬇️ Загрузка: $title' : '⬇️ Жүктелуде: $title'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'PDF': return LucideIcons.fileText;
      case 'DOCX': return LucideIcons.fileEdit;
      case 'XLSX': return LucideIcons.sheet;
      default: return LucideIcons.file;
    }
  }
}