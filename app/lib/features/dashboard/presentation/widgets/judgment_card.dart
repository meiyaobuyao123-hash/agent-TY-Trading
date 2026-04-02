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
    final isLow = judgment.isLowConfidence;

    return Opacity(
      opacity: isLow ? 0.5 : 1.0,
      child: InkWell(
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
                        if (judgment.regime != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _parseColor(judgment.regime!.color)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              judgment.regime!.regime,
                              style: TextStyle(
                                fontSize: 9,
                                color: _parseColor(judgment.regime!.color),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        // L3: Show bias intervention badge
                        if (_hasIntervention()) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showInterventionDetail(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '\u26A1 AI已校准',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (isLow) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.flatGray
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '信心不足，仅供参考',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.flatGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
      ),
    );
  }

  /// Check if any bias flag has an active intervention.
  bool _hasIntervention() {
    if (judgment.biasFlags == null) return false;
    return judgment.biasFlags!.any((f) => f.hasIntervention);
  }

  /// Show bottom sheet with intervention details.
  void _showInterventionDetail(BuildContext context) {
    final interventions = judgment.biasFlags
            ?.where((f) => f.hasIntervention)
            .toList() ??
        [];
    if (interventions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '\u26A1 AI偏差校准',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '系统检测到认知偏差并已自动调整置信度，使预测更加客观。',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...interventions.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(
                          color: Color(0xFF2196F3),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.intervention!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppTheme.flatGray;
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
