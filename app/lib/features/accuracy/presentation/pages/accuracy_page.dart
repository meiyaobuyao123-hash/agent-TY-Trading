import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/accuracy.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/accuracy_provider.dart';

/// Accuracy / Evolution page — Apple-style flat, minimalist, tech-forward UI.
class AccuracyPage extends ConsumerWidget {
  const AccuracyPage({super.key});

  static const _typeLabels = {
    'crypto': '加密货币',
    'cn-equities': 'A股',
    'us-equities': '美股',
    'hk-equities': '港股',
    'global-indices': '全球指数',
    'forex': '外汇',
    'commodities': '大宗商品',
    'macro': '宏观指标',
    'etf': 'ETF基金',
    'prediction-markets': '预测市场',
  };

  String _localizedType(String type) {
    return _typeLabels[type.toLowerCase()] ?? type;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(accuracyProvider);

    return Scaffold(
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const LoadingWidget(message: '加载数据中...'),
          error: (err, _) => AppErrorWidget.fromError(
            error: err,
            onRetry: () => ref.invalidate(accuracyProvider),
          ),
          data: (stats) => _buildContent(context, ref, stats),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<AccuracyStat> stats) {
    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 56,
                color: AppTheme.divider,
              ),
              const SizedBox(height: 16),
              const Text(
                '暂无进化数据',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI判断需要到期后才能验证准确率。首次判断将在4小时后结算。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.totalJudgments);
    final correctJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.correctJudgments);
    final overallAccuracy =
        totalJudgments > 0 ? (correctJudgments / totalJudgments * 100) : 0.0;

