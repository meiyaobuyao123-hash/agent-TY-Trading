import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Pill-shaped direction badge with tinted background and icon.
class DirectionBadge extends StatelessWidget {
  final String direction;
  final double size;

  const DirectionBadge({
    super.key,
    required this.direction,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = direction.toLowerCase() == 'up';
    final isDown = direction.toLowerCase() == 'down';

    final Color color;
    final String label;
    final IconData icon;

    if (isUp) {
      color = AppTheme.upGreen;
      label = '看涨';
      icon = Icons.trending_up_rounded;
    } else if (isDown) {
      color = AppTheme.downRed;
      label = '看跌';
      icon = Icons.trending_down_rounded;
    } else {
      color = AppTheme.flatGray;
      label = '观望';
      icon = Icons.trending_flat_rounded;
    }

    final fontSize = (size * 0.38).clamp(10.0, 14.0);
    final iconSize = (size * 0.45).clamp(12.0, 16.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.3,
        vertical: size * 0.12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: size * 0.1),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
