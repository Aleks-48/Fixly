// lib/screens/task_details_page.dart

import 'package:flutter/material.dart';
import 'package:fixly_app/models/task_model.dart';
import 'package:fixly_app/main.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fixly_app/services/ai_service.dart';
import 'package:fixly_app/theme/app_theme.dart'; // Единая дизайн-система Fixly

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
        final c = AppColors.of(context);
        setState(() {
          currentStatus = newStatus;
          _isUpdating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Статус обновлен" : "Статус жаңартылды"), 
            backgroundColor: c.success,
          ),
        );
        
        if (newStatus == 'completed') {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("КРИТИЧЕСКАЯ ОШИБКА ОБНОВЛЕНИЯ: $e");
      if (mounted) {
        final c = AppColors.of(context);
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLanguage.value == 'ru' ? "Ошибка: $e" : "Қате: $e"), 
            backgroundColor: c.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        String formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(widget.task.createdAt);

        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            title: Text(
              lang == 'ru' ? "Детали заявки" : "Тапсырма мәліметі",
              style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: c.textPrimary),
            actions: [
               if (_isUpdating) 
                 Center(
                   child: Padding(
                     padding: const EdgeInsets.only(right: 16), 
                     child: SizedBox(
                       width: 20, 
                       height: 20, 
                       child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                     ),
                   ),
                 )
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- БЛОК ФОТО ---
                if (widget.task.imageUrl != null && widget.task.imageUrl!.isNotEmpty)
                  _StaggeredEntrance(
                    index: 0,
                    child: Container(
                      width: double.infinity,
                      height: 250,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: c.textPrimary.withOpacity(0.08), 
                            blurRadius: 10, 
                            offset: const Offset(0, 5),
                          )
                        ],
                        image: DecorationImage(
                          image: NetworkImage(widget.task.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                _StaggeredEntrance(
                  index: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(context, currentStatus, lang),
                      Text(
                        formattedDate, 
                        style: TextStyle(color: c.textTertiary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _StaggeredEntrance(
                  index: 2,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.primary.withOpacity(0.12), 
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "${lang == 'ru' ? 'Кв' : 'Пәт'}. ${widget.task.apartment!.isEmpty ? '-' : widget.task.apartment}", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: c.primary, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          widget.task.title.isEmpty ? (lang == 'ru' ? "Без названия" : "Атауы жоқ") : widget.task.title, 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),

                // --- AI СОВЕТНИК ---
                _StaggeredEntrance(
                  index: 3,
                  child: _buildAIAssistant(context, lang),
                ),
                
                const SizedBox(height: 25),

                // --- ОПИСАНИЕ ---
                _StaggeredEntrance(
                  index: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, lang == 'ru' ? "Описание" : "Сипаттама"),
                      Text(
                        widget.task.description.isEmpty ? (lang == 'ru' ? "Описание отсутствует" : "Сипаттамасы жоқ") : widget.task.description, 
                        style: TextStyle(fontSize: 16, height: 1.5, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
                
                _StaggeredEntrance(
                  index: 5,
                  child: Divider(height: 40, color: c.textTertiary.withOpacity(0.15)),
                ),

                // --- КОНТАКТНЫЕ ДАННЫЕ ---
                _StaggeredEntrance(
                  index: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, lang == 'ru' ? "Контактные данные" : "Контакт мәліметтері"),
                      _buildContactCard(context, lang),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- УПРАВЛЕНИЕ СТАТУСОМ ---
                if (widget.role != 'chairman')
                  _StaggeredEntrance(
                    index: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, lang == 'ru' ? "Управление статусом" : "Статусты басқару"),
                        _buildActionButtons(context, lang),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIAssistant(BuildContext context, String lang) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            c.primary.withOpacity(0.08), 
            c.surfaceVariant.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.primary.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang == 'ru' ? "AI Советник" : "AI Көмекші", 
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_aiPlan == null && !_isAiLoading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary, 
                    foregroundColor: Colors.white, 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
              Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
            else
              Text(
                _aiPlan!, 
                style: TextStyle(fontSize: 14, height: 1.5, color: c.textPrimary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, String lang) {
    final c = AppColors.of(context);
    bool hasPhone = widget.task.residentPhone.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.textTertiary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withOpacity(0.02), 
            blurRadius: 8, 
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: c.primary.withOpacity(0.15), 
                child: Icon(Icons.person, color: c.primary),
              ),
              title: Text(
                lang == 'ru' ? "Жилец" : "Тұрғын", 
                style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              subtitle: Text(
                hasPhone ? widget.task.residentPhone : "---", 
                style: TextStyle(color: c.textTertiary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary.withOpacity(0.12), 
                      foregroundColor: c.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: hasPhone ? _makeCall : null,
                    icon: const Icon(Icons.phone, size: 20),
                    label: Text(lang == 'ru' ? "Позвонить" : "Қоңырау"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), 
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: hasPhone ? () => _sendWhatsApp(lang) : null,
                    icon: const Icon(Icons.message, size: 20),
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

  Widget _sectionTitle(BuildContext context, String title) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(
          fontSize: 13, 
          fontWeight: FontWeight.bold, 
          color: c.textTertiary, 
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status, String lang) {
    final c = AppColors.of(context);
    Color color = status == 'new' 
        ? c.primary 
        : status == 'in_progress' 
            ? c.warning 
            : c.success;

    String text = status == 'new' 
        ? (lang == 'ru' ? "Новая" : "Жаңа") 
        : status == 'in_progress' 
            ? (lang == 'ru' ? "В работе" : "Жұмыста") 
            : (lang == 'ru' ? "Завершено" : "Бітті");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text, 
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String lang) {
    final c = AppColors.of(context);
    return Column(
      children: [
        if (currentStatus == 'new')
          _actionButton(context, lang == 'ru' ? "Принять в работу" : "Жұмысқа алу", c.warning, () => _updateStatus('in_progress')),
        if (currentStatus == 'in_progress')
          _actionButton(context, lang == 'ru' ? "Завершить заявку" : "Тапсырманы аяқтау", c.success, () => _updateStatus('completed')),
        if (currentStatus == 'completed')
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: c.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lang == 'ru' ? "Заявка закрыта" : "Тапсырма жабылды", 
                style: TextStyle(color: c.success, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          foregroundColor: Colors.white, 
          elevation: 0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isUpdating ? null : onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ============================================================
//  _StaggeredEntrance — каскадная анимация появления элементов
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
    begin: const Offset(0, 0.05),
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