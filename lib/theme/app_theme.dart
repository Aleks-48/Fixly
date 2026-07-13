// lib/theme/app_theme.dart
//
// ============================================================
//  ДИЗАЙН-СИСТЕМА FIXLY v2 — «универсальный, удобный для всех
//  возрастов», в первую очередь для пожилых пользователей
//  (председатели ОСИ часто старшего возраста).
// ============================================================
//
// Что изменилось относительно v1 и почему:
//
// 1. ТИПОГРАФИКА (AppTypography)
//    Материал по умолчанию использует базовый текст 14px — это ниже
//    рекомендуемого комфортного минимума для чтения людьми старшего
//    возраста. Новый минимум по всему приложению — 16px для любого
//    информационного текста, 17-18px для основного текста экранов,
//    20-22px для заголовков. Ничего меньше 13px не используется нигде
//    (даже подписи и таймстемпы).
//
// 2. КОНТРАСТ (AppColors)
//    Раньше "третичный" текст (textTertiary) был среднего серого тона —
//    на тёмном фоне это давало недостаточный контраст для людей со
//    сниженной контрастной чувствительностью зрения (частое возрастное
//    изменение). Третичные тона осветлены (тёмная тема) / затемнены
//    (светлая тема), чтобы читаться увереннее. Имена полей и структура
//    класса СОХРАНЕНЫ без изменений — весь код, который уже использует
//    AppColors.of(context).card / .textSecondary / и т.д., продолжает
//    работать без правок.
//
// 3. РАЗМЕР ЭЛЕМЕНТОВ УПРАВЛЕНИЯ (AppDimens + ThemeData)
//    Минимальная область нажатия по всему приложению — 48dp (минимум
//    Material Design), для основных действий — 56dp. Кнопки, поля
//    ввода, переключатели через ThemeData получили увеличенные отступы
//    и размеры шрифта автоматически — это работает "бесплатно" на всех
//    экранах, которые используют стандартные ElevatedButton/TextButton/
//    TextField/AppBar/BottomNavigationBar без ручного оверрайда стилей.
//
// 4. НОВЫЕ ГОТОВЫЕ КОМПОНЕНТЫ (AppButton, AppIconButton)
//    Для новых экранов/правок — обёртки, которые сразу гарантируют
//    правильный размер шрифта и область нажатия, чтобы не собирать это
//    вручную заново на каждом экране.
//
// ВАЖНО: это ФУНДАМЕНТ дизайн-системы. Экраны, которые задают стили
// вручную (много инлайновых `TextStyle(fontSize: 12)` и т.п. по всему
// проекту) не подхватят эти изменения автоматически — их нужно
// переводить на AppTypography/AppColors по одному. Уже переведены:
// main_wrapper.dart (навигация/шапка/меню), chairman_home_screen.dart
// (KPI/списки), incoming_call_screen.dart и call_screen.dart (звонки),
// masters_list_screen.dart. Остальные экраны — следующий шаг, см. чат.

import 'package:flutter/material.dart';

// ============================================================
//  ОТСТУПЫ И РАЗМЕРЫ (AppDimens)
// ============================================================
/// Единая сетка отступов и минимальных размеров интерактивных
/// элементов. Использовать вместо "магических чисел" в новом коде.
class AppDimens {
  AppDimens._();

  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  /// Минимальная область нажатия (Material Design минимум).
  static const double minTapTarget = 48;

  /// Область нажатия для ключевых/частых действий (кнопки "Далее",
  /// "Сохранить", навигация, кнопки звонка и т.п.) — с запасом больше
  /// минимума, чтобы не промахиваться при треморе рук или на ходу.
  static const double primaryTapTarget = 56;

  /// Минимальный размер отдельно стоящей нажимаемой иконки (не внутри
  /// кнопки с текстом) — иконки помельче трудно и разглядеть, и попасть.
  static const double iconTapSize = 28;
}

// ============================================================
//  ТИПОГРАФИКА (AppTypography)
// ============================================================
/// Именованные текстовые стили с увеличенными относительно стандарта
/// Material размерами. Использовать вместо `TextStyle(fontSize: ...)`
/// россыпью по экрану — так весь текст в приложении единообразно
/// крупный и читаемый, а не "где как получилось".
class AppTypography {
  AppTypography._();

