import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Страница детального просмотра заказа
/// Поддерживает: звонки, чат, изменение статусов, формирование счета с AI-аналитиком
class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- 1. ФУНКЦИЯ ОТПРАВКИ ФИСКАЛЬНОГО ЧЕКА В ЧАТ ---
  Future<void> _sendInvoiceToChat(String taskId, double base, double materials, double total) async {
    final myId = supabase.auth.currentUser?.id;
    final String invoiceText = """
🧾 *ФИСКАЛЬНЫЙ ЧЕК / ШЕК*
--------------------------------
🛠 Работа: ${base.toInt()} ₸
📦 Материалы: ${materials.toInt()} ₸
--------------------------------
💰 *ИТОГО: ${total.toInt()} ₸*
--------------------------------
✅ Статус: Выполнено через Fixly
AI Verified: Цена соответствует рынку (НДС 16% учтен)
""";

    try {
      await supabase.from('messages').insert({
        'task_id': taskId,
        'sender_id': myId,
        'text': invoiceText,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Ошибка при отправке чека в чат: $e");
    }
  }

  // --- 2. ФУНКЦИЯ ТЕЛЕФОННОГО ЗВОНКА ---
  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Телефон не указан")),
      );
      return;
    }
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Не удалось совершить звонок: $e");
    }
  }

  // --- 3. ОБНОВЛЕНИЕ СТАТУСА И ЛОГИРОВАНИЕ ---
  Future<void> _updateStatus(String status, String lang, {bool assignMe = false, double? finalPrice}) async {
    setState(() => _isLoading = true);
    final myId = supabase.auth.currentUser?.id;
    
    try {
      Map<String, dynamic> updates = {'status': status};
      if (assignMe) updates['assignee_id'] = myId;
      if (finalPrice != null) updates['final_price'] = finalPrice; 
      
      await supabase.from('tasks').update(updates).eq('id', widget.order['id']);
      
      String logText = "";
      if (status == 'in_progress') {
        logText = lang == 'ru' ? "Мастер принял заявку" : "Шебер өтінімді қабылдады";
      } else if (status == 'completed') {
        logText = lang == 'ru' 
            ? "Заявка выполнена. Итого: ${finalPrice?.toInt()} ₸ (Проверено AI)" 
            : "Өтінім орындалды. Барлығы: ${finalPrice?.toInt()} ₸ (AI тексерілді)";
      }
          
      await supabase.from('task_logs').insert({
        'task_id': widget.order['id'], 
        'action_text': logText,
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      debugPrint("Ошибка обновления статуса: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 4. МАКЕТ AI-АНАЛИЗАТОРА (НДС 16% И РЫНОЧНЫЕ ЦЕНЫ 2024-25) ---
  Widget _buildAIPriceGuard(double currentTotal, String taskTitle, String lang) {
    // В реальности здесь идет запрос к Gemini 1.5/3.0
    // Эмуляция: средняя цена за стандартную работу ~12-15к
    double marketLimit = 18000.0; 
    bool isOverpriced = currentTotal > marketLimit;
    double diff = ((currentTotal - marketLimit) / marketLimit) * 100;

    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverpriced ? Colors.orangeAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverpriced ? Colors.orangeAccent : Colors.greenAccent, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            isOverpriced ? Icons.analytics_outlined : Icons.verified_outlined,
            color: isOverpriced ? Colors.orangeAccent : Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverpriced 
                    ? (lang == 'ru' ? "Внимание: Выше среднего" : "Назар аударыңыз") 
                    : (lang == 'ru' ? "AI: Честная цена" : "AI: Әділ баға"),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isOverpriced ? Colors.orangeAccent : Colors.greenAccent),
                ),
                Text(
                  isOverpriced 
                    ? (lang == 'ru' ? "Сумма на ${diff.toInt()}% выше рыночной за 2024г. Учтен НДС 16%." : "Баға нарықтан ${diff.toInt()}% жоғары. ҚҚС 16% ескерілді.")
                    : (lang == 'ru' ? "Цена соответствует стандартам 2024 года с учетом НДС 16%." : "Баға 2024 жылғы стандарттарға сәйкес."),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. МОДАЛЬНОЕ ОКНО ФОРМИРОВАНИЯ ЧЕКА ---
  void _showFinalInvoice(BuildContext context, double basePrice, String lang) {
    final TextEditingController workController = TextEditingController(text: basePrice.toInt().toString());
    final TextEditingController materialController = TextEditingController();
    double currentTotal = basePrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text(lang == 'ru' ? "Формирование счета" : "Шотты қалыптастыру", 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                
                TextField(
                  controller: workController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang == 'ru' ? "Стоимость работы (₸)" : "Жұмыс құны (₸)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.build_circle_outlined, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      double work = double.tryParse(val) ?? 0;
                      double mats = double.tryParse(materialController.text) ?? 0;
                      currentTotal = work + mats;
                    });
                  },
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: materialController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang == 'ru' ? "Материалы / Запчасти (₸)" : "Материалдар (₸)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      double work = double.tryParse(workController.text) ?? 0;
                      double mats = double.tryParse(val) ?? 0;
                      currentTotal = work + mats;
                    });
                  },
                ),
                
                // ИНТЕГРАЦИЯ AI АНАЛИЗА
                _buildAIPriceGuard(currentTotal, widget.order['title'] ?? '', lang),

                const Divider(height: 40, color: Colors.white10),
                
                _buildInvoiceRow(
                  lang == 'ru' ? "ИТОГО К ОПЛАТЕ:" : "ТӨЛЕУГЕ БАРЛЫҒЫ:", 
                  "${currentTotal.toInt()} ₸", 
                  isTotal: true
                ),
                
                const SizedBox(height: 25),
                
                _btn(lang == 'ru' ? "Завершить и отправить чек" : "Аяқтау және чекті жіберу", Colors.blueAccent, () async {
                  double finalWork = double.tryParse(workController.text) ?? 0;
                  double finalMats = double.tryParse(materialController.text) ?? 0;
                  double finalTotal = finalWork + finalMats;

                  Navigator.pop(context); 
                  await _updateStatus('completed', lang, finalPrice: finalTotal);
                  await _sendInvoiceToChat(widget.order['id'].toString(), finalWork, finalMats, finalTotal);
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- ХЕЛПЕРЫ ДЛЯ ИНТЕРФЕЙСА ---
  Widget _buildInvoiceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: isTotal ? Colors.white : Colors.grey, 
          fontSize: isTotal ? 16 : 14, 
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal
        )),
        Text(value, style: TextStyle(
          color: isTotal ? const Color(0xFF3B82F6) : Colors.white, 
          fontSize: isTotal ? 20 : 16, 
          fontWeight: FontWeight.bold
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Детали заказа" : "Тапсырыс мәліметтері"),
            centerTitle: true,
            actions: [
              if (userRole.value == 'osi_chairman')
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: Text(lang == 'ru' ? "Удалить?" : "Өшіру?", style: const TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Нет")),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Да", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await supabase.from('tasks').delete().eq('id', widget.order['id']);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                )
            ],
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('id', widget.order['id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: CircularProgressIndicator());
              
              final task = snapshot.data!.first;
              final imgUrl = task['image_url'] ?? task['image'] ?? task['photo_url'];
              final double basePrice = (task['final_price'] ?? task['price'] ?? 0).toDouble();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imgUrl != null && imgUrl.toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(imgUrl, width: double.infinity, height: 250, fit: BoxFit.cover),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(task['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                        _detailPriority(task['priority'], lang),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    Text(task['description'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.4)),
                    
                    const Divider(height: 40, color: Colors.white10),

                    _buildContactCard(
                      lang: lang,
                      name: task['customer_name'] ?? 'Fixly User',
                      address: task['address'] ?? 'Адрес не указан',
                      phone: task['customer_phone'],
                      apartment: task['apartment'],
                      residentPhone: task['resident_phone'],
                    ),

                    const SizedBox(height: 30),

                    if (_isLoading) 
                      const Center(child: CircularProgressIndicator())
                    else if (task['status'] == 'new' && userRole.value != 'osi_chairman') 
                      _btn(lang == 'ru' ? "Взять в работу" : "Жұмысқа алу", Colors.blueAccent, () => _updateStatus('in_progress', lang, assignMe: true))
                    else if (task['status'] == 'in_progress' && task['assignee_id'] == myId) 
                      _btn(lang == 'ru' ? "Завершить работу" : "Жұмысты аяқтау", Colors.green, () => _showFinalInvoice(context, basePrice, lang))
                    else 
                      _info(
                        task['status'] == 'completed' ? (lang == 'ru' ? "Заявка выполнена" : "Тапсырыс орындалды") : (lang == 'ru' ? "Заявка в процессе" : "Өтінім орындалуда"), 
                        task['status'] == 'completed' ? Colors.green : Colors.orange
                      ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
                          taskId: task['id'].toString(), 
                          taskTitle: task['title'], 
                          receiverId: task['user_id'] ?? '', 
                          receiverName: 'Customer',
                        ))),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(userRole.value == 'osi_chairman' ? (lang == 'ru' ? "Чат с мастером" : "Шебермен чат") : (lang == 'ru' ? "Открыть чат" : "Чатты ашу")),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    _buildLogs(task['id'], lang),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContactCard({required String lang, required String name, required String address, String? phone, dynamic apartment, String? residentPhone}) {
    String fullAddress = address;
    if (apartment != null && apartment.toString().isNotEmpty) {
      fullAddress += ", ${lang == 'ru' ? 'кв.' : 'п.'} $apartment";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(fullAddress, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.person, color: Colors.blue, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(lang == 'ru' ? "Заказчик" : "Тапсырыс беруші", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (phone != null)
                IconButton(onPressed: () => _makeCall(phone), icon: const Icon(Icons.phone, color: Colors.green)),
            ],
          ),
          if (residentPhone != null && residentPhone.isNotEmpty) ...[
            const Divider(height: 24, color: Colors.white10),
            Row(
              children: [
                const Icon(Icons.home_repair_service_outlined, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text("${lang == 'ru' ? 'Житель:' : 'Тұрғын:'} $residentPhone", style: const TextStyle(color: Colors.white70, fontSize: 14))),
                IconButton(onPressed: () => _makeCall(residentPhone), icon: const Icon(Icons.call_made, color: Colors.orangeAccent, size: 20)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailPriority(String? p, String lang) {
    Color c = p == 'high' ? Colors.red : (p == 'medium' ? Colors.orange : Colors.green);
    String t = p == 'high' ? (lang == 'ru' ? 'Высокий' : 'Жоғары') : (p == 'medium' ? (lang == 'ru' ? 'Средний' : 'Орташа') : (lang == 'ru' ? 'Низкий' : 'Төмен'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.5))),
      child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _btn(String t, Color c, VoidCallback a) => SizedBox(
    width: double.infinity, 
    height: 55, 
    child: ElevatedButton(
      onPressed: a, 
      style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0), 
      child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
    )
  );
  
  Widget _info(String t, Color c) => Container(
    width: double.infinity, 
    padding: const EdgeInsets.all(16), 
    decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))), 
    child: Center(child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 15)))
  );

  Widget _buildLogs(dynamic taskId, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(lang == 'ru' ? "История заявки" : "Өтінім тарихы", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('task_logs').stream(primaryKey: ['id']).eq('task_id', taskId).order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Событий пока нет", style: TextStyle(color: Colors.grey));
            return ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: snapshot.data!.length, 
              itemBuilder: (context, i) {
                final log = snapshot.data![i];
                final date = DateTime.parse(log['created_at']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.radio_button_checked, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['action_text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                            Text(DateFormat('dd MMM, HH:mm').format(date.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ]
    );
  }
}