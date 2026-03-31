import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Horizontal bar showing confidence level (0-100%).
class ConfidenceBar extends StatelessWidget {
  final double confidence;
  final double height;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.height = 8,
  });

  Color _barColor(double value) {
    if (value >= 0.7) return AppTheme.upGreen;
    if (value >= 0.4) return AppTheme.accent;
    return AppTheme.downRed;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = confidence.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${(clamped * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: _barColor(clamped),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _barColor(clamped),
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