  // Заголовки экранов / AppBar
  static const double screenTitle = 21;
  // Заголовки секций внутри экрана ("Активные голосования" и т.п.)
  static const double sectionTitle = 18;
  // Имя/название карточки (мастер, заявка, объявление)
  static const double cardTitle = 16;
  // Основной текст для чтения (описания, сообщения в чате)
  static const double body = 16;
  // Крупный основной текст (важные суммы, статусы, экран звонка)
  static const double bodyLarge = 18;
  // Подписи, вспомогательный текст — МИНИМУМ во всём приложении.
  // Меньше этого значения текст нигде не используется.
  static const double caption = 13;
  // Текст на кнопках
  static const double button = 17;

  static const FontWeight regular = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}

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
  // ВАЖНО: раньше textTertiary был средне-серым (#6B7488 тёмная тема /
  // #94A0B8 светлая) — недостаточный контраст для второстепенного, но
  // всё же ИНФОРМАТИВНОГО текста (даты, счётчики, статусы). Осветлён/
  // затемнён для уверенного чтения людьми со сниженной контрастной
  // чувствительностью зрения. Используется только для по-настоящему
  // декоративных элементов (неактивные иконки навигации и т.п.), а не
  // для текста, который нужно прочитать.
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
    cardBorder:     Color(0xFF2A3350), // чуть светлее прежнего — карточки виднее друг от друга
    primary:        Color(0xFF2196F3),
    primaryLight:   Color(0xFF4FC3F7),
    secondary:      Color(0xFF9C6BFF),
    textPrimary:    Color(0xFFFFFFFF),
    textSecondary:  Color(0xFFC2C8DC), // светлее прежнего (#A0A8C0) — увереннее читается
    textTertiary:   Color(0xFF9AA3BE), // светлее прежнего (#6B7488) — было слишком тусклым
    divider:        Color(0xFF232C4A),
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
    background:     Color(0xFFFAF8F5), // Мягкий кремово-песочный фон
    surface:        Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF2ECE4), // Чуть темнее песочного
    card:           Color(0xFFFFFFFF),
    cardBorder:     Color(0xFFE6DEC3), // Теплый песочно-серый бордюр
    primary:        Color(0xFF2D6A4F), // Благородный шалфейно-зеленый
    primaryLight:   Color(0xFF40916C), // Чуть более светлый шалфей
    secondary:      Color(0xFF7052FF), // Приглушенный фиолетовый для ИИ
    textPrimary:    Color(0xFF1B2420), // Глубокий хвойно-черный для мягкого контраста
    textSecondary:  Color(0xFF49534E), // Серо-зеленый
    textTertiary:   Color(0xFF7D8782), // Светлый серо-зеленый
    divider:        Color(0xFFEBE6DD), // Очень мягкий разделитель
    success:        Color(0xFF2D6A4F),
    warning:        Color(0xFFD97706),
    danger:         Color(0xFFC53030),
    info:           Color(0xFF1D3557),
    shadow:         Color(0x0F000000),
    gradientStart:  Color(0xFF2D6A4F),
    gradientEnd:    Color(0xFF1B4332),
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
        // Иконки в AppBar (назад, меню, действия) по умолчанию крупнее
        // стандартных 24px — их касаются на каждом экране.
        iconTheme: IconThemeData(color: c.textPrimary, size: 27),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: AppTypography.screenTitle,
          fontWeight: AppTypography.extraBold,
        ),
      ),
      cardColor: c.card,
      dividerColor: c.divider,
      iconTheme: IconThemeData(color: c.textSecondary, size: 26),
      // Базовая типографика приложения — крупнее стандартной Material.
      // Экраны, которые используют Theme.of(context).textTheme (а не
      // жёстко заданный fontSize), подхватят это автоматически.
      textTheme: base.textTheme
          .apply(
            bodyColor: c.textPrimary,
            displayColor: c.textPrimary,
          )
          .copyWith(
            bodyLarge: TextStyle(fontSize: AppTypography.bodyLarge, color: c.textPrimary),
            bodyMedium: TextStyle(fontSize: AppTypography.body, color: c.textPrimary),
            bodySmall: TextStyle(fontSize: AppTypography.caption, color: c.textSecondary),
            titleLarge: TextStyle(
                fontSize: AppTypography.screenTitle,
                fontWeight: AppTypography.extraBold,
                color: c.textPrimary),
            titleMedium: TextStyle(
                fontSize: AppTypography.sectionTitle,
                fontWeight: AppTypography.bold,
                color: c.textPrimary),
            titleSmall: TextStyle(
                fontSize: AppTypography.cardTitle,
                fontWeight: AppTypography.semibold,
                color: c.textPrimary),
            labelLarge: TextStyle(
                fontSize: AppTypography.button, fontWeight: AppTypography.bold),
          ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textTertiary,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
            fontSize: AppTypography.caption + 1, fontWeight: AppTypography.bold),
        unselectedLabelStyle: const TextStyle(
            fontSize: AppTypography.caption + 1, fontWeight: AppTypography.regular),
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 26),
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: AppTypography.caption + 1,
            fontWeight: selected ? AppTypography.bold : AppTypography.regular,
            color: selected ? c.primary : c.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.primary : c.textTertiary, size: 27);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        iconSize: 30,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          // Минимум 56dp высоты — основной интерактивный элемент, должен
          // быть легко нажимаемым для любой моторики рук.
          minimumSize: const Size(0, AppDimens.primaryTapTarget),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(
              fontSize: AppTypography.button, fontWeight: AppTypography.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary.withOpacity(0.6), width: 1.5),
          minimumSize: const Size(0, AppDimens.primaryTapTarget),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(
              fontSize: AppTypography.button, fontWeight: AppTypography.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(0, AppDimens.minTapTarget),
          textStyle: const TextStyle(
              fontSize: AppTypography.body, fontWeight: AppTypography.semibold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: AppTypography.body),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: AppTypography.body),
        // Поля ввода тоже подписи/значения крупнее — это то, что читают
        // и печатают чаще всего (email, пароль, текст заявки).
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
            fontSize: AppTypography.sectionTitle,
            fontWeight: AppTypography.bold,
            color: c.textPrimary),
        contentTextStyle: TextStyle(fontSize: AppTypography.body, color: c.textSecondary),
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
      listTileTheme: ListTileThemeData(
        // Пункты списков/меню по умолчанию выше и с крупнее текстом —
        // это главная точка навигации во многих экранах приложения.
        minVerticalPadding: 14,
        iconColor: c.textSecondary,
        titleTextStyle: TextStyle(fontSize: AppTypography.body, color: c.textPrimary),
        subtitleTextStyle: TextStyle(fontSize: AppTypography.caption, color: c.textSecondary),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(fontSize: AppTypography.caption, color: Colors.white),
      ),
    );
  }
}

