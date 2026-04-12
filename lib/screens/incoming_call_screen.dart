import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fixly_app/main.dart';
import 'package:fixly_app/services/sound_service.dart';
import 'package:fixly_app/screens/call_screen.dart';

// ============================================================================
//  IncomingCallScreen — Экран обработки входящего аудио-звонка
// ============================================================================
//
//  Основные функции данного модуля:
//  1. Визуальное оповещение: Показ имени, аватара и темы заявки (taskId).
//  2. Анимация: Пульсирующий эффект аватара для привлечения внимания.
//  3. Звук: Интеграция с SoundService для цикличного воспроизведения рингтона.
//  4. Таймер: Автоматическое отклонение звонка через 30 секунд бездействия.
//  5. Синхронизация: Обновление статуса записи в таблице 'calls' в Supabase.
//  6. Навигация: Переход в CallScreen (WebRTC/Agora) при принятии вызова.
//
// ============================================================================

class IncomingCallScreen extends StatefulWidget {
  final String callId;        // Уникальный ID звонка в базе данных
  final String callerId;      // UUID звонящего (мастера или клиента)
  final String callerName;    // Имя для отображения
  final String? callerAvatar; // URL изображения профиля
  final String taskId;        // ID задачи, по которой идет звонок
  final String taskTitle;     // Название задачи

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  
  Timer? _timeoutTimer;       // Таймер для автосброса
  bool _isActing = false;     // Флаг блокировки кнопок (предотвращает двойные нажатия)
  Map<String, dynamic>? _callData; // Данные звонка из БД

  // Контроллер анимации для эффекта пульсации
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fetchCallDetails();
    _setupAnimations();
    _startRingAndTimeout();
    _listenToCallStatus();
  }

  /// Настройка анимации пульсации аватара
  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Бесконечное пульсирование

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// Загрузка дополнительных данных о звонке (например, тип звонка - аудио/видео)
  Future<void> _fetchCallDetails() async {
    try {
      final data = await _supabase
          .from('calls')
          .select()
          .eq('id', widget.callId)
          .maybeSingle();
      if (mounted) {
        setState(() => _callData = data);
      }
    } catch (e) {
      debugPrint('IncomingCallScreen: Ошибка загрузки деталей звонка: $e');
    }
  }

  /// Включение рингтона и запуск таймера на 30 секунд
  void _startRingAndTimeout() {
    SoundService.instance.startRinging();

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isActing) {
        debugPrint('IncomingCallScreen: Тайм-аут звонка (30 сек).');
        _declineCall(timeout: true);
      }
    });
  }

  /// Слушаем изменения в таблице calls.
  /// Если вызывающий сбросил звонок (статус 'ended' или 'declined'), закрываем экран.
  void _listenToCallStatus() {
    _supabase
      .channel('public:calls:id=eq.${widget.callId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'calls',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.callId,
        ),
        callback: (payload) {
          final newStatus = payload.newRecord['status'];
          if (newStatus == 'ended' || newStatus == 'declined' || newStatus == 'timeout') {
            if (mounted && !_isActing) {
              debugPrint('IncomingCallScreen: Звонок отменен звонящим (статус: $newStatus).');
              _stopAndClose();
            }
          }
        },
      )
      .subscribe();
  }

  /// Принять звонок
  Future<void> _acceptCall() async {
    if (_isActing) return;
    setState(() => _isActing = true);

    try {
      // Обновляем статус в БД на 'active'
      await _supabase
          .from('calls')
          .update({'status': 'active', 'answered_at': DateTime.now().toIso8601String()})
          .eq('id', widget.callId);

      _cleanup(); // Останавливаем рингтон и таймер

      // Переходим на экран звонка
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              taskId: widget.taskId,
              hasVideo: _callData?['has_video'] == true, 
              userName: '', 
              avatarUrl: '', 
              remoteUserId: '', 
              remoteUserName: '', 
              taskTitle: '', 
              isIncoming: true, // ИСПРАВЛЕНО ЗДЕСЬ: null заменен на true
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('IncomingCallScreen: Ошибка принятия звонка: $e');
      _stopAndClose();
    }
  }

  /// Отклонить звонок (сбрасывается пользователем или по таймауту)
  Future<void> _declineCall({bool timeout = false}) async {
    if (_isActing) return;
    setState(() => _isActing = true);

    try {
      final status = timeout ? 'timeout' : 'declined';
      // Обновляем статус в БД
      await _supabase
          .from('calls')
          .update({'status': status, 'ended_at': DateTime.now().toIso8601String()})
          .eq('id', widget.callId);
    } catch (e) {
      debugPrint('IncomingCallScreen: Ошибка отклонения звонка: $e');
    } finally {
      _stopAndClose();
    }
  }

  /// Остановка сервисов и закрытие экрана
  void _stopAndClose() {
    _cleanup();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Очистка ресурсов (остановка рингтона, таймеров и анимации)
  void _cleanup() {
    _timeoutTimer?.cancel();
    SoundService.instance.stopRinging();
    _supabase.removeAllChannels(); // Отписка от realtime
  }

  @override
  void dispose() {
    _cleanup();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================================
  //                              ВИЗУАЛЬНАЯ ЧАСТЬ (UI)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = appLanguage.value; // 'ru' или 'kk'
    final isVideo = _callData?['has_video'] == true;

    return Scaffold(
      // Темный, слегка прозрачный фон
      backgroundColor: isDark ? const Color(0xFF101012) : const Color(0xFF1A1D21),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Заголовок типа звонка
            Text(
              isVideo 
                ? (lang == 'ru' ? 'Входящий видеозвонок' : 'Кіріс бейнеқоңырау')
                : (lang == 'ru' ? 'Входящий аудиозвонок' : 'Кіріс аудиоқоңырау'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Название задачи
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.taskTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),

            // Аватар звонящего с эффектом пульсации
            ScaleTransition(
              scale: _pulseAnimation,
              child: _buildAvatar(),
            ),
            const SizedBox(height: 30),

            // Имя звонящего
            Text(
              widget.callerName,
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(flex: 2),

            // Панель управления (Отклонить / Принять)
            _buildActionButtons(lang),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  /// Виджет аватара (с заглушкой, если фото нет)
  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(70),
        child: widget.callerAvatar != null && widget.callerAvatar!.isNotEmpty
            ? Image.network(
                widget.callerAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
              )
            : _buildFallbackAvatar(),
      ),
    );
  }

  /// Заглушка аватара
  Widget _buildFallbackAvatar() {
    return Container(
      color: Colors.blueAccent.withOpacity(0.2),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 50, color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Кнопки управления (Принять/Отклонить)
  Widget _buildActionButtons(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка ОТКЛОНИТЬ (Красная)
          _callActionButton(
            icon: LucideIcons.phoneOff,
            label: lang == 'ru' ? 'Отклонить' : 'Қабылдамау',
            color: Colors.redAccent,
            onTap: _isActing ? null : () => _declineCall(timeout: false),
          ),
          
          // Кнопка ПРИНЯТЬ (Зеленая)
          _callActionButton(
            icon: (_callData?['has_video'] == true) ? LucideIcons.video : LucideIcons.phone,
            label: lang == 'ru' ? 'Принять' : 'Қабылдау',
            color: Colors.greenAccent.shade700,
            onTap: _isActing ? null : _acceptCall,
          ),
        ],
      ),
    );
  }

  /// Универсальный виджет круглой кнопки с подписью
  Widget _callActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;
    
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDisabled ? 0.5 : 1.0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.withOpacity(0.2) : color,
                shape: BoxShape.circle,
                boxShadow: isDisabled ? [] : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}