import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Minimal direction indicator: small colored dot + Chinese text.
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

    if (isUp) {
      color = AppTheme.upGreen;
      label = '看涨';
    } else if (isDown) {
      color = AppTheme.downRed;
      label = '看跌';
    } else {
      color = AppTheme.flatGray;
      label = '观望';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: size * 0.4,
          ),
        ),
      ],
    );
  }
}
