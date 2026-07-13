import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixly_app/utils/app_texts.dart';
import 'package:fixly_app/main.dart';

// ─────────────────────────────────────────────
//  Типы ошибок
// ─────────────────────────────────────────────
enum AppErrorType {
  network,   // нет интернета / таймаут
  auth,      // не авторизован / нет прав
  server,    // ошибка сервера (5xx, Supabase error)
  unknown,   // всё остальное
}

// ─────────────────────────────────────────────
//  Класс-помощник
// ─────────────────────────────────────────────
class AppErrorHandler {
  /// Определяем тип ошибки по объекту исключения
  static AppErrorType classify(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Failed host lookup')) {
      return AppErrorType.network;
    }

    if (error is AuthException) return AppErrorType.auth;

    if (error is PostgrestException) {
      final code = int.tryParse(error.code ?? '') ?? 0;
      if (code >= 500) return AppErrorType.server;
      if (code == 401 || code == 403) return AppErrorType.auth;
      return AppErrorType.server;
    }

    if (error.toString().contains('401') ||
        error.toString().contains('403') ||
        error.toString().contains('JWT')) {
      return AppErrorType.auth;
    }

    return AppErrorType.unknown;
  }

  /// Возвращает локализованное сообщение об ошибке
  static String getMessage(Object error, String lang) {
    final type = classify(error);
    switch (type) {
      case AppErrorType.network:
        return AppTexts.get('error_network', lang);
      case AppErrorType.auth:
        return AppTexts.get('error_auth', lang);
      case AppErrorType.server:
        return AppTexts.get('error_server', lang);
      case AppErrorType.unknown:
        return AppTexts.get('error_unknown', lang);
    }
  }

  /// Показывает красивый адаптивный SnackBar с иконкой
  static void show(
    BuildContext context,
    Object error, {
    /// Колбэк для кнопки «Повторить» — если передан, добавляется action
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final lang = appLanguage.value;
    final type = classify(error);
    final message = getMessage(error, lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color fg, IconData icon) = switch (type) {
      AppErrorType.network => (
          const Color(0xFFFF6B35),
          Colors.white,
          Icons.wifi_off_rounded
        ),
      AppErrorType.auth => (
          const Color(0xFFE63946),
          Colors.white,
          Icons.lock_outline_rounded
        ),
      AppErrorType.server => (
          isDark ? const Color(0xFF2D2D2D) : const Color(0xFF333333),
          Colors.white,
          Icons.cloud_off_rounded
        ),
      AppErrorType.unknown => (
          isDark ? const Color(0xFF2D2D2D) : const Color(0xFF444444),
          Colors.white,
          Icons.error_outline_rounded
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: onRetry != null
              ? SnackBarAction(
                  label: AppTexts.get('retry', lang),
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
  }

  /// Обёртка с retry-логикой: пытается выполнить [action] до [maxAttempts] раз
  /// при сетевых ошибках, с экспоненциальной задержкой между попытками.
  static Future<T> withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        final type = classify(e);

        // Повторяем только при сетевых ошибках
        if (type != AppErrorType.network || attempt >= maxAttempts) {
          rethrow;
        }

        // Экспоненциальная задержка: 1с → 2с → 4с
        await Future.delayed(delay);
        delay = delay * 2;
      }
    }
  }
}
