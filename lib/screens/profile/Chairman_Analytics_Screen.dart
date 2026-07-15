// lib/screens/chairman_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart'; // Предполагается, что здесь лежит appLanguage
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/services/pdf_report_service.dart';
import 'package:fixly_app/services/ai_service.dart'; 
import 'package:fixly_app/services/building_context_service.dart';
import 'package:printing/printing.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fixly_app/theme/app_theme.dart'; // Подключение единой дизайн-системы Fixly

class ChairmanAnalyticsScreen extends StatefulWidget {
  const ChairmanAnalyticsScreen({super.key});

  @override
  State<ChairmanAnalyticsScreen> createState() => _ChairmanAnalyticsScreenState();
}

class _ChairmanAnalyticsScreenState extends State<ChairmanAnalyticsScreen> {
  // --- 1. ФИНАНСОВЫЕ ПОКАЗАТЕЛИ ---
  double _eosiBalance = 2450000;      // Текущий счет (ЕОСИ)
  double _capitalBalance = 5800000;   // Кап. ремонт
  String? _buildingId;                // Используется для фильтрации по дому

  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _capitalController = TextEditingController();
  final TextEditingController _manualStatController = TextEditingController();

  bool _isGeneratingPdf = false;
  bool _isAiLoading = false;
  String _aiForecastText = ""; 
  List<Map<String, dynamic>> _aiPriorityTasks = []; 
  
  // --- 2. ДАННЫЕ РЫНКА (ФАКТОР НДС 16% И РК 2025) ---
  final Map<String, Map<String, dynamic>> _marketStats = {
    'utilities': {
      'trend': 0.18, 
      'label': 'Тарифы ЖКХ (РК)', 
      'info': 'Программа "Тариф в обмен на инвестиции"',
      'colorKey': 'danger'
    },
    'materials': {
      'trend': 0.16, 
      'label': 'Стройматериалы', 
      'info': 'Учет планируемого НДС 16% в 2025 году',
      'colorKey': 'warning'
    },
    'services': {
      'trend': 0.14, 
      'label': 'Сервисные услуги', 
      'info': 'Подорожание из-за роста МРП и налогов',
      'colorKey': 'primary'
    },
  };

  @override
  void initState() {
    super.initState();
    _loadBuildingAndAnalysis();
  }

  Future<void> _loadBuildingAndAnalysis() async {
    _buildingId = await BuildingContextService.currentBuildingId();
    if (mounted) setState(() {});
    await _fetchAiAnalysis();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _capitalController.dispose();
    _manualStatController.dispose();
    super.dispose();
  }

