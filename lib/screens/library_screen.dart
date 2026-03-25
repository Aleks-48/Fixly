import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Список документов
  final List<Map<String, String>> _allDocuments = const [
    {
      'title': 'Основы гидравлического расчета систем водоснабжения и водоотведения',
      'subtitle': 'Миркина Е. Н., Горбачева М. П. | PDF',
      'url': 'https://wqxzraqzonyxnsrlysyt.supabase.co/storage/v1/object/public/library/Mirkina_Osnovy_gidravlicheskogo_rascheta_sistem_vodosnabzhenia_i_vodootvedenia.pdf'
    },
  ];

  List<Map<String, String>> _filteredDocs = [];

  @override
  void initState() {
    super.initState();
    _filteredDocs = _allDocuments;
  }

  void _runFilter(String keyword) {
    setState(() {
      _filteredDocs = _allDocuments
          .where((doc) => doc['title']!.toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Библиотека знаний"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: "Поиск по библиотеке...",
                prefixIcon: const Icon(LucideIcons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ),
          
          // Список файлов
          Expanded(
            child: _filteredDocs.isEmpty
                ? const Center(child: Text("Ничего не найдено"))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = _filteredDocs[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.fileText, color: Colors.blue),
                          ),
                          title: Text(doc['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(doc['subtitle']!),
                          trailing: const Icon(LucideIcons.externalLink, size: 18),
                          onTap: () => _launchURL(doc['url']!),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось открыть файл")),
        );
      }
    }
  }
}