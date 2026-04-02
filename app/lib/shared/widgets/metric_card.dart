import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable summary metric card — icon circle + large value + title.
/// Supports animated number transitions when value changes.
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // Try to parse value as number for animation
    final numericValue = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
    final isCompound = value.contains('/');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in a tinted rounded-square
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),

          // Animated large bold value
          if (numericValue != null && !isCompound)
            _AnimatedNumber(
              targetValue: numericValue,
              style: AppTheme.mediumNumber,
            )
          else if (isCompound)
            _AnimatedCompoundNumber(
              value: value,
              style: AppTheme.mediumNumber,
            )
          else
            Text(
              value,
              style: AppTheme.mediumNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),

          // Small gray title
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.flatGray,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated integer display that smoothly counts up/down.
class _AnimatedNumber extends StatelessWidget {
  final int targetValue;
  final TextStyle style;

  const _AnimatedNumber({
    required this.targetValue,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '$value',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Animated compound number like "12 / 8" — animate each part.
class _AnimatedCompoundNumber extends StatelessWidget {
  final String value;
  final TextStyle style;

  const _AnimatedCompoundNumber({
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final parts = value.split('/').map((s) => s.trim()).toList();
    if (parts.length != 2) {
      return Text(value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final a = int.tryParse(parts[0].replaceAll(RegExp(r'[^\d]'), ''));
    final b = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), ''));

    if (a == null || b == null) {
      return Text(value, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: a),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) => Text('$val', style: style),
        ),
        Text(' / ', style: style),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: b),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) => Text('$val', style: style),
        ),
      ],
    );
  }
}
