import 'package:flutter/material.dart';
import 'package:fixly_app/models/task_model.dart';
import 'package:fixly_app/main.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/services/ai_service.dart';

class TaskDetailsPage extends StatefulWidget {
  final TaskModel task;
  final String role;

  const TaskDetailsPage({super.key, required this.task, required this.role});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final supabase = Supabase.instance.client;
  late String currentStatus;
  bool _isUpdating = false;

  String? _aiPlan;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.task.status;
  }

  Future<void> _makeCall() async {
    if (widget.task.residentPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: widget.task.residentPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Ошибка вызова: $e");
    }
  }

  Future<void> _sendWhatsApp(String lang) async {
    if (widget.task.residentPhone.isEmpty) return;
    final phone = widget.task.residentPhone.replaceAll(RegExp(r'\D'), '');
    final message = lang == 'ru' 
        ? "Здравствуйте! Я мастер из Fixly по вашей заявке: ${widget.task.title}"
        : "Сәлеметсіз бе! Мен Fixly шеберімін, сіздің тапсырысыңыз бойынша: ${widget.task.title}";
    
    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Ошибка WhatsApp: $e");
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;
    
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      
      if (newStatus == 'in_progress') {
        updateData['master_id'] = user.id;
      }

      await supabase
          .from('tasks')
          .update(updateData)
          .eq('id', widget.task.id)
          .select();

      if (mounted) {
        setState(() {
          currentStatus = newStatus;
          _isUpdating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Статус обновлен" : "Статус жаңартылды"), 
            backgroundColor: Colors.green,
          ),
        );
        
        if (newStatus == 'completed') {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("КРИТИЧЕСКАЯ ОШИБКА ОБНОВЛЕНИЯ: $e");
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Ошибка: $e" : "Қате: $e"), 
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        String formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(widget.task.createdAt);

        return Scaffold(
          appBar: AppBar(
            title: Text(lang == 'ru' ? "Детали заявки" : "Тапсырма мәліметі"),
            actions: [
               if (_isUpdating) 
                 const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- БЛОК ФОТО (НОВОЕ) ---
                if (widget.task.imageUrl != null && widget.task.imageUrl!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 250,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                      image: DecorationImage(
                        image: NetworkImage(widget.task.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(currentStatus, lang),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(
                        "${lang == 'ru' ? 'Кв' : 'Пәт'}. ${widget.task.apartment!.isEmpty ? '-' : widget.task.apartment}", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        widget.task.title.isEmpty ? (lang == 'ru' ? "Без названия" : "Атауы жоқ") : widget.task.title, 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      )
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),
                // --- AI СОВЕТНИК (АКТУАЛЬНО) ---
                _buildAIAssistant(lang),
                
                const SizedBox(height: 25),
                _sectionTitle(lang == 'ru' ? "Описание" : "Сипаттама"),
                Text(
                  widget.task.description.isEmpty ? (lang == 'ru' ? "Описание отсутствует" : "Сипаттамасы жоқ") : widget.task.description, 
                  style: const TextStyle(fontSize: 16, height: 1.5)
                ),
                
                const Divider(height: 40),

                _sectionTitle(lang == 'ru' ? "Контактные данные" : "Контакт мәліметтері"),
                _buildContactCard(lang),

                const SizedBox(height: 30),
                if (widget.role != 'chairman') ...[
                  _sectionTitle(lang == 'ru' ? "Управление статусом" : "Статусты басқару"),
                  _buildActionButtons(lang),
                ],
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIAssistant(String lang) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [Colors.deepPurple.shade50, Colors.blue.shade50]),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(lang == 'ru' ? "AI Советник" : "AI Көмекші", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_aiPlan == null && !_isAiLoading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    setState(() => _isAiLoading = true);
                    final plan = await AIService.generateActionPlan(widget.task.title, widget.task.description, lang);
                    setState(() { _aiPlan = plan; _isAiLoading = false; });
                  },
                  icon: const Icon(Icons.psychology, size: 20),
                  label: Text(lang == 'ru' ? "Анализировать задачу" : "Тапсырманы талдау"),
                ),
              )
            else if (_isAiLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple))
            else
              Text(_aiPlan!, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String lang) {
    bool hasPhone = widget.task.residentPhone.isNotEmpty;
    return Card(
      elevation: 0,
      color: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
              title: Text(lang == 'ru' ? "Жилец" : "Тұрғын"),
              subtitle: Text(hasPhone ? widget.task.residentPhone : "---"),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: hasPhone ? _makeCall : null,
                    icon: const Icon(Icons.phone),
                    label: Text(lang == 'ru' ? "Позвонить" : "Қоңырау"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                    onPressed: hasPhone ? () => _sendWhatsApp(lang) : null,
                    icon: const Icon(Icons.message),
                    label: const Text("WhatsApp"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildStatusBadge(String status, String lang) {
    Color color = status == 'new' ? Colors.blue : status == 'in_progress' ? Colors.orange : Colors.green;
    String text = status == 'new' ? (lang == 'ru' ? "Новая" : "Жаңа") : status == 'in_progress' ? (lang == 'ru' ? "В работе" : "Жұмыста") : (lang == 'ru' ? "Завершено" : "Бітті");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons(String lang) {
    return Column(
      children: [
        if (currentStatus == 'new')
          _actionButton(lang == 'ru' ? "Принять в работу" : "Жұмысқа алу", Colors.orange, () => _updateStatus('in_progress')),
        if (currentStatus == 'in_progress')
          _actionButton(lang == 'ru' ? "Завершить заявку" : "Тапсырманы аяқтау", Colors.green, () => _updateStatus('completed')),
        if (currentStatus == 'completed')
          Center(child: Text(lang == 'ru' ? "Заявка закрыта" : "Тапсырма жабылды", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: _isUpdating ? null : onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}