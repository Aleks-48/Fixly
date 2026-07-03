import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _ringPlayer = AudioPlayer(); // Отдельный плеер для звонка

  // Пути к твоим файлам
  static const String clickSound = 'sounds/mixkit-software-interface-start-2574.wav';
  static const String notificationSound = 'sounds/dragon-studio-new-notification-3-398649.mp3';
  static const String callRingSound = 'sounds/11325622-atmosphere-sound-effect-239969.mp3';

  // Раньше тут было `static get instance => null;`. incoming_call_screen.dart
  // вызывает `SoundService.instance.startRinging()` — на null это падало с
  // NoSuchMethodError при каждом входящем звонке (краш сразу в initState()).
  // Метода startRinging() при этом тоже не существовало — был только
  // playRinging(). Теперь instance — это реальный объект-обёртка с
  // методами startRinging()/stopRinging(), которые форвардят на
  // статическую реализацию ниже (её также продолжает использовать
  // call_screen.dart через SoundService.playRinging()/stopRinging()).
  static final SoundServiceInstance instance = SoundServiceInstance._();

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

/// Объектная обёртка над статическими методами SoundService — нужна,
/// потому что в Dart нельзя одновременно иметь static и instance метод
/// с одинаковым именем (stopRinging) в одном классе.
class SoundServiceInstance {
  SoundServiceInstance._();

  Future<void> startRinging() => SoundService.playRinging();
  Future<void> stopRinging() => SoundService.stopRinging();
}