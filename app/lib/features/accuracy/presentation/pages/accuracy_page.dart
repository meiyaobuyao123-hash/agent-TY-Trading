import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/accuracy.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/accuracy_provider.dart';

/// Accuracy page showing overall stats, bar chart by market type, and stat cards.
class AccuracyPage extends ConsumerWidget {
  const AccuracyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(accuracyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accuracy')),
      body: statsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading accuracy...'),
        error: (err, _) => AppErrorWidget(
          message: 'Failed to load accuracy data:\n$err',
          onRetry: () => ref.invalidate(accuracyProvider),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(
              child: Text(
                'No accuracy data yet.\nWaiting for settled judgments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          // Compute overall aggregates
          final totalJudgments =
              stats.fold<int>(0, (sum, s) => sum + s.totalJudgments);
          final correctJudgments =
              stats.fold<int>(0, (sum, s) => sum + s.correctJudgments);
          final overallAccuracy = totalJudgments > 0
              ? (correctJudgments / totalJudgments * 100)
              : 0.0;
          final avgCalibration = stats.isNotEmpty
              ? stats.fold<double>(0, (sum, s) => sum + s.calibrationErr) /
                  stats.length
              : 0.0;

          // Average confidence (use calibration error as proxy if no direct field)
          final avgConfidence = stats
                  .where((s) => s.highConfAccuracy != null)
                  .fold<double>(
                      0,
                      (sum, s) =>
                          sum +
                          (s.highConfAccuracy! +
                                  (s.mediumConfAccuracy ?? 0) +
                                  (s.lowConfAccuracy ?? 0)) /
                              3) /
              (stats
                      .where((s) => s.highConfAccuracy != null)
                      .length
                      .clamp(1, 999));

          return RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () async {
              ref.invalidate(accuracyProvider);
              await ref.read(accuracyProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Big accuracy number
                _BigAccuracyCard(accuracy: overallAccuracy),

                const SizedBox(height: 24),

                // Bar chart by market type
                const Text(
                  'Accuracy by Market Type',
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

                // Stat cards grid
                const Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatCards(
                  totalJudgments: totalJudgments,
                  correctJudgments: correctJudgments,
                  avgConfidence: avgConfidence,
                  calibrationErr: avgCalibration,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCards({
    required int totalJudgments,
    required int correctJudgments,
    required double avgConfidence,
    required double calibrationErr,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'Total Judgments',
          value: totalJudgments.toString(),
          icon: Icons.gavel,
        ),
        _StatCard(
          label: 'Correct',
          value: correctJudgments.toString(),
          icon: Icons.check_circle_outline,
          valueColor: AppTheme.upGreen,
        ),
        _StatCard(
          label: 'Avg Confidence',
          value: '${avgConfidence.toStringAsFixed(1)}%',
          icon: Icons.speed,
        ),
        _StatCard(
          label: 'Calibration Error',
          value: '${calibrationErr.toStringAsFixed(2)}%',
          icon: Icons.tune,
          valueColor: calibrationErr < 5 ? AppTheme.upGreen : AppTheme.downRed,
        ),
      ],
    );
  }
}

class _BigAccuracyCard extends StatelessWidget {
  final double accuracy;

  const _BigAccuracyCard({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final color = accuracy >= 60
        ? AppTheme.upGreen
        : accuracy >= 40
            ? AppTheme.accent
            : AppTheme.downRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            const Text(
              'Overall Accuracy',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyBarChart extends StatelessWidget {
  final List<AccuracyStat> stats;

  const _AccuracyBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                color: AppTheme.cardBorder,
                strokeWidth: 1,
              ),
            ),
            barGroups: stats.asMap().entries.map((entry) {
              final acc = entry.value.accuracyPct;
              final color = acc >= 60
                  ? AppTheme.upGreen
                  : acc >= 40
                      ? AppTheme.accent
                      : AppTheme.downRed;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: acc,
                    color: color,
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _shortenType(String type) {
    if (type.length > 6) return '${type.substring(0, 5)}..';
    return type;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accent, size: 20),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
