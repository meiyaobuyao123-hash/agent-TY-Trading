import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import 'confidence_bar.dart';
import 'direction_badge.dart';

/// Market signal card for the dashboard — shows AI judgment with all key info.
class SignalCard extends StatelessWidget {
  final String symbol;
  final String? name;
  final String price;
  final String? changePct;
  final String direction;
  final double confidence;
  final String? reasoning;
  final String? modelName;
  final int? horizonHours;
  final DateTime? createdAt;
  final bool? isSettled;
  final bool? isCorrect;
  final double? qualityScore;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const SignalCard({
    super.key,
    required this.symbol,
    this.name,
    required this.price,
    this.changePct,
    required this.direction,
    required this.confidence,
    this.reasoning,
    this.modelName,
    this.horizonHours,
    this.createdAt,
    this.isSettled,
    this.isCorrect,
    this.qualityScore,
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
  });

  /// Strip "[model_name] " prefix from reasoning text.
  static String cleanReasoning(String? text) {
    if (text == null || text.isEmpty) return '';
    // Remove all "[xxx] " prefixes and " | [xxx] " separators
    return text
        .replaceAll(RegExp(r'\[[\w-]+\]\s*'), '')
        .replaceAll(RegExp(r'\s*\|\s*'), '\n\n')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isUp = direction.toLowerCase() == 'up';
    final isDown = direction.toLowerCase() == 'down';
    final changeColor = isUp
        ? AppTheme.upGreen
        : isDown
            ? AppTheme.downRed
            : AppTheme.flatGray;

    final cleanedReasoning = cleanReasoning(reasoning);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: star + symbol + quality + direction badge + help button ──
            Row(
              children: [
                // Star icon
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: isFavorite
                          ? const Color(0xFFFFB800)
                          : AppTheme.divider,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          symbol,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Quality badge
                      if (qualityScore != null && qualityScore! >= 0.7) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.upGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '高质量',
                            style: TextStyle(
                              color: AppTheme.upGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (modelName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            modelName!,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DirectionBadge(direction: direction),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _shareSignal(),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.ios_share_rounded,
                        size: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showFieldExplanation(context),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: price + change % ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 合理价格',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: AppTheme.largeNumber,
                    ),
                  ],
                ),
                if (changePct != null) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: changeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        changePct!,
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Settlement status
                if (isSettled == true) ...[
                  Icon(
                    isCorrect == true
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 20,
                    color:
                        isCorrect == true ? AppTheme.upGreen : AppTheme.downRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCorrect == true ? '正确' : '错误',
                    style: TextStyle(
                      color: isCorrect == true
                          ? AppTheme.upGreen
                          : AppTheme.downRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      horizonHours != null ? '${horizonHours}h 后验证' : '待验证',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 3: AI reasoning summary ──
            if (cleanedReasoning.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cleanedReasoning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── Row 4: confidence bar + time ──
            Row(
              children: [
                const Text(
                  '置信度',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ConfidenceBar(
                    confidence: confidence,
                    height: 4,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MM/dd HH:mm').format(createdAt!.toLocal()),
                    style: const TextStyle(
                      color: AppTheme.flatGray,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareSignal() {
    final directionCn = direction.toLowerCase() == 'up'
        ? '看涨'
        : direction.toLowerCase() == 'down'
            ? '看跌'
            : '观望';
    final confPct = (confidence * 100).toStringAsFixed(0);
    final reasoningSnippet = cleanReasoning(reasoning);
    final snippet = reasoningSnippet.length > 50
        ? '${reasoningSnippet.substring(0, 50)}...'
        : reasoningSnippet;

    final text =
        '天演AI信号 | $symbol $directionCn $confPct% | 合理价格 \$$price | 分析: $snippet';
    Share.share(text);
  }

  void _showFieldExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
              '字段说明',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _explainRow('方向标签', '看涨/看跌/观望',
                'AI 模型对未来价格走势的判断方向。'),
            _explainRow('AI 合理价格', '如 69800.00',
                'AI 模型认为该资产在预测周期内的合理价格估值。'),
            _explainRow('偏差百分比', '如 +1.80%',
                'AI 合理价格与当前市场价格的偏差程度，正值表示被低估，负值表示被高估。'),
            _explainRow('置信度', '0% ~ 100%',
                '多模型共识：3个模型一致=高，2个一致=中，1个或分歧=低。当前仅 DeepSeek 单模型运行。'),
            _explainRow('验证状态', '待验证/正确/错误',
                '预测到期后，系统自动对比实际价格走势来验证判断是否正确。'),
            _explainRow('模型标签', '如 deepseek',
                '做出该判断的 AI 模型名称。'),
            _explainRow('AI 分析', '灰色文本区',
                'AI 模型对当前市场状况的分析推理过程。'),
          ],
        ),
      ),
    );
  }

  Widget _explainRow(String field, String example, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              field,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
