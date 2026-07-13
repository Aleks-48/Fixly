import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fixly_app/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    // Адаптируем цвета Shimmer под тему (включая шалфейно-песочную)
    final baseColor = colors.isDark 
        ? const Color(0xFF1E2640) // Темная тема
        : const Color(0xFFEDE9E1); // Светлая (песочная) тема
        
    final highlightColor = colors.isDark 
        ? const Color(0xFF2A3350)
        : const Color(0xFFFAF8F5);

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

  // Скелетон для круглой иконки или аватара
  static Widget circular({
    required double size,
  }) {
    return AppShimmer(
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }

  // Шаблонный скелетон для карточки списка
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(width: 140, height: 16, borderRadius: 6),
                const SizedBox(height: 8),
                AppShimmer(width: 80, height: 12, borderRadius: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppShimmer(width: 40, height: 10, borderRadius: 4),
                    const SizedBox(width: 8),
                    AppShimmer(width: 60, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Скелетон карточки объявления (иконка + заголовок + текст + дата)
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
                    AppShimmer(width: double.infinity, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    AppShimmer(width: 200, height: 12, borderRadius: 4),
                    const SizedBox(height: 6),
                    AppShimmer(width: 160, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AppShimmer(width: 90, height: 11, borderRadius: 4),
          ),
        ],
      ),
    );
  }
}