import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sound_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String roomId;
  final String callerName;

  const IncomingCallScreen({super.key, required this.roomId, required this.callerName});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _jitsiMeet = JitsiMeet();

  @override
  void initState() {
    super.initState();
    SoundService.playRinging(); // Звук входящего звонка
  }

  void _acceptCall() async {
    SoundService.stopRinging();
    
    var options = JitsiMeetConferenceOptions(
      room: widget.roomId,
      configOverrides: {
        "startWithAudioMuted": false,
        "startWithVideoMuted": false,
      },
      featureFlags: {"unsecureRoomNameChecksEnabled": true},
    );

    await _jitsiMeet.join(options);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 100, color: Colors.white),
            Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.call_end, color: Colors.red, size: 50), onPressed: () => Navigator.pop(context)),
                IconButton(icon: const Icon(Icons.call, color: Colors.green, size: 50), onPressed: _acceptCall),
              ],
            )
          ],
        ),
      ),
    );
  }
}