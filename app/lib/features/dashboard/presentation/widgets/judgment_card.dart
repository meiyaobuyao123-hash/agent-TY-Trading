import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/judgment.dart';
import '../../../../shared/widgets/confidence_bar.dart';
import '../../../../shared/widgets/direction_badge.dart';

/// Card displaying a single AI judgment summary.
class JudgmentCard extends StatelessWidget {
  final Judgment judgment;

  const JudgmentCard({super.key, required this.judgment});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MM/dd HH:mm');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (judgment.symbol != null) {
            context.push('/market/${judgment.symbol}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: symbol + direction badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judgment.symbol ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${judgment.confidence} confidence',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DirectionBadge(direction: judgment.direction),
                ],
              ),

              const SizedBox(height: 12),

              // Confidence bar
              ConfidenceBar(confidence: judgment.confidenceScore),

              const SizedBox(height: 12),

              // Reasoning preview
              if (judgment.reasoning != null)
                Text(
                  judgment.reasoning!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

              const SizedBox(height: 8),

              // Footer: timestamp + settlement status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeFormat.format(judgment.createdAt),
                    style: const TextStyle(
                      color: AppTheme.flatGray,
                      fontSize: 11,
                    ),
                  ),
                  _buildSettlementIcon(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementIcon() {
    if (!judgment.isSettled) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, color: AppTheme.flatGray, size: 14),
          SizedBox(width: 4),
          Text('Pending', style: TextStyle(color: AppTheme.flatGray, fontSize: 11)),
        ],
      );
    }
    if (judgment.isCorrect == true) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppTheme.upGreen, size: 14),
          SizedBox(width: 4),
          Text('Correct', style: TextStyle(color: AppTheme.upGreen, fontSize: 11)),
        ],
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cancel, color: AppTheme.downRed, size: 14),
        SizedBox(width: 4),
        Text('Incorrect', style: TextStyle(color: AppTheme.downRed, fontSize: 11)),
      ],
    );
  }
}
