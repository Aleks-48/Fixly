// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart'; 

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
  static const double minTapTarget = 48;
  static const double primaryTapTarget = 56;
  static const double iconTapSize = 28;
}

class AppTypography {
  AppTypography._();
  static const double screenTitle = 21;
  static const double sectionTitle = 18;
  static const double cardTitle = 16;
  static const double body = 16;
  static const double bodyLarge = 18;
  static const double caption = 13;
  static const double button = 17;

  static const FontWeight regular = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}

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

  final Color background;     
  final Color surface;        
  final Color surfaceVariant; 
  final Color card;           
  final Color cardBorder;     
  final Color primary;        
  final Color primaryLight;   
  final Color secondary;      
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color shadow;
  final Color gradientStart;  
  final Color gradientEnd;
  final bool isDark;

  // ── ТЁМНАЯ ПАЛИТРА (Глубокий вечерний шалфей и мягкое золото) ──
  static const dark = AppColors._(
    background:     Color(0xFF191C1A), // Приглушенный темный шалфейно-серый
    surface:        Color(0xFF1E221F), 
    surfaceVariant: Color(0xFF282D29), 
    card:           Color(0xFF212622), 
    cardBorder:     Color(0xFF323A34), 
    
    primary:        Color(0xFF8A9A5B), // Шалфей (Sage) — мягкий зеленый акцент
    primaryLight:   Color(0xFFA1B273), 
    secondary:      Color(0xFFE9C46A), // Песочное золото (Sand/Ochre) вместо фиолетового
    
    textPrimary:    Color(0xFFFFFFFF),
    textSecondary:  Color(0xFFC4CBC6), 
    textTertiary:   Color(0xFF9AA29D), 
    divider:        Color(0xFF2A312B), 
    success:        Color(0xFF52B788),
    warning:        Color(0xFFF4A261),
    danger:         Color(0xFFE76F51),
    info:           Color(0xFF7AA095), 
    shadow:         Color(0x66000000),
    
    gradientStart:  Color(0xFF8A9A5B), 
    gradientEnd:    Color(0xFF4E5B2F), 
    isDark:         true,
  );

  // ── СВЕТЛАЯ ПАЛИТРА (Натуральный мягкий песок и благородный шалфей) ──
  static const light = AppColors._(
    background:     Color(0xFFFAF6EE), // Нежный натуральный песок (Sand)
    surface:        Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1EAE0), // Более глубокий песочный тон для полей ввода
    card:           Color(0xFFFFFFFF),
    cardBorder:     Color(0xFFE3DAC3), // Песочно-бежевая кайма карточек
    
    primary:        Color(0xFF6B7A47), // Контрастный зрелый шалфей (для хорошей читаемости пожилыми)
    primaryLight:   Color(0xFF8A9A5B), // Воздушный классический шалфей
    secondary:      Color(0xFFD4A373), // Глубокий теплый песочный акцент вместо фиолетового
    
    textPrimary:    Color(0xFF252C25), // Мягкий хвойно-черный для текста (комфортнее чистого черного)
    textSecondary:  Color(0xFF535D54), 
    textTertiary:   Color(0xFF838D84), 
    divider:        Color(0xFFEAE2D2), 
    success:        Color(0xFF4F772D),
    warning:        Color(0xFFE65F2B),
    danger:         Color(0xFFBC3939),
    info:           Color(0xFF588157), 
    shadow:         Color(0x0A000000),
    
    gradientStart:  Color(0xFF8A9A5B),
    gradientEnd:    Color(0xFF6B7A47),
    isDark:         false,
  );

  static AppColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}

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
        // Перекрываем контейнеры, чтобы системные оверлеи не синели
        primaryContainer: c.surfaceVariant,
        secondaryContainer: c.surfaceVariant,
        outline: c.cardBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
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
        minVerticalPadding: 14,
        iconColor: c.textSecondary,
        titleTextStyle: TextStyle(fontSize: AppTypography.body, color: c.textPrimary),
        subtitleTextStyle: TextStyle(fontSize: AppTypography.caption, color: c.textSecondary),
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(fontSize: AppTypography.caption, color: Colors.white),
      ),
    );
  }
}

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
              minimumSize: const Size(0, AppDimens.primaryTapTarget),
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AppDimens.primaryTapTarget),
            ),
            child: child,
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

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

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.lang = 'ru',
    this.compact = false,
  });

  final String status;
  final String lang; 
  final bool compact;

  static const Map<String, Map<String, String>> _labels = {
    'new':         {'ru': 'Новая',      'kz': 'Жаңа'},
    'in_progress': {'ru': 'В работе',   'kz': 'Жұмыста'},
    'completed':   {'ru': 'Готово',     'kz': 'Дайын'},
    'cancelled':   {'ru': 'Отменено',   'kz': 'Бас тартылды'},
    'active':      {'ru': 'Активно',    'kz': 'Белсенді'},
    'draft':       {'ru': 'Черновик',   'kz': 'Жоба'},
    'closed':      {'ru': 'Закрыто',    'kz': 'Жабық'},
    'archived':    {'ru': 'Архив',      'kz': 'Мұрағат'},
  };

  static Color _colorFor(String status, AppColors c) {
    switch (status) {
      case 'new':
        return c.info;
      case 'in_progress':
        return c.warning;
      case 'completed':
        return c.success;
      case 'cancelled':
        return c.danger;
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
          fontSize: compact ? AppTypography.caption : AppTypography.caption + 1,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

class AppShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Widget? child;

  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.child,
  });
  
  static get cross => null;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    // Исключили синеву из фонов анимации Shimmer
    final baseColor = colors.isDark 
        ? const Color(0xFF282D29) 
        : const Color(0xFFECE5D8); 
        
    final highlightColor = colors.isDark 
        ? const Color(0xFF333A34) 
        : const Color(0xFFFAF6EE); 

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget circular({required double size}) {
    return AppShimmer(
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }

static Widget cardListTile(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          AppShimmer.circular(size: 54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              // Вот здесь была лишняя строка, теперь всё чисто:
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmer(width: 140, height: 16, borderRadius: 6),
                const SizedBox(height: 8),
                const AppShimmer(width: 80, height: 12, borderRadius: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const AppShimmer(width: 40, height: 10, borderRadius: 4),
                    const SizedBox(width: 8),
                    const AppShimmer(width: 60, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget announcementCard(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmer.circular(size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppShimmer(width: double.infinity, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    const AppShimmer(width: 200, height: 12, borderRadius: 4),
                    const SizedBox(height: 6),
                    const AppShimmer(width: 160, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: AppShimmer(width: 90, height: 11, borderRadius: 4),
          ),
        ],
      ),
    );
  }
}