// ============================================================
//  APPBUTTON — крупная кнопка с гарантированным размером
// ============================================================
/// Готовая кнопка для новых экранов/правок — 56dp высотой, крупный
/// текст, чёткое отключённое состояние. Использовать вместо сборки
/// ElevatedButton вручную на каждом экране заново.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final btnColor = color ?? c.primary;

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isOutlined ? btnColor : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Text(label),
            ],
          );

    final button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: btnColor,
              side: BorderSide(color: btnColor.withOpacity(0.6), width: 1.5),
              minimumSize: Size(0, AppDimens.primaryTapTarget),
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: Colors.white,
              minimumSize: Size(0, AppDimens.primaryTapTarget),
            ),
            child: child,
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ============================================================
//  APPICONBUTTON — иконка с гарантированной областью нажатия
// ============================================================
/// Обёртка над IconButton с явным минимумом 48x48dp области нажатия и
/// увеличенным размером самой иконки — стандартный IconButton даёт
/// иконку 24px, что мелко для частых действий (позвонить, удалить,
/// открыть меню).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.size = 26,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      constraints: const BoxConstraints(
        minWidth: AppDimens.minTapTarget,
        minHeight: AppDimens.minTapTarget,
      ),
      decoration: backgroundColor != null
          ? BoxDecoration(color: backgroundColor, shape: BoxShape.circle)
          : null,
      child: IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onPressed,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
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
          // Материал: минимальная область нажатия карточки — на весь её
          // размер, но добавляем constraints, чтобы даже совсем короткая
          // карточка (одна строка текста) не была меньше 48dp по высоте.
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppDimens.minTapTarget),
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
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          // Раньше 10/12px — ниже минимума читаемости, принятого в этой
          // дизайн-системе (13px). Статус — важная информация (например,
          // "Критично"/"Отменено"), должен читаться однозначно.
          fontSize: compact ? AppTypography.caption : AppTypography.caption + 1,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}