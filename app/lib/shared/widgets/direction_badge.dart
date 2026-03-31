import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Badge showing market direction: up (green), down (red), flat (gray).
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
    final IconData icon;
    final String label;

    if (isUp) {
      color = AppTheme.upGreen;
      icon = Icons.arrow_upward;
      label = 'UP';
    } else if (isDown) {
      color = AppTheme.downRed;
      icon = Icons.arrow_downward;
      label = 'DOWN';
    } else {
      color = AppTheme.flatGray;
      icon = Icons.remove;
      label = 'FLAT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: size * 0.5),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
