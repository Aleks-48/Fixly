import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sound_service.dart';

class CallScreen extends StatefulWidget {
  final String taskId;
  final bool hasVideo;
  final String userName;
  final String avatarUrl;

  const CallScreen({
    super.key,
    required this.taskId,
    required this.hasVideo,
    required this.userName,
    required this.avatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _jitsiMeet = JitsiMeet();
  final supabase = Supabase.instance.client;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    SoundService.playRinging(); // Запускаем звук вызова
  }

  @override
  void dispose() {
    SoundService.stopRinging(); // Обязательно останавливаем при выходе
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
      },
      conferenceTerminated: (url, error) {
        SoundService.stopRinging();
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
            // Аватарка
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(widget.avatarUrl),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 24),
            // Имя
            Text(
              widget.userName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
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