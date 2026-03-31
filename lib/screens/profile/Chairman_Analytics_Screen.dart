import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/services/pdf_report_service.dart';
import 'package:fixly_app/services/ai_service.dart'; 
import 'package:printing/printing.dart'; 

class ChairmanAnalyticsScreen extends StatefulWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  State<ChairmanAnalyticsScreen> createState() => _ChairmanAnalyticsScreenState();
}

class _ChairmanAnalyticsScreenState extends State<ChairmanAnalyticsScreen> {
  // --- 1. ФИНАНСОВЫЕ ПОКАЗАТЕЛИ (РЕАЛЬНОСТЬ РК 2025) ---
  double _eosiBalance = 2450000;      // Текущий счет (ЕОСИ)
  double _capitalBalance = 5800000;   // Кап. ремонт
  
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _capitalController = TextEditingController();
  final TextEditingController _manualStatController = TextEditingController();

  bool _isGeneratingPdf = false;
  bool _isAiLoading = false;
  String _aiForecastText = ""; 
  List<Map<String, dynamic>> _aiPriorityTasks = []; 
  
  // --- 2. ДАННЫЕ РЫНКА (ФАКТОР НДС 16%) ---
  // Фиксированные данные по Казахстану для стабильного анализа
  final Map<String, Map<String, dynamic>> _marketStats = {
    'utilities': {
      'trend': 0.18, 
      'label': 'Тарифы ЖКХ (РК)', 
      'info': 'Рост из-за программы "Тариф в обмен на инвестиции"',
      'color': Colors.redAccent
    },
    'materials': {
      'trend': 0.16, 
      'label': 'Стройматериалы', 
      'info': 'Учет планируемого НДС 16% в 2025 году',
      'color': Colors.orangeAccent
    },
    'services': {
      'trend': 0.14, 
      'label': 'Сервисные услуги', 
      'info': 'Подорожание из-за роста МРП и налогов',
      'color': Colors.blueAccent
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchAiAnalysis();
  }

  // --- 3. ЛОГИКА ИИ АНАЛИЗА (ГЛУБОКИЙ АУДИТ) ---
  Future<void> _fetchAiAnalysis() async {
    setState(() {
      _isAiLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Получаем историю последних трат для контекста
      final List<Map<String, dynamic>> lastTasks = await supabase
          .from('tasks')
          .select()
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(15);

      // Формируем жесткий рыночный контекст для Gemini
      String marketContext = """
      ВНИМАНИЕ: Экономика Казахстана 2025. 
      - Налоговая реформа: Ожидаемое повышение НДС до 16%.
      - Стройматериалы в РК: Рост цен на 16-20% из-за импортозамещения и логистики.
      - Коммунальные услуги: Плановое повышение тарифов на 15-25%.
      - Цель анализа: Помочь председателю ОСИ обосновать жильцам необходимость увеличения сборов или срочных закупок материалов до подорожания.
      Дополнительно от пользователя: ${_manualStatController.text}
      """;

      final result = await AIService.getChairmanFinancialAnalysis(
        savingAccount: _eosiBalance,
        capitalRepairAccount: _capitalBalance,
        lang: appLanguage.value,
        recentExpenses: lastTasks,
        marketContext: marketContext, 
      );

      setState(() {
        _aiForecastText = result;
        _updateAiPriorityTasks(lastTasks);
      });
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  void _updateAiPriorityTasks(List<Map<String, dynamic>> tasks) {
    // Формируем список критических действий на основе анализа рынка
    setState(() {
      _aiPriorityTasks = [
        {
          'title': appLanguage.value == 'ru' ? 'Срочный закуп (до роста НДС)' : 'Материалдарды жедел сатып алу',
          'importance': 'Critical',
          'cost': '600 000 ₸',
          'icon': LucideIcons.alertTriangle
        },
        {
          'title': appLanguage.value == 'ru' ? 'Ревизия системы отопления' : 'Жылу жүйесін тексеру',
          'importance': 'High',
          'cost': '180 000 ₸',
          'icon': LucideIcons.thermometer
        },
      ];
    });
  }

  // --- 4. ДИАЛОГИ ВВОДА ДАННЫХ ---

  void _showManualStatDialog(String lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(lang == 'ru' ? "Факторы рынка РК" : "РК нарықтық факторлары"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang == 'ru' 
                ? "Введите изменения (например: рост цен на лифтовое оборудование +20%)" 
                : "Өзгерістерді енгізіңіз (мыс: лифт жабдықтары +20%)",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualStatController,
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: lang == 'ru' ? "НДС 16%, инфляция..." : "ҚҚС 16%...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang == 'ru' ? "Закрыть" : "Жабу")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchAiAnalysis(); 
            }, 
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(lang == 'ru' ? "Обновить анализ" : "Талдауды жаңарту")
          ),
        ],
      ),
    );
  }

