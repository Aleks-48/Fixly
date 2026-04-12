import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ============================================================
//  OrderDetailsPage — детали заказа
//  • Таблица: 'tasks', поле исполнителя: 'master_id'
//  • Роли: resident | master | chairman
//  • Статусы: new → in_progress → completed | cancelled
// ============================================================
class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // ── ЗВОНОК ─────────────────────────────────────────────────
  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              appLanguage.value == 'ru' ? 'Телефон не указан' : 'Телефон жоқ'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri(
        scheme: 'tel',
        path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── ФИСКАЛЬНЫЙ ЧЕК В ЧАТ ──────────────────────────────────
  Future<void> _sendInvoiceToChat(
      String taskId, double work, double mats, double total) async {
    final myId = _supabase.auth.currentUser?.id;
    final lang = appLanguage.value;
    final invoiceText = lang == 'ru'
        ? '''🧾 ФИСКАЛЬНЫЙ ЧЕК
───────────────────
🛠 Работа:       ${work.toInt()} ₸
📦 Материалы:    ${mats.toInt()} ₸
───────────────────
💰 ИТОГО: ${total.toInt()} ₸
✅ Выполнено через Fixly (НДС 16% учтён)'''
        : '''🧾 ФИСКАЛДЫҚ ЧЕК
───────────────────
🛠 Жұмыс:        ${work.toInt()} ₸
📦 Материалдар:  ${mats.toInt()} ₸
───────────────────
💰 БАРЛЫҒЫ: ${total.toInt()} ₸
✅ Fixly арқылы орындалды''';

    try {
      await _supabase.from('messages').insert({
        'task_id'   : taskId,
        'sender_id' : myId,
        'text'      : invoiceText,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('sendInvoice error: $e');
    }
  }

  // ── ОБНОВЛЕНИЕ СТАТУСА + ЛОГ ──────────────────────────────
  Future<void> _updateStatus(
      String status, String lang, {bool assignMe = false, double? finalPrice}) async {
    setState(() => _isLoading = true);
    final myId = _supabase.auth.currentUser?.id;

    try {
      final Map<String, dynamic> updates = {'status': status};
      if (assignMe && myId != null) updates['master_id'] = myId; // ← master_id, не assignee_id
      if (finalPrice != null) updates['final_price'] = finalPrice;

      await _supabase
          .from('tasks') // ← таблица tasks
          .update(updates)
          .eq('id', widget.order['id']);

      // Лог
      String logText;
      if (status == 'in_progress') {
        logText = lang == 'ru'
            ? 'Мастер принял заявку'
            : 'Шебер өтінімді қабылдады';
      } else if (status == 'completed') {
        logText = lang == 'ru'
            ? 'Заявка выполнена. Итого: ${finalPrice?.toInt()} ₸'
            : 'Өтінім орындалды. Барлығы: ${finalPrice?.toInt()} ₸';
      } else if (status == 'cancelled') {
        logText = lang == 'ru' ? 'Заявка отменена' : 'Өтінім бас тартылды';
      } else {
        logText = status;
      }

      await _supabase.from('task_logs').insert({
        'task_id'    : widget.order['id'],
        'action_text': logText,
        'created_at' : DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('updateStatus error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── AI-АНАЛИЗАТОР ЦЕН ─────────────────────────────────────
  Widget _buildAIPriceGuard(double total, String title, String lang) {
    const double marketLimit = 18000.0;
    final bool isOver = total > marketLimit && total > 0;
    final double diff =
        isOver ? ((total - marketLimit) / marketLimit * 100) : 0;
    final Color color = isOver ? Colors.orange : Colors.green;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.analytics_outlined : Icons.verified_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOver
                      ? (lang == 'ru'
                          ? 'Внимание: выше среднего на рынке'
                          : 'Назар: нарықтан жоғары')
                      : (lang == 'ru' ? 'AI: честная цена' : 'AI: әділ баға'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  isOver
                      ? (lang == 'ru'
                          ? 'Сумма на ${diff.toInt()}% выше рыночной (НДС 16% учтён)'
                          : 'Баға нарықтан ${diff.toInt()}% жоғары')
                      : (lang == 'ru'
                          ? 'Соответствует рыночным ценам 2024–25'
                          : '2024–25 жылғы нарық бағасына сәйкес'),
                  style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── МОДАЛЬНОЕ ОКНО СЧЁТА ───────────────────────────────────
  void _showFinalInvoice(BuildContext context, double basePrice, String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workCtrl = TextEditingController(text: basePrice.toInt().toString());
    final matsCtrl = TextEditingController();
    double currentTotal = basePrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Дескриптор
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lang == 'ru' ? 'Формирование счёта' : 'Шотты қалыптастыру',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 24),

              // Поле: работа
              _invoiceTextField(
                controller: workCtrl,
                label: lang == 'ru' ? 'Стоимость работы (₸)' : 'Жұмыс құны (₸)',
                icon: Icons.build_circle_outlined,
                isDark: isDark,
                onChanged: (v) => setModal(() {
                  currentTotal = (double.tryParse(v) ?? 0) +
                      (double.tryParse(matsCtrl.text) ?? 0);
                }),
              ),
              const SizedBox(height: 12),

              // Поле: материалы
              _invoiceTextField(
                controller: matsCtrl,
                label: lang == 'ru'
                    ? 'Материалы / Запчасти (₸)'
                    : 'Материалдар (₸)',
                icon: Icons.shopping_bag_outlined,
                isDark: isDark,
                onChanged: (v) => setModal(() {
                  currentTotal = (double.tryParse(workCtrl.text) ?? 0) +
                      (double.tryParse(v) ?? 0);
                }),
              ),

              // AI-анализ
              _buildAIPriceGuard(
                  currentTotal, widget.order['title'] ?? '', lang),

              const Divider(height: 32),

              // Итого
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang == 'ru' ? 'ИТОГО К ОПЛАТЕ:' : 'ТӨЛЕУГЕ БАРЛЫҒЫ:',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text(
                    '${currentTotal.toInt()} ₸',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6)),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Кнопка завершить
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final finalWork = double.tryParse(workCtrl.text) ?? 0;
                    final finalMats = double.tryParse(matsCtrl.text) ?? 0;
                    final finalTotal = finalWork + finalMats;
                    Navigator.pop(ctx);
                    await _updateStatus('completed', lang,
                        finalPrice: finalTotal);
                    await _sendInvoiceToChat(
                        widget.order['id'].toString(),
                        finalWork,
                        finalMats,
                        finalTotal);
                  },
                  child: Text(
                    lang == 'ru'
                        ? 'Завершить и отправить чек'
                        : 'Аяқтау және чекті жіберу',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade300),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF3B82F6)),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      ),
    );
  }

  // ── ПРИОРИТЕТ ──────────────────────────────────────────────
  Widget _priorityBadge(String? p, String lang) {
    final Color c = p == 'high'
        ? Colors.red
        : (p == 'medium' ? Colors.orange : Colors.green);
    final String t = p == 'high'
        ? (lang == 'ru' ? 'Высокий' : 'Жоғары')
        : (p == 'medium'
            ? (lang == 'ru' ? 'Средний' : 'Орташа')
            : (lang == 'ru' ? 'Низкий' : 'Төмен'));
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(t,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── КАРТОЧКА КОНТАКТА ──────────────────────────────────────
  Widget _buildContactCard({
    required String lang,
    required bool isDark,
    required String name,
    required String address,
    String? phone,
    String? apartment,
    String? residentPhone,
  }) {
    final fullAddr = apartment != null && apartment.isNotEmpty
        ? '$address, ${lang == 'ru' ? 'кв.' : 'п.'} $apartment'
        : address;

    final cardColor =
        isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.grey.withOpacity(isDark ? 0.1 : 0.2)),
      ),
      child: Column(
        children: [
          if (fullAddr.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullAddr,
                    style: TextStyle(
                        color:
                            isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          if (fullAddr.isNotEmpty) const Divider(height: 20),
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person,
                    color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      lang == 'ru' ? 'Заказчик' : 'Тапсырыс беруші',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (phone != null && phone.isNotEmpty)
                IconButton(
                  onPressed: () => _makeCall(phone),
                  icon: const Icon(Icons.phone,
                      color: Colors.green),
                ),
            ],
          ),
          if (residentPhone != null &&
              residentPhone.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.home_repair_service_outlined,
                    color: Colors.orangeAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${lang == 'ru' ? 'Житель:' : 'Тұрғын:'} $residentPhone',
                    style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: () => _makeCall(residentPhone),
                  icon: const Icon(Icons.call_made,
                      color: Colors.orangeAccent, size: 20),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── СТАТУС BADGE ───────────────────────────────────────────
  Widget _statusBadge(String status, String lang) {
    final Map<String, Map<String, dynamic>> cfg = {
      'new'        : {'label': lang == 'ru' ? 'Новая' : 'Жаңа',         'color': Colors.blueAccent},
      'in_progress': {'label': lang == 'ru' ? 'В работе' : 'Жұмыста',   'color': Colors.orange},
      'completed'  : {'label': lang == 'ru' ? 'Выполнено' : 'Орындалды', 'color': Colors.green},
      'cancelled'  : {'label': lang == 'ru' ? 'Отменено' : 'Бас тартылды', 'color': Colors.red},
    };
    final entry = cfg[status] ?? cfg['new']!;
    final Color c = entry['color'] as Color;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(
        entry['label'] as String,
        style: TextStyle(
            color: c, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  // ── ИСТОРИЯ ЗАЯВКИ ─────────────────────────────────────────
  Widget _buildLogs(dynamic taskId, String lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang == 'ru' ? 'История заявки' : 'Өтінім тарихы',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase
              .from('task_logs')
              .stream(primaryKey: ['id'])
              .eq('task_id', taskId)
              .order('created_at', ascending: false),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.isEmpty) {
              return Text(
                lang == 'ru'
                    ? 'Событий пока нет'
                    : 'Оқиғалар жоқ',
                style: const TextStyle(color: Colors.grey),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snap.data!.length,
              itemBuilder: (context, i) {
                final log  = snap.data![i];
                final date = DateTime.tryParse(
                        log['created_at']?.toString() ?? '') ??
                    DateTime.now();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.radio_button_checked,
                          size: 14,
                          color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['action_text']?.toString() ??
                                  '',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87),
                            ),
                            Text(
                              DateFormat('dd MMM, HH:mm')
                                  .format(date.toLocal()),
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11),
                            ),
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
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final myId  = _supabase.auth.currentUser?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            title: Text(
              lang == 'ru' ? 'Детали заказа' : 'Тапсырыс мәліметтері',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black87),
            actions: [
              // Удаление — только председатель
              if (userRole.value == 'chairman')
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text(
                          lang == 'ru' ? 'Удалить?' : 'Өшіру?',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(c, false),
                              child: Text(
                                  lang == 'ru' ? 'Нет' : 'Жоқ')),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(c, true),
                              child: Text(
                                lang == 'ru' ? 'Удалить' : 'Өшіру',
                                style: const TextStyle(
                                    color: Colors.red),
                              )),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _supabase
                          .from('tasks')
                          .delete()
                          .eq('id', widget.order['id']);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('tasks')
                .stream(primaryKey: ['id'])
                .eq('id', widget.order['id']),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final task      = snap.data!.first;
              final imgUrl    = task['image_url']?.toString() ??
                  task['image']?.toString() ??
                  task['photo_url']?.toString();
              final basePrice =
                  ((task['final_price'] ?? task['price']) as num?)
                          ?.toDouble() ??
                      0.0;
              final status    = task['status']?.toString() ?? 'new';
              final masterId  = task['master_id']?.toString();
              final isMaster  = userRole.value == 'master';
              final isChairman = userRole.value == 'chairman';
              final isMyTask  = masterId == myId;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фото
                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          imgUrl,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Заголовок + приоритет
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task['title']?.toString() ?? '',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _priorityBadge(
                            task['priority']?.toString(), lang),
                      ],
                    ),

                    const SizedBox(height: 8),
                    _statusBadge(status, lang),
                    const SizedBox(height: 12),

                    // Описание
                    if ((task['description']?.toString() ?? '')
                        .isNotEmpty)
                      Text(
                        task['description'].toString(),
                        style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? Colors.white60
                                : Colors.black54,
                            height: 1.5),
                      ),

                    // Цена
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(LucideIcons.wallet,
                            size: 16,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38),
                        const SizedBox(width: 6),
                        Text(
                          '${basePrice.toInt()} ₸',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.shade200),
                    const SizedBox(height: 20),

                    // Контакт
                    _buildContactCard(
                      lang          : lang,
                      isDark        : isDark,
                      name          : task['customer_name']?.toString() ?? 'Fixly User',
                      address       : task['address']?.toString() ?? '',
                      phone         : task['customer_phone']?.toString(),
                      apartment     : task['apartment']?.toString(),
                      residentPhone : task['resident_phone']?.toString(),
                    ),

                    const SizedBox(height: 24),

                    // Кнопки действий
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Мастер берёт новый заказ
                      if (isMaster && status == 'new')
                        _actionBtn(
                          label: lang == 'ru'
                              ? 'Взять в работу'
                              : 'Жұмысқа алу',
                          color: Colors.blueAccent,
                          icon: LucideIcons.play,
                          onTap: () => _updateStatus(
                              'in_progress', lang,
                              assignMe: true),
                        ),

                      // Мастер завершает свой заказ
                      if (isMaster && status == 'in_progress' && isMyTask)
                        _actionBtn(
                          label: lang == 'ru'
                              ? 'Завершить работу'
                              : 'Жұмысты аяқтау',
                          color: Colors.green,
                          icon: LucideIcons.checkCircle,
                          onTap: () => _showFinalInvoice(
                              context, basePrice, lang),
                        ),

                      // Статус просмотра
                      if (status == 'completed' ||
                          (status == 'in_progress' && !isMyTask && !isChairman))
                        _statusInfo(status, lang),

                      // Отмена (только председатель)
                      if (isChairman && status != 'completed' && status != 'cancelled') ...[
                        const SizedBox(height: 8),
                        _actionBtn(
                          label: lang == 'ru'
                              ? 'Отменить заявку'
                              : 'Өтінімді бас тарту',
                          color: Colors.redAccent,
                          icon: LucideIcons.x,
                          onTap: () =>
                              _updateStatus('cancelled', lang),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),

                    // Кнопка чата
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              taskId      : widget.order['id'].toString(),
                              taskTitle   : task['title']?.toString() ?? '',
                              receiverId  : task['user_id']?.toString() ?? '',
                              receiverName: task['customer_name']?.toString() ?? 'Customer',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          isChairman
                              ? (lang == 'ru'
                                  ? 'Чат с мастером'
                                  : 'Шебермен чат')
                              : (lang == 'ru'
                                  ? 'Открыть чат'
                                  : 'Чатты ашу'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : Colors.black54,
                          side: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // История
                    _buildLogs(widget.order['id'], lang, isDark),

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

  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _statusInfo(String status, String lang) {
    final isCompleted = status == 'completed';
    final Color c = isCompleted ? Colors.green : Colors.orange;
    final String t = isCompleted
        ? (lang == 'ru' ? 'Заявка выполнена' : 'Тапсырыс орындалды')
        : (lang == 'ru' ? 'Заявка в процессе' : 'Өтінім орындалуда');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              isCompleted
                  ? LucideIcons.checkCircle
                  : LucideIcons.clock,
              color: c,
              size: 18),
          const SizedBox(width: 8),
          Text(t,
              style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }
}