import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final ValueChanged<int>? onChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 28,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: size,
              color: filled ? AppColors.conditionFair : AppColors.textTertiary,
            ),
          ),
        );
      }),
    );
  }
}
