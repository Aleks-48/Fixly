import 'package:fixly_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sound_service.dart';

class CallScreen extends StatefulWidget {
  final String taskId;
  final bool hasVideo;
  final String userName;
  final String avatarUrl;
  final String remoteUserId;
  final String remoteUserName;
  final String taskTitle;
  final bool isIncoming;
  // ВАЖНО: chat_screen.dart создаёт запись в таблице calls (status:
  // 'ringing') перед открытием этого экрана и передаёт её id сюда, чтобы
  // можно было обновлять статус ('active'/'ended') — так же, как
  // incoming_call_screen.dart делает для входящей стороны. Без этого
  // поля запись в calls навсегда оставалась бы в статусе 'ringing'.
  final String callId;

  const CallScreen({
    super.key,
    required this.taskId,
    required this.hasVideo,
    required this.userName,
    required this.avatarUrl,
    this.remoteUserId = '',
    this.remoteUserName = '',
    this.taskTitle = '',
    this.isIncoming = false,
    this.callId = '',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final _jitsiMeet = JitsiMeet();
  final supabase = Supabase.instance.client;
  bool _isConnecting = false;

  // Пульсирующее кольцо вокруг аватара — тот же визуальный язык, что и
  // на incoming_call_screen.dart (синее свечение + масштабирование),
  // чтобы входящий и исходящий экраны звонка выглядели единым целым,
  // а не двумя разными интерфейсами.
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  late final Animation<double> _pulseAnim = Tween<double>(begin: 1.0, end: 1.12)
      .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    SoundService.playRinging(); // Запускаем звук вызова
  }

  @override
  void dispose() {
    SoundService.stopRinging(); // Обязательно останавливаем при выходе
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startCall() async {
    setState(() => _isConnecting = true);
    final user = supabase.auth.currentUser;

    var options = JitsiMeetConferenceOptions(
      room: "fixly_room_${widget.taskId}",
      configOverrides: {
        "startWithAudioMuted": false,
        "startWithVideoMuted": !widget.hasVideo,
        "subject": widget.hasVideo ? "Видеозвонок" : "Аудиозвонок",
        "prejoinPageEnabled": false,
      },
      featureFlags: {
        "unsecureRoomNameChecksEnabled": true,
        "videoMuteButtonEnabled": true,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: user?.email ?? "Пользователь",
        email: user?.email,
      ),
    );

    var listener = JitsiMeetEventListener(
      conferenceJoined: (url) {
        SoundService.stopRinging();
        if (widget.callId.isNotEmpty) {
          supabase
              .from('calls')
              .update({'status': 'active', 'answered_at': DateTime.now().toIso8601String()})
              .eq('id', widget.callId)
              .then((_) {}, onError: (_) {});
        }
      },
      conferenceTerminated: (url, error) {
        SoundService.stopRinging();
        if (widget.callId.isNotEmpty) {
          supabase
              .from('calls')
              .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
              .eq('id', widget.callId)
              .then((_) {}, onError: (_) {});
        }
        if (mounted) Navigator.pop(context);
      },
    );

    await _jitsiMeet.join(options, listener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), const Color(0xFF1C1C1E)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Аватарка с пульсирующим свечением
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
color: AppColors.of(context).primary.withOpacity(0.35),                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: _buildAvatar(),
              ),
            ),
            const SizedBox(height: 24),
            // Имя
            Text(
              widget.userName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (widget.taskTitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.taskTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _isConnecting ? "Соединение..." : "Готов к вызову",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
            ),
            const Spacer(flex: 3),
            // Панель управления
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.mic_off, Colors.white24, () {}),
                  _buildActionButton(Icons.call, Colors.green, () => _startCall()),
                  _buildActionButton(Icons.call_end, Colors.red, () {
                    SoundService.stopRinging();
                    if (widget.callId.isNotEmpty) {
                      supabase
                          .from('calls')
                          .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
                          .eq('id', widget.callId)
                          .then((_) {}, onError: (_) {});
                    }
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ВАЖНО: раньше здесь был голый `NetworkImage(widget.avatarUrl)` — при
  /// пустой строке (её реально передаёт chat_screen.dart при звонке без
  /// фото) это давало битую иконку/ошибку загрузки изображения на весь
  /// экран звонка. Теперь при пустом URL показываем инициал имени, как
  /// это уже сделано в master_Detail_Page.dart и masters_list_screen.dart.
  Widget _buildAvatar() {
    final hasAvatar = widget.avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white10,
      backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}