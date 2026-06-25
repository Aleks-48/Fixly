// lib/theme/app_theme.dart
//
// Централизованная дизайн-система Fixly.
// • AppColors  — палитры light/dark, выбираются через AppColors.of(context)
// • AppTheme   — готовые ThemeData для MaterialApp (theme / darkTheme)
// • AppCard    — стандартная кликабельная карточка во всём приложении
// • StatusBadge— бейдж статуса для заявок (tasks) и голосований (proposals)
//
// Тёмная палитра соответствует референсным скриншотам:
// фон #0A0D1A, карточки #141B2D, акцент #2196F3 / #4FC3F7.

import 'package:flutter/material.dart';

// ============================================================
//  ЦВЕТА
// ============================================================
class AppColors {
  const AppColors._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.cardBorder,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.shadow,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isDark,
  });

  final Color background;     // фон экрана
  final Color surface;        // фон AppBar / BottomNav / Drawer
  final Color surfaceVariant; // слегка приподнятая поверхность (вложенные блоки)
  final Color card;           // фон стандартной карточки
  final Color cardBorder;     // обводка карточки
  final Color primary;        // основной акцент (#2196F3)
  final Color primaryLight;   // вторичный акцент / иконки (#4FC3F7)
  final Color secondary;      // доп. акцент (фиолетовый, для AI/премиум блоков)
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color shadow;
  final Color gradientStart;  // для шапок/градиентных кнопок (chairman drawer)
  final Color gradientEnd;
  final bool isDark;

  // ── ТЁМНАЯ ПАЛИТРА ────────────────────────────────────────
  static const dark = AppColors._(
    background:     Color(0xFF0A0D1A),
    surface:        Color(0xFF0F1322),
    surfaceVariant: Color(0xFF1A2036),
    card:           Color(0xFF141B2D),
    cardBorder:     Color(0xFF232B43),
    primary:        Color(0xFF2196F3),
    primaryLight:   Color(0xFF4FC3F7),
    secondary:      Color(0xFF9C6BFF),
    textPrimary:    Color(0xFFFFFFFF),
    textSecondary:  Color(0xFFA0A8C0),
    textTertiary:   Color(0xFF6B7488),
    divider:        Color(0xFF1F2740),
    success:        Color(0xFF34D399),
    warning:        Color(0xFFFBBF24),
    danger:         Color(0xFFF87171),
    info:           Color(0xFF60A5FA),
    shadow:         Color(0x66000000),
    gradientStart:  Color(0xFF2196F3),
    gradientEnd:    Color(0xFF0D47A1),
    isDark:         true,
  );

  // ── СВЕТЛАЯ ПАЛИТРА ───────────────────────────────────────
  static const light = AppColors._(
    background:     Color(0xFFF4F6FB),
    surface:        Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEFF2F8),
    card:           Color(0xFFFFFFFF),
    cardBorder:     Color(0xFFE6E9F2),
    primary:        Color(0xFF2196F3),
    primaryLight:   Color(0xFF03A9F4),
    secondary:      Color(0xFF7C4DFF),
    textPrimary:    Color(0xFF101522),
    textSecondary:  Color(0xFF5A6477),
    textTertiary:   Color(0xFF94A0B8),
    divider:        Color(0xFFE6E9F2),
    success:        Color(0xFF10B981),
    warning:        Color(0xFFF59E0B),
    danger:         Color(0xFFEF4444),
    info:           Color(0xFF3B82F6),
    shadow:         Color(0x14000000),
    gradientStart:  Color(0xFF2196F3),
    gradientEnd:    Color(0xFF1565C0),
    isDark:         false,
  );

  /// Главный способ получить палитру в виджете:
  /// `final c = AppColors.of(context);`
  static AppColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}

// ============================================================
//  THEMEDATA
// ============================================================
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(AppColors.light);
  static ThemeData get darkTheme => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final base = c.isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      brightness: c.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      colorScheme: (c.isDark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
        primary: c.primary,
        secondary: c.secondary,
        surface: c.surface,
        error: c.danger,
        onPrimary: Colors.white,
        onSurface: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardColor: c.card,
      dividerColor: c.divider,
      iconTheme: IconThemeData(color: c.textSecondary),
      textTheme: base.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textTertiary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.primary : c.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.primary : c.textTertiary);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
        labelStyle: TextStyle(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary.withOpacity(0.4)
              : null,
        ),
      ),
    );
  }
}

// ============================================================
//  APPCARD — стандартная кликабельная карточка
// ============================================================
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.borderRadius = 18,
    this.borderColor,
    this.backgroundColor,
    this.elevation = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  /// Лёгкая тень под карточкой (для светлой темы выглядит уместнее).
  final bool elevation;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevation
            ? [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: backgroundColor ?? c.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor ?? c.cardBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  STATUSBADGE — статусы заявок (tasks) и голосований (proposals)
// ============================================================

/// Единый реестр статусов, который понимает и task_model.dart (new /
/// in_progress / completed / cancelled), и voting (active / draft / closed
/// / archived).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.lang = 'ru',
    this.compact = false,
  });

  final String status;
  final String lang; // 'ru' | 'kz'
  final bool compact;

  static const Map<String, Map<String, String>> _labels = {
    // ── задачи (tasks) ──
    'new':         {'ru': 'Новая',      'kz': 'Жаңа'},
    'in_progress': {'ru': 'В работе',   'kz': 'Жұмыста'},
    'completed':   {'ru': 'Готово',     'kz': 'Дайын'},
    'cancelled':   {'ru': 'Отменено',   'kz': 'Бас тартылды'},
    // ── голосования (proposals) ──
    'active':      {'ru': 'Активно',    'kz': 'Белсенді'},
    'draft':       {'ru': 'Черновик',   'kz': 'Жоба'},
    'closed':      {'ru': 'Закрыто',    'kz': 'Жабық'},
    'archived':    {'ru': 'Архив',      'kz': 'Мұрағат'},
  };

  static Color _colorFor(String status, AppColors c) {
    switch (status) {
      // задачи
      case 'new':
        return c.info;
      case 'in_progress':
        return c.warning;
      case 'completed':
        return c.success;
      case 'cancelled':
        return c.danger;
      // голосования
      case 'active':
        return c.success;
      case 'draft':
        return c.warning;
      case 'closed':
        return c.textTertiary;
      case 'archived':
        return c.textTertiary;
      default:
        return c.textTertiary;
    }
  }

  String get _label {
    final short = lang.length >= 2 ? lang.substring(0, 2).toLowerCase() : 'ru';
    return _labels[status]?[short] ?? _labels[status]?['ru'] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _colorFor(status, c);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
