import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/judgment.dart';

/// WeChat-style minimal judgment card.
class JudgmentCard extends StatelessWidget {
  final Judgment judgment;

  const JudgmentCard({super.key, required this.judgment});

  String _directionEmoji() {
    switch (judgment.direction.toLowerCase()) {
      case 'up':
        return '📈';
      case 'down':
        return '📉';
      default:
        return '➡️';
    }
  }

  String _directionLabel() {
    switch (judgment.direction.toLowerCase()) {
      case 'up':
        return '看涨';
      case 'down':
        return '看跌';
      default:
        return '观望';
    }
  }

  Color _directionDotColor() {
    switch (judgment.direction.toLowerCase()) {
      case 'up':
        return AppTheme.upGreen;
      case 'down':
        return AppTheme.downRed;
      default:
        return AppTheme.flatGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MM/dd HH:mm');

    return InkWell(
      onTap: () {
        if (judgment.symbol != null) {
          context.push('/market/${judgment.symbol}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: emoji icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                _directionEmoji(),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),

            // Middle: market name + one-line reasoning
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        judgment.symbol ?? '未知',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _directionDotColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _directionLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _directionDotColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (judgment.reasoning != null)
                    Text(
                      judgment.reasoning!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat.format(judgment.createdAt.toLocal()),
                    style: const TextStyle(
                      color: AppTheme.flatGray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Right: confidence %
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(judgment.confidenceScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                _buildSettlementDot(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementDot() {
    if (!judgment.isSettled) {
      return const Text('待验证',
          style: TextStyle(color: AppTheme.flatGray, fontSize: 10));
    }
    if (judgment.isCorrect == true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.upGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          const Text('正确',
              style: TextStyle(color: AppTheme.upGreen, fontSize: 10)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppTheme.downRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        const Text('错误',
            style: TextStyle(color: AppTheme.downRed, fontSize: 10)),
      ],
    );
  }
}
