import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fixly_app/services/billing_service.dart';
import 'package:fixly_app/services/building_context_service.dart';

class ResidentInvoicesScreen extends StatefulWidget {
  const ResidentInvoicesScreen({super.key});

  @override
  State<ResidentInvoicesScreen> createState() => _ResidentInvoicesScreenState();
}

class _ResidentInvoicesScreenState extends State<ResidentInvoicesScreen> {
  final BillingService _billingService = BillingService();
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final context = await BuildingContextService.loadCurrent();
    if (context != null && context.hasBuilding) {
      final invoices = await _billingService.getBuildingInvoices(context.buildingId!);
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- МЕТОД ДЛЯ ФЕЙКОВОЙ ОПЛАТЫ В БАЗЕ ---
  Future<void> _processFakePayment(String invoiceId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.green)),
      );
      
      await Future.delayed(const Duration(seconds: 1));

      await Supabase.instance.client
          .from('invoices')
          .update({'status': 'paid'})
          .eq('id', invoiceId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Успешно оплачено! (Тестовый режим)'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvoices(); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при оплате: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- МЕТОД ДЛЯ ГЕНЕРАЦИИ И СКАЧИВАНИЯ PDF КВИТАНЦИИ ---
  Future<void> _downloadReceipt(Map<String, dynamic> invoice) async {
    // Показываем лоадер, так как загрузка шрифта для кириллицы требует доли секунды
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF8A9A5B))),
    );

    try {
      final doc = pw.Document();
      // Загружаем шрифты с поддержкой кириллицы
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('Квитанция об оплате', style: pw.TextStyle(font: fontBold, fontSize: 24)),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Платформа:', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey600)),
                      pw.Text('Fixly', style: pw.TextStyle(font: fontBold, fontSize: 14, color: const PdfColor.fromInt(0xFF8A9A5B))),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 20),
                  pw.Text('Детали платежа', style: pw.TextStyle(font: fontBold, fontSize: 18)),
                  pw.SizedBox(height: 15),
                  pw.Text('Назначение: ${invoice['purpose'] ?? 'Целевой сбор'}', style: pw.TextStyle(font: font, fontSize: 16)),
                  pw.SizedBox(height: 8),
                  pw.Text('Сумма: ${invoice['amount']} KZT', style: pw.TextStyle(font: font, fontSize: 16)),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.green200)
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('СТАТУС: ОПЛАЧЕНО', style: pw.TextStyle(font: fontBold, color: PdfColors.green800)),
                      ]
                    ),
                  ),
                  pw.Spacer(),
                  pw.Center(
                    child: pw.Text('Спасибо за своевременную оплату!', style: pw.TextStyle(font: font, color: PdfColors.grey600)),
                  )
                ],
              ),
            );
          },
        ),
      );

      if (mounted) Navigator.pop(context); // Скрываем лоадер

      // Вызов нативного окна сохранения/шаринга PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Квитанция_Fixly_${invoice['id']}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания квитанции: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- ШТОРКА (BOTTOM SHEET) ДЛЯ УЖЕ ОПЛАЧЕННОГО СЧЕТА ---
  void _showPaidInvoiceSheet(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(LucideIcons.checkCircle2, size: 50, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Счет оплачен',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вы можете загрузить или распечатать электронную квитанцию',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8A9A5B),
                    side: const BorderSide(color: Color(0xFF8A9A5B), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(LucideIcons.download),
                  label: const Text(
                    'Скачать квитанцию',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Скрываем шторку
                    _downloadReceipt(invoice); // Генерируем PDF
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- ШТОРКА (BOTTOM SHEET) ДЛЯ ОПЛАТЫ ---
  void _showFakePaymentSheet(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(LucideIcons.creditCard, size: 50, color: Color(0xFF8A9A5B)),
              const SizedBox(height: 16),
              const Text(
                'Оплата счета',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                invoice['purpose'] ?? 'Целевой сбор',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${invoice['amount']} ₸',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.info, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Это тестовая оплата (скелет). Реальные деньги не списываются.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A9A5B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); 
                    _processFakePayment(invoice['id'].toString());
                  },
                  child: const Text(
                    'Оплатить (Тест)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Счета и квитанции')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('Нет выставленных счетов'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    final isPending = invoice['status'] == 'pending';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        // Разветвление логики нажатия: 
                        // если не оплачено -> шторка оплаты, если оплачено -> шторка скачивания
                        onTap: isPending 
                            ? () => _showFakePaymentSheet(invoice) 
                            : () => _showPaidInvoiceSheet(invoice),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPending ? const Color(0xFF8A9A5B) : Colors.green,
                            child: Icon(
                              isPending ? LucideIcons.receipt : LucideIcons.checkCircle2, 
                              color: Colors.white
                            ),
                          ),
                          title: Text(
                            invoice['purpose'] ?? 'Счет',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Сумма: ${invoice['amount']} ₸'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isPending 
                                  ? Colors.orange.withOpacity(0.2) 
                                  : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPending ? 'К оплате' : 'Оплачено',
                              style: TextStyle(
                                color: isPending ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}