  void _showEditBalanceDialog(String lang) {
    _balanceController.text = _eosiBalance.toInt().toString();
    _capitalController.text = _capitalBalance.toInt().toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(lang == 'ru' ? "Корректировка счетов" : "Шоттарды түзету"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(_balanceController, lang == 'ru' ? "Счет ЕОСИ" : "ЕОСИ шоты"),
            const SizedBox(height: 15),
            _buildDialogField(_capitalController, lang == 'ru' ? "Фонд кап. ремонта" : "Күрделі жөндеу қоры"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang == 'ru' ? "Отмена" : "Бас тарту")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _eosiBalance = double.tryParse(_balanceController.text) ?? _eosiBalance;
                _capitalBalance = double.tryParse(_capitalController.text) ?? _capitalBalance;
              });
              Navigator.pop(context);
              _fetchAiAnalysis();
            },
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(lang == 'ru' ? "Сохранить" : "Сақтау"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: "₸",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // --- 5. ГЕНЕРАЦИЯ PDF-ОТЧЕТА ---
  Future<void> _handlePdfGeneration(String lang) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final supabase = Supabase.instance.client;
      final List<Map<String, dynamic>> votes = await supabase.from('votes').select();
      
      List<Map<String, dynamic>> preparedVotes = [];
      for (var v in votes) {
        final bytes = await PdfReportService.downloadSignature(v['signature_url']);
        var vCopy = Map<String, dynamic>.from(v);
        vCopy['sig_bytes'] = bytes;
        preparedVotes.add(vCopy);
      }

      final pdfData = await PdfReportService.createPdfDocument(
        proposalTitle: lang == 'ru' ? "Аналитический отчет ОСИ (РК 2025)" : "ОСИ талдау есебі",
        votes: preparedVotes,
      );

      await Printing.sharePdf(bytes: pdfData, filename: 'osi_finance_report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            elevation: 0,
            title: Text(lang == 'ru' ? "Аналитика: Рынок РК" : "Аналитика: РК нарығы"),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.barChart4, size: 20),
                onPressed: () => _showManualStatDialog(lang),
              ),
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
                    if (task['status'] == 'completed') {
                      completedCount++;
                      totalSpent += double.tryParse(task['final_price']?.toString() ?? '0') ?? 0;
                    } else {
                      activeCount++;
                    }
                  }

                  double health = (completedCount + activeCount) > 0 
                      ? completedCount / (completedCount + activeCount) : 1.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ФИНАНСЫ
                        _buildFinancialOverview(_eosiBalance, _capitalBalance, totalSpent, lang),
                        
                        const SizedBox(height: 25),
                        
                        // AI АНАЛИТИКА НДС 16%
                        _buildSectionHeader(lang == 'ru' ? "AI Прогноз: Налоги и Инфляция" : "AI болжамы: Салықтар"),
                        _buildAIAdviceCard(_aiForecastText, _isAiLoading, lang, isDark),

                        const SizedBox(height: 25),

                        // ПРИОРИТЕТНЫЕ ЗАДАЧИ
                        _buildSectionHeader(lang == 'ru' ? "Критические задачи" : "Маңызды міндеттер"),
                        _buildAiTasksList(_aiPriorityTasks, lang),

                        const SizedBox(height: 25),

                        // ДИНАМИКА ЦЕН (ИСПРАВЛЕННЫЙ ЦВЕТ)
                        _buildSectionHeader(lang == 'ru' ? "Цены в РК (с учетом НДС 16%)" : "РК бағалары (ҚҚС 16%)"),
                        _buildMarketComparison(lang, isDark),

                        const SizedBox(height: 25),

                        // ЗДОРОВЬЕ
                        _buildSectionHeader(lang == 'ru' ? "Технический статус" : "Техникалық күй"),
                        _buildHealthIndicator(health, activeCount, lang),
                        
                        const SizedBox(height: 25),

                        // ПОСЛЕДНИЕ ТРАТЫ
                        _buildRecentTasksList(tasks, lang),

                        const SizedBox(height: 30),

                        // КНОПКА
                        _buildReportButton(lang),
                        
                        const SizedBox(height: 60),
                      ],
                    ),
                  );
                },
              ),
              
              if (_isGeneratingPdf)
                _buildOverlayLoader(lang == 'ru' ? "Формирование отчета..." : "Есеп жасалуда..."),
            ],
          ),
        );
      },
    );
  }

  // --- 6. ВИДЖЕТЫ (UI COMPONENTS) ---

  Widget _buildFinancialOverview(double bal, double cap, double spent, String lang) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showEditBalanceDialog(lang),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniBalance(lang == 'ru' ? "ОСИ СЧЕТ" : "ОСИ ШОТЫ", bal, Colors.cyanAccent),
                _miniBalance(lang == 'ru' ? "КАП. РЕМОНТ" : "КҮРДЕЛІ ЖӨНДЕУ", cap, Colors.orangeAccent),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang == 'ru' ? "ОСВОЕНО (МЕСЯЦ)" : "ИГЕРІЛДІ (АЙ)", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text("${spent.toInt()} ₸", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniBalance(String label, double val, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text("${val.toInt()} ₸", style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAIAdviceCard(String text, bool loading, String lang, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(isDark ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 10),
              Text(lang == 'ru' ? "AI-АНАЛИТИКА РК" : "AI-ТАЛДАУ", 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
          if (!loading) Text(
            text.isEmpty ? (lang == 'ru' ? "Запустите ИИ для анализа рисков НДС 16%" : "16% ҚҚС тәуекелдерін талдау үшін ИИ іске қосыңыз") : text,
            style: TextStyle(fontSize: 13, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTasksList(List<Map<String, dynamic>> tasks, String lang) {
    if (tasks.isEmpty) return const SizedBox();
    return Column(
      children: tasks.map((t) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.blue.withOpacity(0.1)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: (t['importance'] == 'Critical' ? Colors.red : Colors.blue).withOpacity(0.1),
            child: Icon(t['icon'] as IconData, size: 18, color: t['importance'] == 'Critical' ? Colors.red : Colors.blue),
          ),
          title: Text(t['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text(t['importance'], style: TextStyle(fontSize: 11, color: t['importance'] == 'Critical' ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
          trailing: Text(t['cost'], style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
        ),
      )).toList(),
    );
  }

  Widget _buildMarketComparison(String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: _marketStats.entries.map((e) {
          final trend = e.value['trend'] as double;
          final color = e.value['color'] as Color; // Исправленная типизация
          final label = e.value['label'] as String;
          final info = e.value['info'] as String;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildMarketBar(
              label, 
              (1.0 + trend), 
              color,
              "+${(trend * 100).toInt()}%",
              info
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarketBar(String label, double val, Color col, String diff, String info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(diff, style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        Text(info, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: val / 1.5, 
            color: col, 
            backgroundColor: col.withOpacity(0.1), 
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthIndicator(double health, int active, String lang) {
    Color col = health > 0.8 ? Colors.green : (health > 0.5 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: col.withOpacity(0.2)),
        color: col.withOpacity(0.02),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(health * 100).toInt()}%", style: TextStyle(color: col, fontSize: 38, fontWeight: FontWeight.w900)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(lang == 'ru' ? "АКТИВНЫЕ ЗАЯВКИ" : "БЕЛСЕНДІ ӨТІНІШТЕР", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900)),
                  Text("$active", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(value: health, color: col, backgroundColor: col.withOpacity(0.1), minHeight: 10),
        ],
      ),
    );
  }

  Widget _buildRecentTasksList(List<Map<String, dynamic>> tasks, String lang) {
    final last = tasks.where((t) => t['status'] == 'completed').toList().reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(lang == 'ru' ? "Последние оплаты" : "Соңғы төлемдер"),
        if (last.isEmpty) const Text("...", style: TextStyle(color: Colors.grey)),
        ...last.map((t) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.receipt, color: Colors.green, size: 22),
          title: Text(t['category'] ?? "Услуга", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          trailing: Text("${t['final_price']} ₸", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        )),
      ],
    );
  }

  Widget _buildReportButton(String lang) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton.icon(
        onPressed: _isGeneratingPdf ? null : () => _handlePdfGeneration(lang),
        icon: const Icon(LucideIcons.fileDown, color: Colors.white),
        label: Text(lang == 'ru' ? "СКАЧАТЬ АНАЛИТИКУ PDF" : "PDF ТАЛДАУДЫ ЖҮКТЕУ", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16, left: 4),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
  );

  Widget _buildOverlayLoader(String text) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 6),
            const SizedBox(height: 30),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}