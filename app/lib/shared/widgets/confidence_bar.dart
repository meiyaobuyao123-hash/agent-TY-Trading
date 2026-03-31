import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Thin iOS-style progress bar showing confidence level (0-100%).
class ConfidenceBar extends StatelessWidget {
  final double confidence;
  final double height;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = confidence.clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  // Light gray track
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                  // iOS blue fill
                  FractionallySizedBox(
                    widthFactor: clamped,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(clamped * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
