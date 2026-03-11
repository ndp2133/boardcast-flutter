import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

class StarRating extends StatefulWidget {
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
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  int? _tappedIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rating: ${widget.rating} of ${widget.maxRating} stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.maxRating, (i) {
          final filled = i < widget.rating;
          return Semantics(
            label: '${i + 1} star${i == 0 ? '' : 's'}',
            button: true,
            child: GestureDetector(
              onTap: widget.onChanged != null
                  ? () {
                      HapticFeedback.lightImpact();
                      setState(() => _tappedIndex = i);
                      Future.delayed(AppDurations.base, () {
                        if (mounted) setState(() => _tappedIndex = null);
                      });
                      widget.onChanged!(i + 1);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedScale(
                  scale: _tappedIndex == i ? 1.3 : 1.0,
                  duration: AppDurations.base,
                  curve: Curves.elasticOut,
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: widget.size,
                    color: filled ? AppColors.conditionFair : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
