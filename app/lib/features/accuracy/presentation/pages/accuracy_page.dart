import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/accuracy.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/accuracy_provider.dart';

/// Accuracy page — clean stats with bar chart.
class AccuracyPage extends ConsumerWidget {
  const AccuracyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(accuracyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '数据分析',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: statsAsync.when(
        loading: () => const LoadingWidget(message: '加载数据中...'),
        error: (err, _) => AppErrorWidget(
          message: '加载准确率数据失败:\n$err',
          onRetry: () => ref.invalidate(accuracyProvider),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(
              child: Text(
                '暂无数据\n等待判断结算',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          final totalJudgments =
              stats.fold<int>(0, (sum, s) => sum + s.totalJudgments);
          final correctJudgments =
              stats.fold<int>(0, (sum, s) => sum + s.correctJudgments);
          final overallAccuracy = totalJudgments > 0
              ? (correctJudgments / totalJudgments * 100)
              : 0.0;

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(accuracyProvider);
              await ref.read(accuracyProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Big accuracy card
                _BigAccuracyCard(
                  accuracy: overallAccuracy,
                  total: totalJudgments,
                  correct: correctJudgments,
                ),

                const SizedBox(height: 24),

                // Bar chart
                const Text(
                  '各市场准确率',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: _AccuracyBarChart(stats: stats),
                ),

                const SizedBox(height: 24),

                // Stat cards
                const Text(
                  '分项数据',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Per-market type cards
                ...stats.map((s) => _MarketAccuracyCard(stat: s)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BigAccuracyCard extends StatelessWidget {
  final double accuracy;
  final int total;
  final int correct;

  const _BigAccuracyCard({
    required this.accuracy,
    required this.total,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${accuracy.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '共$total次判断，$correct次正确',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyBarChart extends StatelessWidget {
  final List<AccuracyStat> stats;

  const _AccuracyBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _shortenType(stats[index].marketType),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.divider,
              strokeWidth: 0.5,
            ),
          ),
          barGroups: stats.asMap().entries.map((entry) {
            final acc = entry.value.accuracyPct;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: acc,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _shortenType(String type) {
    if (type.length > 6) return '${type.substring(0, 5)}..';
    return type;
  }
}

class _MarketAccuracyCard extends StatelessWidget {
  final AccuracyStat stat;

  const _MarketAccuracyCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stat.marketType,
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
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${stat.correctJudgments}/${stat.totalJudgments}',
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
