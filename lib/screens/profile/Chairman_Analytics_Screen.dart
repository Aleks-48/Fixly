import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/services/pdf_report_service.dart';
import 'package:fixly_app/services/ai_service.dart'; // Новый импорт
import 'package:printing/printing.dart'; 

class ChairmanAnalyticsScreen extends StatefulWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  State<ChairmanAnalyticsScreen> createState() => _ChairmanAnalyticsScreenState();
}

class _ChairmanAnalyticsScreenState extends State<ChairmanAnalyticsScreen> {
  // 1. ПЕРЕМЕННЫЕ ДАННЫХ (Реальные цифры для ИИ)
  double _eosiBalance = 2450000;      // Накопительный счет (ЕОСИ)
  double _capitalBalance = 5800000;   // Капитальный ремонт (добавили по просьбе)
  
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _capitalController = TextEditingController();
  
  // Состояния загрузки
  bool _isGeneratingPdf = false;
  bool _isAiLoading = false;
  String _aiForecastText = ""; // Текст прогноза от ИИ

  @override
  void initState() {
    super.initState();
    // Запускаем первичный анализ при входе (можно добавить задержку или кнопку)
    _fetchAiAnalysis();
  }

  // ФУНКЦИЯ ЗАПРОСА К GEMINI AI
  Future<void> _fetchAiAnalysis() async {
    setState(() {
      _isAiLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      // Получаем последние завершенные задачи для анализа трат
      final List<Map<String, dynamic>> lastTasks = await supabase
          .from('tasks')
          .select()
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(5);

      final result = await AIService.getChairmanFinancialAnalysis(
        savingAccount: _eosiBalance,
        capitalRepairAccount: _capitalBalance,
        lang: appLanguage.value,
        recentExpenses: lastTasks,
      );

      setState(() {
        _aiForecastText = result;
      });
    } catch (e) {
      print("AI Analysis Error: $e");
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  // Функция для изменения баланса через диалог
  void _showEditBalanceDialog(String lang) {
    _balanceController.text = _eosiBalance.toInt().toString();
    _capitalController.text = _capitalBalance.toInt().toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang == 'ru' ? "Обновить счета" : "Шоттарды жаңарту"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: lang == 'ru' ? "Накопительный (ЕОСИ)" : "Жинақтаушы",
                suffixText: "₸",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _capitalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: lang == 'ru' ? "Капитальный ремонт" : "Күрделі жөндеу",
                suffixText: "₸",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang == 'ru' ? "Отмена" : "Бас тарту"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _eosiBalance = double.tryParse(_balanceController.text) ?? _eosiBalance;
                _capitalBalance = double.tryParse(_capitalController.text) ?? _capitalBalance;
              });
              Navigator.pop(context);
              _fetchAiAnalysis(); // Пересчитываем прогноз ИИ после смены баланса
            },
            child: Text(lang == 'ru' ? "Сохранить" : "Сақтау"),
          ),
        ],
      ),
    );
  }

  // ФУНКЦИЯ ГЕНЕРАЦИИ И ОТПРАВКИ ОТЧЕТА (Для будущего переноса в Голосование)
  Future<void> _handlePdfGeneration(String lang) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final supabase = Supabase.instance.client;
      final List<Map<String, dynamic>> votes = await supabase.from('votes').select();

      if (votes.isEmpty) {
        throw lang == 'ru' ? "Нет данных для отчета" : "Есеп үшін деректер жоқ";
      }

      List<Map<String, dynamic>> preparedVotes = [];
      for (var v in votes) {
        final bytes = await PdfReportService.downloadSignature(v['signature_url']);
        var vCopy = Map<String, dynamic>.from(v);
        vCopy['sig_bytes'] = bytes;
        preparedVotes.add(vCopy);
      }

      final pdfData = await PdfReportService.createPdfDocument(
        proposalTitle: lang == 'ru' ? "Протокол ОСИ: Результаты голосования" : "Мүлік иелерінің бірлестігінің хаттамасы",
        votes: preparedVotes,
      );

      await Printing.sharePdf(
        bytes: pdfData, 
        filename: 'report_osi_${DateTime.now().day}_${DateTime.now().month}.pdf'
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ru' ? "Отчет готов" : "Есеп дайын"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final supabase = Supabase.instance.client;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Аналитика и Прогнозы" : "Аналитика мен болжамдар"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.sparkles, color: Colors.blueAccent),
                onPressed: _fetchAiAnalysis,
              )
            ],
          ),
          body: Stack(
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('tasks').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data ?? [];
                  double totalSpent = 0;
                  int completedCount = 0;
                  int activeCount = 0;

                  for (var task in tasks) {
                    final status = task['status'];
                    if (status == 'completed') {
                      completedCount++;
                      totalSpent += double.tryParse(task['final_price']?.toString() ?? '0') ?? 0;
                    } else if (['new', 'in_progress', 'pending'].contains(status)) {
                      activeCount++;
                    }
                  }

                  double health = (completedCount + activeCount) > 0 
                      ? completedCount / (completedCount + activeCount) 
                      : 1.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. ФИНАНСОВЫЙ БЛОК (С двумя счетами)
                        _buildFinancialOverview(_eosiBalance, _capitalBalance, totalSpent, lang),
                        
                        const SizedBox(height: 30),
                        
                        // 2. ИИ-АНАЛИТИКА (Заменили старый статический блок)
                        _buildSectionHeader(lang == 'ru' ? "Умный прогноз и аудит (Gemini AI)" : "Ақылды болжам (Gemini AI)"),
                        _buildAIAdviceCard(_aiForecastText, _isAiLoading, lang, isDark),

                        const SizedBox(height: 30),

                        // 3. ПРОГНОЗ РЕМОНТОВ
                        _buildSectionHeader(lang == 'ru' ? "Приоритетные задачи" : "Басым тапсырмалар"),
                        _buildRepairPredictor(_eosiBalance, lang),

                        const SizedBox(height: 30),

                        // 4. ЗДОРОВЬЕ ДОМА
                        _buildSectionHeader(lang == 'ru' ? "Состояние жилого объекта" : "Тұрғын үй жағдайы"),
                        _buildHealthIndicator(health, activeCount, lang),
                        
                        const SizedBox(height: 30),

                        // 5. ДЕТАЛЬНЫЙ АНАЛИЗ ЦЕН
                        _buildSectionHeader(lang == 'ru' ? "Анализ цен по рынку (РК)" : "Нарықтық баға анализі"),
                        _buildMarketComparison(tasks, lang, isDark),

                        const SizedBox(height: 30),

                        // 6. ПОСЛЕДНИЕ РАБОТЫ
                        _buildRecentTasksList(tasks, lang),

                        const SizedBox(height: 30),

                        // 7. КНОПКА ОТЧЕТА (В будущем перенесешь ее в раздел голосования)
                        _buildReportButton(lang),
                        
                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              ),
              
              if (_isGeneratingPdf)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 25),
                        Text(
                          lang == 'ru' ? "Создание протокола..." : "Хаттама жасау...",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- ОБНОВЛЕННЫЕ ВИДЖЕТЫ ---

  Widget _buildFinancialOverview(double balance, double capital, double spent, String lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showEditBalanceDialog(lang),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniBalance(lang == 'ru' ? "НАКОПИТЕЛЬНЫЙ" : "ЖИНАҚТАУШЫ", balance, Colors.greenAccent),
                _miniBalance(lang == 'ru' ? "КАПИТАЛЬНЫЙ" : "КҮРДЕЛІ", capital, Colors.purpleAccent),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang == 'ru' ? "ОБЩИЙ РАСХОД" : "ЖАЛПЫ ШЫҒЫН", style: const TextStyle(color: Colors.white60, fontSize: 10)),
              Text("${spent.toInt()} ₸", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniBalance(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text("${val.toInt()} ₸", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ОБНОВЛЕННЫЙ КАРТОЧКА С ИИ-ТЕКСТОМ
  Widget _buildAIAdviceCard(String text, bool isLoading, String lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                lang == 'ru' ? "АНАЛИЗ ДАННЫХ" : "ДЕРЕКТЕРДІ ТАЛДАУ",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isLoading 
            ? const LinearProgressIndicator(backgroundColor: Colors.transparent)
            : Text(
                text.isEmpty 
                  ? (lang == 'ru' ? "Нажмите на иконку ✨ для получения прогноза" : "Болжам алу үшін ✨ белгішесін басыңыз")
                  : text,
                style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
              ),
        ],
      ),
    );
  }

  Widget _buildRepairPredictor(double balance, String lang) {
    List<Map<String, dynamic>> predictions = [];
    if (balance > 1000000) {
      predictions.add({'title': lang == 'ru' ? 'Обновление кровли' : 'Шатырды жаңарту', 'icon': LucideIcons.home, 'cost': '~950k'});
      predictions.add({'title': lang == 'ru' ? 'Ремонт подъезда' : 'Кіреберіс', 'icon': LucideIcons.paintBucket, 'cost': '~400k'});
    } else {
      predictions.add({'title': lang == 'ru' ? 'Замена освещения' : 'Жарық', 'icon': LucideIcons.lightbulb, 'cost': '~120k'});
    }

    return Column(
      children: predictions.map((p) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(p['icon'] as IconData, color: Colors.blue, size: 20),
          title: Text(p['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          trailing: Text(p['cost'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
      )).toList(),
    );
  }

  Widget _buildHealthIndicator(double health, int active, String lang) {
    Color color = health > 0.8 ? Colors.green : (health > 0.5 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(health * 100).toInt()}%", style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(lang == 'ru' ? "Активных задач" : "Белсенді", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("$active", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: health, 
            minHeight: 6, 
            borderRadius: BorderRadius.circular(10), 
            backgroundColor: color.withOpacity(0.1), 
            color: color
          ),
        ],
      ),
    );
  }

  Widget _buildMarketComparison(List<Map<String, dynamic>> tasks, String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildMarketBar(lang == 'ru' ? "Сантехника" : "Сантехника", 0.85, Colors.green, "-15%"),
          const SizedBox(height: 15),
          _buildMarketBar(lang == 'ru' ? "Электрика" : "Электрика", 1.15, Colors.red, "+15%"),
          const SizedBox(height: 15),
          _buildMarketBar(lang == 'ru' ? "Лифты" : "Лифттер", 0.95, Colors.blue, "-5%"),
        ],
      ),
    );
  }

  Widget _buildMarketBar(String label, double val, Color color, String diff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(diff, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: val / 1.5, color: color, backgroundColor: color.withOpacity(0.1), minHeight: 4),
      ],
    );
  }

  Widget _buildRecentTasksList(List<Map<String, dynamic>> tasks, String lang) {
    final lastTasks = tasks.where((t) => t['status'] == 'completed').toList().reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(lang == 'ru' ? "Последние оплаты" : "Соңғы төлемдер"),
        if (lastTasks.isEmpty) 
          const Text("Нет данных", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ...lastTasks.map((t) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 18),
          title: Text(t['category'] ?? "Ремонт", style: const TextStyle(fontSize: 13)),
          trailing: Text("${t['final_price']} ₸", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        )),
      ],
    );
  }

  Widget _buildReportButton(String lang) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingPdf ? null : () => _handlePdfGeneration(lang),
        icon: const Icon(LucideIcons.fileText, color: Colors.white),
        label: Text(
          lang == 'ru' ? "СКАЧАТЬ ПРОТОКОЛ ГОЛОСОВАНИЯ" : "ДАУЫС БЕРУ ХАТТАМАСЫН ЖҮКТЕУ", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  );
}