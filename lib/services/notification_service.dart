import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/utils/app_error_handler.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  /// Запрашивает у пользователя права на отправку уведомлений (особенно на iOS)
  static Future<void> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM Permission error: $e');
    }
  }

  /// Настраивает обработчик сообщений, когда приложение открыто (Foreground)
  static void setupForegroundListener(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        final title = message.notification!.title ?? 'Новое уведомление';
        final body = message.notification!.body ?? '';

        // Показываем SnackBar внутри приложения
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2D6A4F), // Акцентный цвет
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  /// Вызывает Edge Function в Supabase, которая рассылает пуши всем жителям `buildingId`
  static Future<void> notifyBuilding({
    required String buildingId,
    required String title,
    required String body,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await AppErrorHandler.withRetry(() => _supabase.functions.invoke(
        'send_push',
        body: {
          'building_id': buildingId,
          'title': title,
          'body': body,
          'data': extraData ?? {},
        },
      ));
    } catch (e) {
      debugPrint('Failed to trigger push notification: $e');
      // Мы не бросаем ошибку дальше, чтобы не блокировать основной флоу (создание голосования и т.д.)
    }
  }
}
