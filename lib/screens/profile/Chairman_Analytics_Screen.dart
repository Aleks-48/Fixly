import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/services/pdf_report_service.dart';
import 'package:printing/printing.dart'; // Важно для Printing.sharePdf

class ChairmanAnalyticsScreen extends StatefulWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  State<ChairmanAnalyticsScreen> createState() => _ChairmanAnalyticsScreenState();
}

class _ChairmanAnalyticsScreenState extends State<ChairmanAnalyticsScreen> {
  // Переменная для хранения баланса (ручной ввод)
  double _eosiBalance = 2450000; 
  final TextEditingController _balanceController = TextEditingController();
  
  // Состояние загрузки для PDF
  bool _isGeneratingPdf = false;

  // Функция для изменения баланса через диалог
  void _showEditBalanceDialog(String lang) {
    _balanceController.text = _eosiBalance.toInt().toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang == 'ru' ? "Обновить баланс ЕОСИ" : "ЕОСИ балансын жаңарту"),
        content: TextField(
          controller: _balanceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: "₸",
            hintText: lang == 'ru' ? "Введите сумму" : "Соманы енгізіңіз",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
              });
              Navigator.pop(context);
            },
            child: Text(lang == 'ru' ? "Сохранить" : "Сақтау"),
          ),
        ],
      ),
    );
  }

  // ФУНКЦИЯ ГЕНЕРАЦИИ И ОТПРАВКИ ОТЧЕТА
  Future<void> _handlePdfGeneration(String lang) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Получаем данные всех голосов из базы
      final List<Map<String, dynamic>> votes = await supabase
          .from('votes')
          .select();

      if (votes.isEmpty) {
        throw lang == 'ru' ? "Нет данных для отчета" : "Есеп үшін деректер жоқ";
      }

      // 2. Подготавливаем данные (скачиваем байты подписей)
      List<Map<String, dynamic>> preparedVotes = [];
      for (var v in votes) {
        // Скачиваем подпись по URL
        final bytes = await PdfReportService.downloadSignature(v['signature_url']);
        var vCopy = Map<String, dynamic>.from(v);
        vCopy['sig_bytes'] = bytes;
        preparedVotes.add(vCopy);
      }

      // 3. Создаем PDF документ через сервис
      // ВНИМАНИЕ: Убедитесь, что в PdfReportService метод возвращает pw.Document или байты
      // Для этого примера мы используем логику Printing.sharePdf прямо здесь для надежности
      
      final pdfData = await PdfReportService.createPdfDocument(
        proposalTitle: lang == 'ru' ? "Протокол ОСИ: Результаты голосования" : "Мүлік иелерінің бірлестігінің хаттамасы",
        votes: preparedVotes,
      );

      // 4. Открываем системное меню "Поделиться" (Share)
      // Это позволит сохранить в файлы или отправить в WhatsApp
      await Printing.sharePdf(
        bytes: pdfData, 
        filename: 'report_osi_${DateTime.now().day}_${DateTime.now().month}.pdf'
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'ru' ? "Отчет готов к отправке" : "Есеп жіберуге дайын"), 
          backgroundColor: Colors.green
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${lang == 'ru' ? 'Ошибка' : 'Қате'}: $e"), 
          backgroundColor: Colors.red
        ),
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
                        // 1. ФИНАНСОВЫЙ БЛОК
                        _buildFinancialOverview(_eosiBalance, totalSpent, lang),
                        
                        const SizedBox(height: 30),
                        
                        // 2. ПРОГНОЗ РЕМОНТОВ
                        _buildSectionHeader(lang == 'ru' ? "Прогноз ремонтов (AI)" : "Жөндеу болжамы (AI)"),
                        _buildRepairPredictor(_eosiBalance, lang),

                        const SizedBox(height: 30),

                        // 3. ЗДОРОВЬЕ ДОМА
                        _buildSectionHeader(lang == 'ru' ? "Состояние жилого объекта" : "Тұрғын үй жағдайы"),
                        _buildHealthIndicator(health, activeCount, lang),
                        
                        const SizedBox(height: 30),

                        // 4. СОВЕТ ОТ ИИ
                        _buildSectionHeader(lang == 'ru' ? "Рекомендация системы" : "Жүйе ұсынысы"),
                        _buildAIAdviceCard(totalSpent, lang, isDark),

                        const SizedBox(height: 30),

                        // 5. ДЕТАЛЬНЫЙ АНАЛИЗ ЦЕН
                        _buildSectionHeader(lang == 'ru' ? "Анализ цен по рынку" : "Нарықтық баға анализі"),
                        _buildMarketComparison(tasks, lang, isDark),

                        const SizedBox(height: 30),

                        // 6. ПОСЛЕДНИЕ РАБОТЫ
                        _buildRecentTasksList(tasks, lang),

                        const SizedBox(height: 30),

                        // 7. КНОПКА ОТЧЕТА
                        _buildReportButton(lang),
                        
                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              ),
              
              // АНИМАЦИЯ ЗАГРУЗКИ PDF (OVERLAY)
              if (_isGeneratingPdf)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 5,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          lang == 'ru' ? "Сбор данных и генерация PDF..." : "Деректерді жинау және PDF жасау...",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lang == 'ru' ? "Это может занять до 10 секунд" : "Бұл 10 секундқа дейін созылуы мүмкін",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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

  // --- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ (МЕТОДЫ ИНТЕРФЕЙСА) ---

  Widget _buildFinancialOverview(double balance, double spent, String lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showEditBalanceDialog(lang),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      lang == 'ru' ? "СЧЕТ ЕОСИ" : "ЕОСИ ШОТЫ", 
                      style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.pencil, color: Colors.blueAccent, size: 10),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${balance.toInt()} ₸", 
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          Container(width: 1, height: 45, color: Colors.white12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lang == 'ru' ? "ПОТРАЧЕНО" : "ЖҰМСАЛДЫ", 
                style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)
              ),
              const SizedBox(height: 8),
              Text(
                "${spent.toInt()} ₸", 
                style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepairPredictor(double balance, String lang) {
    List<Map<String, dynamic>> predictions = [];
    if (balance > 1000000) {
      predictions.add({'title': lang == 'ru' ? 'Обновление кровли' : 'Шатырды жаңарту', 'icon': LucideIcons.home, 'cost': '~950 000 ₸'});
      predictions.add({'title': lang == 'ru' ? 'Ремонт подъезда' : 'Кіреберісті жөндеу', 'icon': LucideIcons.paintBucket, 'cost': '~400 000 ₸'});
    } else if (balance > 200000) {
      predictions.add({'title': lang == 'ru' ? 'Замена освещения' : 'Жарықты ауыстыру', 'icon': LucideIcons.lightbulb, 'cost': '~120 000 ₸'});
    } else {
      predictions.add({'title': lang == 'ru' ? 'Мелкий ремонт' : 'Ұсақ-түйек жөндеу', 'icon': LucideIcons.wrench, 'cost': '< 50 000 ₸'});
    }

    return Column(
      children: predictions.map((p) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: ListTile(
          leading: Icon(p['icon'] as IconData, color: Colors.blue),
          title: Text(p['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(lang == 'ru' ? "Рекомендовано AI" : "AI ұсынған"),
          trailing: Text(p['cost'] as String, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
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
                  Text(lang == 'ru' ? "Активных задач" : "Белсенді тапсырма", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("$active", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: health, 
            minHeight: 8, 
            borderRadius: BorderRadius.circular(10), 
            backgroundColor: color.withOpacity(0.1), 
            color: color
          ),
        ],
      ),
    );
  }

  Widget _buildAIAdviceCard(double spent, String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Colors.orange),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              spent > 500000 
                ? (lang == 'ru' ? "Расходы выше среднего. Проверьте сметы сантехников." : "Шығындар жоғары. Сантехника сметасын тексеріңіз.")
                : (lang == 'ru' ? "Бюджет в норме. Хорошее время для плановой диагностики." : "Бюджет қалыпты. Жоспарлы диагностика үшін жақсы уақыт."),
              style: const TextStyle(fontSize: 13),
            ),
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(diff, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: val / 1.5, 
          color: color, 
          backgroundColor: color.withOpacity(0.1), 
          minHeight: 5, 
          borderRadius: BorderRadius.circular(5)
        ),
      ],
    );
  }

  Widget _buildRecentTasksList(List<Map<String, dynamic>> tasks, String lang) {
    final lastTasks = tasks.where((t) => t['status'] == 'completed').toList().reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(lang == 'ru' ? "Последние отчеты" : "Соңғы есептер"),
        if (lastTasks.isEmpty) 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              lang == 'ru' ? "Нет завершенных работ" : "Аяқталған жұмыс жоқ",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ...lastTasks.map((t) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
          title: Text(t['category'] ?? "Ремонт", style: const TextStyle(fontSize: 14)),
          trailing: Text("${t['final_price']} ₸", style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ],
    );
  }

  Widget _buildReportButton(String lang) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B0FF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isGeneratingPdf ? null : () => _handlePdfGeneration(lang),
        icon: const Icon(LucideIcons.fileDown, color: Colors.white),
        label: Text(
          lang == 'ru' ? "СКАЧАТЬ И ПОДЕЛИТЬСЯ ОТЧЕТОМ" : "ЕСЕПТІ ЖҮКТЕУ ЖӘНЕ БӨЛІСУ", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, 
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 15, left: 4),
    child: Text(
      title, 
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
    ),
  );
}