import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Semantics(
      label: 'Rating: $rating of $maxRating stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxRating, (i) {
          final filled = i < rating;
          return Semantics(
            label: '${i + 1} star${i == 0 ? '' : 's'}',
            button: true,
            child: GestureDetector(
              onTap: onChanged != null
                  ? () {
                      HapticFeedback.lightImpact();
                      onChanged!(i + 1);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: size,
                  color: filled ? AppColors.conditionFair : AppColors.textTertiary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
