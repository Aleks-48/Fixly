import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;       // Число от 0.0 до 5.0
  final double size;         // Размер иконок
  final int? reviewCount;    // Опционально: количество отзывов в скобках
  final Color color;         // Цвет звезд (по умолчанию золотой)

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.reviewCount,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Цикл отрисовки 5 звезд
        Row(
          children: List.generate(5, (index) {
            // Определяем тип иконки для каждой позиции
            IconData iconData;
            if (rating >= index + 1) {
              iconData = Icons.star; // Полная звезда
            } else if (rating >= index + 0.5) {
              iconData = Icons.star_half; // Половинка
            } else {
              iconData = Icons.star_border; // Пустая
            }

            return Icon(
              iconData,
              color: color,
              size: size,
            );
          }),
        ),
        
        // Если передано количество отзывов, показываем их рядом
        if (reviewCount != null) ...[
          const SizedBox(width: 8),
          Text(
            "($reviewCount)",
            style: TextStyle(
              fontSize: size * 0.8,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}