  // --- 3. ЛОГИКА ИИ АНАЛИЗА ---
  Future<void> _fetchAiAnalysis() async {
    if (!mounted) return;
    setState(() {
      _isAiLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      var lastTasksQuery = supabase
          .from('tasks')
          .select()
          .eq('status', 'completed') as dynamic;
      if (_buildingId != null && _buildingId!.isNotEmpty) {
        lastTasksQuery = lastTasksQuery.eq('building_id', _buildingId!);
      }
      final List<Map<String, dynamic>> lastTasks = await lastTasksQuery
          .order('created_at', ascending: false)
          .limit(15);

      String marketContext = """
      ВНИМАНИЕ: Экономика Казахстана 2025. 
      - Налоговая реформа: Ожидаемое повышение НДС до 16%.
      - Стройматериалы в РК: Рост цен на 16-20%.
      - Коммунальные услуги: Плановое повышение тарифов на 15-25%.
      - Дополнительно: ${_manualStatController.text}
      """;

      final result = await AIService.getChairmanFinancialAnalysis(
        savingAccount: _eosiBalance,
        capitalRepairAccount: _capitalBalance,
        lang: appLanguage.value,
        recentExpenses: lastTasks,
        marketContext: marketContext, 
      );

      if (mounted) {
        setState(() {
          _aiForecastText = result;
          _updateAiPriorityTasks();
        });
      }
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  void _updateAiPriorityTasks() {
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

  // --- 4. ДИАЛОГИ ---

  void _showManualStatDialog(String lang) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final c = AppColors.of(dialogCtx);
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            lang == 'ru' ? "Факторы рынка РК" : "РК нарықтық факторлары",
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang == 'ru' 
                  ? "Введите изменения (например: рост цен на лифты +20%)" 
                  : "Өзгерістерді енгізіңіз (мыс: лифт бағасы +20%)",
                style: TextStyle(fontSize: 14, color: c.textTertiary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualStatController,
                maxLines: 3,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: c.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  hintText: lang == 'ru' ? "НДС 16%, инфляция..." : "ҚҚС 16%...",
                  hintStyle: TextStyle(color: c.textTertiary.withOpacity(0.6)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx), 
              child: Text(lang == 'ru' ? "Закрыть" : "Жабу", style: TextStyle(color: c.textTertiary))
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _fetchAiAnalysis(); 
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: Text(lang == 'ru' ? "Обновить" : "Жаңарту", style: const TextStyle(color: Colors.white))
            ),
          ],
        );
      },
    );
  }

  void _showEditBalanceDialog(String lang) {
    _balanceController.text = _eosiBalance.toInt().toString();
    _capitalController.text = _capitalBalance.toInt().toString();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final c = AppColors.of(dialogCtx);
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            lang == 'ru' ? "Корректировка счетов" : "Шоттарды түзету",
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(dialogCtx, _balanceController, lang == 'ru' ? "Счет ЕОСИ" : "ЕОСИ шоты"),
              const SizedBox(height: 15),
              _buildDialogField(dialogCtx, _capitalController, lang == 'ru' ? "Фонд кап. ремонта" : "Күрделі жөндеу қоры"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx), 
              child: Text(lang == 'ru' ? "Отмена" : "Бас тарту", style: TextStyle(color: c.textTertiary))
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _eosiBalance = double.tryParse(_balanceController.text) ?? _eosiBalance;
                  _capitalBalance = double.tryParse(_capitalController.text) ?? _capitalBalance;
                });
                Navigator.pop(dialogCtx);
                _fetchAiAnalysis();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: Text(lang == 'ru' ? "Сохранить" : "Сақтау", style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField(BuildContext context, TextEditingController ctrl, String label) {
    final c = AppColors.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textTertiary),
        suffixText: "₸",
        suffixStyle: TextStyle(color: c.textTertiary),
        filled: true,
        fillColor: c.surfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.textTertiary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }

  // --- 5. ГЕНЕРАЦИЯ PDF ---
  Future<void> _handlePdfGeneration(String lang) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> votes = [];
      if (_buildingId != null && _buildingId!.isNotEmpty) {
        votes = List<Map<String, dynamic>>.from(
          await supabase.from('votes').select().eq('building_id', _buildingId!),
        );
      }
      
      List<Map<String, dynamic>> preparedVotes = [];
      for (var v in votes) {
        dynamic bytes;
        if (v['signature_url'] != null) {
          try {
            bytes = await PdfReportService.downloadSignature(v['signature_url']);
          } catch (e) {
            debugPrint("Sig error: $e");
          }
        }
        var vCopy = Map<String, dynamic>.from(v);
        vCopy['sig_bytes'] = bytes;
        preparedVotes.add(vCopy);
      }

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoMedium();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) => [
            pw.Center(
              child: pw.Text(
                "ЛИСТ ГОЛОСОВАНИЯ СОБСТВЕННИКОВ\n(Письменный опрос)", 
                textAlign: pw.TextAlign.center, 
                style: pw.TextStyle(font: fontBold, fontSize: 14)
              )
            ),
            pw.SizedBox(height: 20),
            pw.Text("Вопрос: Утверждение плана работ на основании AI-аналитики 2025", style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("№", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ФИО", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Кв.", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ЗА", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ПРОТИВ", style: pw.TextStyle(font: fontBold, fontSize: 9))),
                  ]
                ),
                ...List.generate(preparedVotes.isEmpty ? 10 : preparedVotes.length, (index) {
                  if (preparedVotes.isEmpty) {
                    return pw.TableRow(children: List.generate(5, (_) => pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(""))));
                  }
                  final v = preparedVotes[index];
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${index + 1}", style: pw.TextStyle(font: font, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${v['full_name'] ?? ''}", style: pw.TextStyle(font: font, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${v['apartment'] ?? ''}", style: pw.TextStyle(font: font, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: v['decision'] == 'yes' && v['sig_bytes'] != null ? pw.Container(height: 15, child: pw.Image(pw.MemoryImage(v['sig_bytes']))) : pw.Text("")),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: v['decision'] == 'no' && v['sig_bytes'] != null ? pw.Container(height: 15, child: pw.Image(pw.MemoryImage(v['sig_bytes']))) : pw.Text("")),
                    ]
                  );
                }),
              ]
            ),
          ]
        )
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'voting_list.pdf');

    } catch (e) {
      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: c.danger));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleFinancialPdfGeneration(String lang, double spent) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> expenses = [];
      if (_buildingId != null && _buildingId!.isNotEmpty) {
        expenses = List<Map<String, dynamic>>.from(
          await supabase.from('tasks')
            .select()
            .eq('building_id', _buildingId!)
            .eq('status', 'completed')
            .order('completed_at', ascending: false)
        );
      }

      await PdfReportService.exportAndOpenFinancialPdf(
        eosiBalance: _eosiBalance,
        capitalBalance: _capitalBalance,
        totalSpent: spent,
        expenses: expenses,
        address: "Ваш адрес", // Извлекается контекстно при генерации отчета
      );
    } catch (e) {
      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: c.danger));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- 6. ОСНОВНОЙ BUILD ---
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final supabase = Supabase.instance.client;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: c.card,
            elevation: 0,
            title: Text(
              lang == 'ru' ? "Аналитика: Рынок РК" : "Аналитика: РК нарығы",
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
            ),
            iconTheme: IconThemeData(color: c.textPrimary),
            actions: [
              IconButton(
                icon: Icon(LucideIcons.barChart4, color: c.primary), 
                onPressed: () => _showManualStatDialog(lang)
              ),
              IconButton(
                icon: Icon(LucideIcons.sparkles, color: c.warning), 
                onPressed: _fetchAiAnalysis
              )
            ],
          ),
          body: Stack(
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _buildingId != null && _buildingId!.isNotEmpty
                    ? supabase
                        .from('tasks')
                        .stream(primaryKey: ['id'])
                        .eq('building_id', _buildingId!)
                    : const Stream<List<Map<String, dynamic>>>.empty(),
                builder: (context, snapshot) {
                  if (_buildingId == null || _buildingId!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          lang == 'ru'
                              ? 'Дом не привязан к профилю — аналитика недоступна'
                              : 'Үй профильге тіркелмеген — аналитика қолжетімсіз',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textTertiary, fontSize: 14),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: c.primary));
                  }

                  final tasks = snapshot.data!;
                  double spent = 0;
                  int completed = 0;
                  int active = 0;

                  for (var t in tasks) {
                    if (t['status'] == 'completed') {
                      completed++;
                      spent += double.tryParse(t['final_price']?.toString() ?? '0') ?? 0;
                    } else {
                      active++;
                    }
                  }

                  double health = (completed + active) > 0 ? completed / (completed + active) : 1.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StaggeredEntrance(
                          index: 0,
                          child: _buildFinancialOverview(context, _eosiBalance, _capitalBalance, spent, lang),
                        ),
                        const SizedBox(height: 25),
                        
                        _StaggeredEntrance(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(context, lang == 'ru' ? "AI Прогноз" : "AI болжамы"),
                              _buildAIAdviceCard(context, _aiForecastText, _isAiLoading, lang),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        _StaggeredEntrance(
                          index: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(context, lang == 'ru' ? "Критические задачи" : "Маңызды міндеттер"),
                              _buildAiTasksList(context, _aiPriorityTasks),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        _StaggeredEntrance(
                          index: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(context, lang == 'ru' ? "Цены в РК (НДС 16%)" : "РК бағалары (ҚҚС 16%)"),
                              _buildMarketComparison(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        _StaggeredEntrance(
                          index: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(context, lang == 'ru' ? "Статус дома" : "Үйдің күйі"),
                              _buildHealthIndicator(context, health, active, lang),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        _StaggeredEntrance(
                          index: 5,
                          child: _buildReportButtons(context, lang, spent),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              ),
              if (_isGeneratingPdf) _buildOverlayLoader(context, lang == 'ru' ? "Создание PDF..." : "PDF жасалуда..."),
            ],
          ),
        );
      },
    );
  }

  // --- 7. КОМПОНЕНТЫ ИНТЕРФЕЙСА ---

  Widget _buildFinancialOverview(BuildContext context, double bal, double cap, double spent, String lang) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.primary,
            c.primary.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: c.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showEditBalanceDialog(lang),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniBalance(context, lang == 'ru' ? "ОСИ СЧЕТ" : "ОСИ ШОТЫ", bal, Colors.cyanAccent),
                _miniBalance(context, lang == 'ru' ? "КАП. РЕМОНТ" : "КҮРДЕЛІ ЖӨНДЕУ", cap, Colors.orangeAccent),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.15), height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ru' ? "ОСВОЕНО" : "ИГЕРІЛДІ", 
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontWeight: FontWeight.bold)
              ),
              Text(
                "${spent.toInt()} ₸", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniBalance(BuildContext context, String label, double val, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
        const SizedBox(height: 4),
        Text(
          "${val.toInt()} ₸", 
          style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  Widget _buildAIAdviceCard(BuildContext context, String text, bool loading, String lang) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, color: c.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                "AI ANALYTICS", 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.primary.withOpacity(0.75))
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading) 
            LinearProgressIndicator(
              minHeight: 2, 
              color: c.primary, 
              backgroundColor: c.primary.withOpacity(0.1),
            ),
          if (!loading) 
            Text(
              text.isEmpty ? (lang == 'ru' ? "Нажмите иконку искр для анализа" : "Талдау үшін ұшқын белгішесін басыңыз") : text,
              style: TextStyle(fontSize: 13, height: 1.5, color: c.textPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildAiTasksList(BuildContext context, List<Map<String, dynamic>> tasks) {
    final c = AppColors.of(context);
    return Column(
      children: tasks.map((t) {
        final bool isCritical = t['importance'] == 'Critical';
        final highlightColor = isCritical ? c.danger : c.warning;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: c.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.textTertiary.withOpacity(0.15)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: highlightColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                t['icon'] as IconData, 
                color: highlightColor,
                size: 20,
              ),
            ),
            title: Text(
              t['title'], 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)
            ),
            trailing: Text(
              t['cost'], 
              style: TextStyle(fontWeight: FontWeight.bold, color: c.primary, fontSize: 14)
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getMarketColor(BuildContext context, String key) {
    final c = AppColors.of(context);
    switch (key) {
      case 'danger': return c.danger;
      case 'warning': return c.warning;
      case 'primary': return c.primary;
      default: return c.primary;
    }
  }

  Widget _buildMarketComparison(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: _marketStats.entries.map((e) {
        final trend = e.value['trend'] as double;
        final color = _getMarketColor(context, e.value['colorKey']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.value['label'], 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)
                  ),
                  Text(
                    "+${(trend * 100).toInt()}%", 
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: trend * 2, 
                color: color, 
                backgroundColor: color.withOpacity(0.1), 
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHealthIndicator(BuildContext context, double health, int active, String lang) {
    final c = AppColors.of(context);
    Color col = health > 0.7 ? c.success : c.warning;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: col.withOpacity(0.25))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${(health * 100).toInt()}%", 
            style: TextStyle(color: col, fontSize: 32, fontWeight: FontWeight.w900)
          ),
          Text(
            lang == 'ru' ? "Активно: $active" : "Белсенді: $active", 
            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)
          ),
        ],
      ),
    );
  }

  Widget _buildReportButtons(BuildContext context, String lang, double spent) {
    final c = AppColors.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _handlePdfGeneration(lang),
            icon: const Icon(LucideIcons.fileDown, color: Colors.white),
            label: Text(
              lang == 'ru' ? "СКАЧАТЬ ЛИСТ ГОЛОСОВАНИЯ" : "ДАУЫС БЕРУ ПАРАҒЫН ЖҮКТЕУ",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _handleFinancialPdfGeneration(lang, spent),
            icon: Icon(LucideIcons.fileText, color: c.primary),
            label: Text(
              lang == 'ru' ? "ВЫГРУЗИТЬ ФИН. ОТЧЕТ" : "ҚАРЖЫЛЫҚ ЕСЕПТІ ЖҮКТЕУ",
              style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 14)
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.primary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.textTertiary, letterSpacing: 1)
      ),
    );
  }

  Widget _buildOverlayLoader(BuildContext context, String text) {
    final c = AppColors.of(context);
    return Container(
      color: c.background.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.primary),
            const SizedBox(height: 20),
            Text(
              text, 
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация элементов дашборда
// ============================================================
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}