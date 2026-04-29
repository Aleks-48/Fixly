import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _ringPlayer = AudioPlayer(); // Отдельный плеер для звонка

  // Пути к твоим файлам
  static const String clickSound = 'sounds/mixkit-software-interface-start-2574.wav';
  static const String notificationSound = 'sounds/dragon-studio-new-notification-3-398649.mp3';
  static const String callRingSound = 'sounds/11325622-atmosphere-sound-effect-239969.mp3';

  static get instance => null;

  // Воспроизведение звука клика
  static Future<void> playClick() async {
    await _player.stop();
    await _player.play(AssetSource(clickSound));
  }

  // Воспроизведение звука уведомления
  static Future<void> playNotification() async {
    await _player.stop();
    await _player.setVolume(0.5);
    await _player.play(AssetSource(notificationSound));
  }

  // Запуск звука входящего звонка (зацикленный)
  static Future<void> playRinging() async {
    await _ringPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringPlayer.play(AssetSource(callRingSound));
  }

  // Остановка звука звонка
  static Future<void> stopRinging() async {
    await _ringPlayer.stop();
  }

  static void stopRingtone() {}

  static void playRingtone() {}
}