    // Sort stats by accuracy for preference ranking
    final sortedByAccuracy = List<AccuracyStat>.from(stats)
      ..sort((a, b) => b.accuracyPct.compareTo(a.accuracyPct));

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(accuracyProvider);
        ref.invalidate(accuracyHistoryProvider);
        await ref.read(accuracyProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Large title
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 12),
            child: Text(
              'AI 进化',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Accuracy explanation
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '准确率反映AI判断的历史正确率。数值越高，说明AI对该市场的理解越深。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Circular progress ring
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _AccuracyRingPainter(
                      percentage: overallAccuracy,
                    ),
                    child: Center(
                      child: Text(
                        '${overallAccuracy.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '共$totalJudgments次判断',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Accuracy trend chart ──
          _AccuracyTrendSection(),

          const SizedBox(height: 24),

          // ── Model performance section ──
          _buildModelPerformanceSection(stats),

          const SizedBox(height: 24),

          // ── Market type preference section ──
          _buildMarketPreferenceSection(sortedByAccuracy),

          const SizedBox(height: 24),

          // Section header
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '分项表现',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Market type cards
          ...stats.map((s) => _MarketAccuracyCard(
                stat: s,
                localizedType: _localizedType(s.marketType),
              )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Model performance section ──
  Widget _buildModelPerformanceSection(List<AccuracyStat> stats) {
    final totalJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.totalJudgments);
    final correctJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.correctJudgments);
    final overallAccuracy =
        totalJudgments > 0 ? (correctJudgments / totalJudgments * 100) : 0.0;

    // Compute high/medium/low confidence averages
    final highConfStats =
        stats.where((s) => s.highConfAccuracy != null).toList();
    final medConfStats =
        stats.where((s) => s.mediumConfAccuracy != null).toList();
    final lowConfStats =
        stats.where((s) => s.lowConfAccuracy != null).toList();

    final highConf = highConfStats.isNotEmpty
        ? highConfStats.fold<double>(
                0, (sum, s) => sum + s.highConfAccuracy!) /
            highConfStats.length
        : null;
    final medConf = medConfStats.isNotEmpty
        ? medConfStats.fold<double>(
                0, (sum, s) => sum + s.mediumConfAccuracy!) /
            medConfStats.length
        : null;
    final lowConf = lowConfStats.isNotEmpty
        ? lowConfStats.fold<double>(
                0, (sum, s) => sum + s.lowConfAccuracy!) /
            lowConfStats.length
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.psychology_rounded,
                    size: 16, color: Color(0xFF8E44AD)),
              ),
              const SizedBox(width: 10),
              const Text(
                '模型表现',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // DeepSeek model card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'DeepSeek',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.upGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '活跃',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.upGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _modelStatRow(
                    '整体准确率', '${overallAccuracy.toStringAsFixed(1)}%'),
                if (highConf != null)
                  _modelStatRow(
                      '高置信度', '${highConf.toStringAsFixed(1)}%'),
                if (medConf != null)
                  _modelStatRow(
                      '中置信度', '${medConf.toStringAsFixed(1)}%'),
                if (lowConf != null)
                  _modelStatRow(
                      '低置信度', '${lowConf.toStringAsFixed(1)}%'),
                _modelStatRow('总判断数', '$totalJudgments'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Market type preference section ──
  Widget _buildMarketPreferenceSection(List<AccuracyStat> sortedStats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                '市场类型偏好',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'AI 在以下市场类型中表现最好',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(sortedStats.length, (i) {
            final s = sortedStats[i];
            final name = _localizedType(s.marketType);
            final isTop = i == 0 && s.accuracyPct > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isTop
                          ? const Color(0xFFFFF3CD)
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTop
                              ? const Color(0xFF856404)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${s.accuracyPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.accuracyPct > 60
                          ? AppTheme.upGreen
                          : s.accuracyPct > 45
                              ? const Color(0xFFFFCC00)
                              : AppTheme.downRed,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Custom painter for the circular accuracy ring.
class _AccuracyRingPainter extends CustomPainter {
  final double percentage;

  _AccuracyRingPainter({required this.percentage});

  Color _ringColor() {
    if (percentage > 70) return AppTheme.upGreen;
    if (percentage > 50) return const Color(0xFFFFCC00);
    return AppTheme.downRed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 10) / 2;

    // Track background
    final trackPaint = Paint()
      ..color = const Color(0xFFF2F2F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    if (percentage > 0) {
      final fillPaint = Paint()
        ..color = _ringColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      final sweepAngle = (percentage / 100) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawArc(
        rect,
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}

/// Accuracy trend line chart section — fetches history from API.
class _AccuracyTrendSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(accuracyHistoryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                '准确率趋势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  '加载趋势数据失败',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            data: (history) {
              if (history.length < 2) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '数据积累中，趋势图将在更多数据后显示',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return _buildTrendChart(history);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<AccuracyHistoryItem> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].accuracyPct));
    }

    final values = history.map((h) => h.accuracyPct).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final padding = range == 0 ? 10.0 : range * 0.2;
    final chartMin = (minVal - padding).clamp(0.0, 100.0);
    final chartMax = (maxVal + padding).clamp(0.0, 100.0);

    // Determine trend
    final isUp = history.last.accuracyPct >= history.first.accuracyPct;
    final lineColor = isUp ? AppTheme.upGreen : AppTheme.downRed;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range == 0 ? 5 : range / 3,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.divider,
                strokeWidth: 0.5,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.flatGray,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: history.length > 6
                    ? (history.length / 4).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= history.length) {
                    return const SizedBox.shrink();
                  }
                  final time = history[idx].calculatedAt.toLocal();
                  return Text(
                    DateFormat('MM/dd').format(time),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.flatGray,
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: chartMin,
          maxY: chartMax,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final time = idx >= 0 && idx < history.length
                      ? DateFormat('MM/dd HH:mm')
                          .format(history[idx].calculatedAt.toLocal())
                      : '';
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)}%\n$time',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketAccuracyCard extends StatelessWidget {
  final AccuracyStat stat;
  final String localizedType;

  const _MarketAccuracyCard({
    required this.stat,
    required this.localizedType,
  });

  Color _barColor() {
    if (stat.accuracyPct > 70) return AppTheme.upGreen;
    if (stat.accuracyPct > 50) return const Color(0xFFFFCC00);
    return AppTheme.downRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + percentage
          Row(
            children: [
              Expanded(
                child: Text(
                  localizedType,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${stat.accuracyPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: stat.accuracyPct / 100,
                backgroundColor: const Color(0xFFF2F2F7),
                valueColor: AlwaysStoppedAnimation<Color>(_barColor()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bottom label
          Text(
            '${stat.correctJudgments}/${stat.totalJudgments} 判断正确',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
