import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Refined thin progress bar with gradient fill based on confidence level.
class ConfidenceBar extends StatelessWidget {
  final double confidence;
  final double height;
  final bool showLabel;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.height = 4,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = confidence.clamp(0.0, 1.0);

    // Gradient: blue (low) -> green (high)
    final fillColor = Color.lerp(
      AppTheme.primary,
      AppTheme.upGreen,
      clamped,
    )!;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: clamped,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        fillColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '${(clamped * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
