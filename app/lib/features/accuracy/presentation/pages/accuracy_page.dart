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

/// Accuracy / Evolution page — reorganized into 3 tabs (R13).
class AccuracyPage extends ConsumerStatefulWidget {
  const AccuracyPage({super.key});

  @override
  ConsumerState<AccuracyPage> createState() => _AccuracyPageState();
}

class _AccuracyPageState extends ConsumerState<AccuracyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _typeLabels = {
    'crypto': '加密货币',
    'cn-equities': 'A股',
    'us-equities': '美股',
    'hk-equities': '港股',
    'jp-equities': '日股',
    'eu-equities': '欧股',
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(accuracyProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
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

    return Column(
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
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
        ),
        const SizedBox(height: 12),
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            dividerHeight: 0,
            tabs: const [
              Tab(text: '概览'),
              Tab(text: '详细'),
              Tab(text: '进化'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(ref, stats),
              _buildDetailTab(ref, stats),
              _buildEvolutionTab(ref),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // Tab 1: 概览 — Accuracy ring + trend + sentiment
  // ═══════════════════════════════════════════════
  Widget _buildOverviewTab(WidgetRef ref, List<AccuracyStat> stats) {
    final totalJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.totalJudgments);
    final correctJudgments =
        stats.fold<int>(0, (sum, s) => sum + s.correctJudgments);
    final overallAccuracy =
        totalJudgments > 0 ? (correctJudgments / totalJudgments * 100) : 0.0;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(accuracyProvider);
        ref.invalidate(accuracyHistoryProvider);
        ref.invalidate(brierScoreProvider);
        await ref.read(accuracyProvider.future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已更新'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
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

          const SizedBox(height: 24),

          // Brier score section (R13)
          _BrierScoreSection(),

          const SizedBox(height: 24),

          // Accuracy trend chart
          _AccuracyTrendSection(),

          const SizedBox(height: 24),

          // Market sentiment
          _buildMarketSentimentSection(ref),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMarketSentimentSection(WidgetRef ref) {
    final overviewAsync = ref.watch(overviewStatsForEvolutionProvider);

    return overviewAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final breadth = data['market_breadth'] as Map<String, dynamic>?;
        if (breadth == null) return const SizedBox.shrink();

        final upCount = breadth['up_count'] as int? ?? 0;
        final downCount = breadth['down_count'] as int? ?? 0;
        final flatCount = breadth['flat_count'] as int? ?? 0;
        final mood = breadth['mood'] as String? ?? '中性';

        Color moodColor;
        if (mood == '贪婪') {
          moodColor = AppTheme.upGreen;
        } else if (mood == '恐慌') {
          moodColor = AppTheme.downRed;
        } else {
          moodColor = const Color(0xFFFFCC00);
        }

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
                      color: moodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.sentiment_satisfied_rounded,
                        size: 16, color: moodColor),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '市场情绪',
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
                      color: moodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mood,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: moodColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Sentiment bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (upCount > 0)
                        Flexible(
                          flex: upCount,
                          child: Container(color: AppTheme.upGreen),
                        ),
                      if (flatCount > 0)
                        Flexible(
                          flex: flatCount,
                          child: Container(
                              color: const Color(0xFFFFCC00)),
                        ),
                      if (downCount > 0)
                        Flexible(
                          flex: downCount,
                          child: Container(color: AppTheme.downRed),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '上涨 $upCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.upGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '平盘 $flatCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFCC00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '下跌 $downCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.downRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // Tab 2: 详细 — Market type breakdown + model perf
  // ═══════════════════════════════════════════════
  Widget _buildDetailTab(WidgetRef ref, List<AccuracyStat> stats) {
    final sortedByAccuracy = List<AccuracyStat>.from(stats)
      ..sort((a, b) => b.accuracyPct.compareTo(a.accuracyPct));

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(accuracyProvider);
        await ref.read(accuracyProvider.future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已更新'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Model performance section
          _buildModelPerformanceSection(stats),

          const SizedBox(height: 24),

          // Market type preference section
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

  // ═══════════════════════════════════════════════
  // Tab 3: 进化 — Timeline + Learning Rate + Genome + heatmap + bias
  // ═══════════════════════════════════════════════
  Widget _buildEvolutionTab(WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(genomeStatusProvider);
        ref.invalidate(accuracyByHourProvider);
        ref.invalidate(biasReportProvider);
        ref.invalidate(metaInsightsProvider);
        ref.invalidate(evolutionTimelineProvider);
        ref.invalidate(leaderboardProvider);
        ref.invalidate(calibrationChartProvider);
        await ref.read(genomeStatusProvider.future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已更新'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Evolution Timeline
          _EvolutionTimelineSection(),

          const SizedBox(height: 24),

          // AI Learning Rate
          _LearningRateSection(),

          const SizedBox(height: 24),

          // Leaderboard — top/bottom markets
          const _LeaderboardSection(),

          const SizedBox(height: 24),

          // Calibration chart — predicted vs actual
          const _CalibrationChartSection(),

          const SizedBox(height: 24),

          // Meta-learning self-awareness section (L4)
          _MetaInsightsSection(),

          const SizedBox(height: 24),

          // Strategy genome section
          _GenomeStatusSection(),

          const SizedBox(height: 24),

          // Accuracy by hour heatmap
          _AccuracyByHourSection(),

          const SizedBox(height: 24),

          // Bias report
          _BiasReportSection(),

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
              color: AppTheme.backgroundOf(context),
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
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isTop
                          ? const Color(0xFFFFF3CD)
                          : AppTheme.backgroundOf(context),
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

// ═══════════════════════════════════════════════
// Brier Score Section (R13)
// ═══════════════════════════════════════════════
class _BrierScoreSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(brierScoreProvider);

    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final brierScore = (data['brier_score'] as num?)?.toDouble();
        if (brierScore == null) return const SizedBox.shrink();

        final brierByType =
            (data['brier_by_type'] as List<dynamic>?) ?? [];

        // Determine quality
        String qualityLabel;
        Color qualityColor;
        if (brierScore < 0.15) {
          qualityLabel = '优秀';
          qualityColor = AppTheme.upGreen;
        } else if (brierScore < 0.25) {
          qualityLabel = '良好';
          qualityColor = const Color(0xFFFFCC00);
        } else {
          qualityLabel = '待提升';
          qualityColor = AppTheme.downRed;
        }

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
                      color: qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.speed_rounded,
                        size: 16, color: qualityColor),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Brier分数',
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
                      color: qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      qualityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: qualityColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Score display
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    brierScore.toStringAsFixed(4),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: qualityColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      '(越低越好)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Brier分数衡量预测概率的精准度。0=完美预测，0.25=随机猜测。当前${brierScore.toStringAsFixed(2)}，${brierScore < 0.25 ? "优于随机" : "需要改进"}。分数越低说明AI对涨跌概率的判断越准确。',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // By-type breakdown
              if (brierByType.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...brierByType.map((bt) {
                  final mt = bt['market_type'] as String? ?? '';
                  final score =
                      (bt['brier_score'] as num?)?.toDouble() ?? 0.0;
                  final count = bt['count'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            mt,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          score.toStringAsFixed(4),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: score < 0.15
                                ? AppTheme.upGreen
                                : score < 0.25
                                    ? const Color(0xFFFFCC00)
                                    : AppTheme.downRed,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($count次)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
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

    final trackPaint = Paint()
      ..color = const Color(0xFFF2F2F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

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
        -math.pi / 2,
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

/// Accuracy trend line chart section.
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

/// Evolution Timeline section (进化时间线).
class _EvolutionTimelineSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(evolutionTimelineProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '进化时间线',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          timelineAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => const Text(
              '加载失败',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            data: (milestones) {
              if (milestones.isEmpty) {
                return const Text(
                  '暂无里程碑数据',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < milestones.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline dot + line
                        SizedBox(
                          width: 24,
                          child: Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: i == milestones.length - 1
                                      ? AppTheme.primary
                                      : AppTheme.divider,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              if (i < milestones.length - 1)
                                Container(
                                  width: 2,
                                  height: 36,
                                  color: AppTheme.divider,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Day ${milestones[i]['day']}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        milestones[i]['label'] as String? ??
                                            '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  milestones[i]['detail'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// AI Learning Rate section.
class _LearningRateSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(metaInsightsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 学习速率',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          metaAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => const Text(
              '加载失败',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            data: (data) {
              final rates = (data['learning_rates'] as List<dynamic>?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              if (rates.isEmpty) {
                return const Text(
                  '暂无学习数据，需要更多已结算判断。',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                );
              }
              return Column(
                children: rates.map((lr) {
                  final status = lr['status'] as String? ?? 'stable';
                  final label = lr['label'] as String? ?? '';
                  final marketType = lr['market_type'] as String? ?? '';
                  final rate = (lr['learning_rate'] as num?)?.toDouble() ?? 0;
                  final firstAcc = (lr['first_half_accuracy'] as num?)?.toDouble() ?? 0;
                  final secondAcc = (lr['second_half_accuracy'] as num?)?.toDouble() ?? 0;

                  final statusColor = switch (status) {
                    'improving' => const Color(0xFF4CAF50),
                    'declining' => const Color(0xFFEF5350),
                    _ => AppTheme.flatGray,
                  };
                  final statusIcon = switch (status) {
                    'improving' => Icons.trending_up_rounded,
                    'declining' => Icons.trending_down_rounded,
                    _ => Icons.trending_flat_rounded,
                  };

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 18, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                marketType,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '$label  (${firstAcc.toStringAsFixed(1)}% -> ${secondAcc.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${rate >= 0 ? "+" : ""}${rate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bias Report section.
class _BiasReportSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biasAsync = ref.watch(biasReportProvider);

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
                  color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.psychology_alt_rounded,
                    size: 16, color: Color(0xFFFF9800)),
              ),
              const SizedBox(width: 10),
              const Text(
                '认知偏差报告',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI判断中检测到的认知偏差统计，帮助理解AI的局限性。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          biasAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  '加载偏差报告失败',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            data: (report) => _buildBiasContent(report),
          ),
        ],
      ),
    );
  }

  Widget _buildBiasContent(Map<String, dynamic> report) {
    final totalWithBias = report['total_judgments_with_bias'] as int? ?? 0;
    final total = report['total_judgments'] as int? ?? 0;
    final biasRate = report['bias_rate'] as num? ?? 0.0;
    final insight = report['insight'] as String? ?? '';
    final biasTypes = (report['bias_types'] as List<dynamic>?) ?? [];

    if (total == 0) {
      return const Text(
        '暂无数据',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _biasMetric('偏差检出率', '${biasRate.toStringAsFixed(1)}%'),
            const SizedBox(width: 20),
            _biasMetric('有偏差判断', '$totalWithBias/$total'),
          ],
        ),
        const SizedBox(height: 14),
        ...biasTypes.map((bt) {
          final label = bt['label'] as String? ?? '';
          final count = bt['count'] as int? ?? 0;
          final pct = bt['pct_of_judgments'] as num? ?? 0;
          final accBiased = bt['accuracy_when_biased'] as num?;
          final accUnbiased = bt['accuracy_when_unbiased'] as num?;
          final biasIcon = _biasIcon(bt['type'] as String? ?? '');

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(biasIcon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count次 (${pct.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (accBiased != null || accUnbiased != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (accBiased != null) ...[
                          Text(
                            '有偏差: ${accBiased.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: accBiased < 40
                                  ? AppTheme.downRed
                                  : AppTheme.textSecondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (accUnbiased != null)
                          Text(
                            '无偏差: ${accUnbiased.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        if (insight.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: Color(0xFFFF9800)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _biasMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _biasIcon(String type) {
    switch (type) {
      case 'momentum':
        return '\u26A0\uFE0F';
      case 'consensus':
        return '\uD83D\uDC65';
      case 'anchoring':
        return '\u2693';
      default:
        return '\u26A0\uFE0F';
    }
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
        color: AppTheme.backgroundOf(context),
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

/// Accuracy by Hour heatmap section.
class _AccuracyByHourSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(accuracyByHourProvider);

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
                  color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.schedule_rounded,
                    size: 16, color: Color(0xFF2196F3)),
              ),
              const SizedBox(width: 10),
              const Text(
                '时段准确率',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI在不同时段(UTC)的预测准确率，揭示最佳预测窗口。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          dataAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox(
              height: 60,
              child: Center(
                child: Text('加载时段数据失败',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ),
            data: (data) => _buildHeatmap(data),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>?) ?? [];
    final insight = data['insight'] as String? ?? '';

    if (items.isEmpty) {
      return const Text('暂无时段数据',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(24, (h) {
            final item = items.firstWhere(
              (i) => (i['hour'] as int) == h,
              orElse: () => {'hour': h, 'total': 0, 'accuracy_pct': 0.0},
            );
            final total = item['total'] as int? ?? 0;
            final pct = (item['accuracy_pct'] as num?)?.toDouble() ?? 0.0;

            Color cellColor;
            if (total == 0) {
              cellColor = const Color(0xFFF2F2F7);
            } else if (pct >= 60) {
              cellColor = AppTheme.upGreen.withValues(
                  alpha: 0.2 + (pct - 60) / 40 * 0.6);
            } else if (pct >= 40) {
              cellColor = const Color(0xFFFFCC00).withValues(alpha: 0.3);
            } else {
              cellColor = AppTheme.downRed.withValues(
                  alpha: 0.2 + (40 - pct) / 40 * 0.4);
            }

            return Tooltip(
              message: total > 0
                  ? '$h:00 UTC  准确率${pct.toStringAsFixed(0)}% ($total次)'
                  : '$h:00 UTC  无数据',
              child: Container(
                width: 42,
                height: 32,
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${h}h',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        if (insight.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: Color(0xFF2196F3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Strategy Genome Status section.
class _MetaInsightsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(metaInsightsProvider);

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
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.psychology_rounded,
                    size: 16, color: Color(0xFF9C27B0)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI自我认知',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          metaAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const Text(
              '暂无元学习数据',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            data: (data) => _buildMetaContent(data),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaContent(Map<String, dynamic> data) {
    final insightText = data['meta_insight_text'] as String? ?? '';
    final recommendations = (data['recommendations'] as List<dynamic>?) ?? [];
    final totalAnalyzed = data['total_analyzed'] as int? ?? 0;
    final byRegime = (data['by_regime'] as Map<String, dynamic>?) ?? {};

    if (totalAnalyzed == 0) {
      return const Text(
        '暂无已结算判断，元学习需要更多数据。',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta insight summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            insightText,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ),

        // Regime accuracy table
        if (byRegime.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            '各市场状态准确率',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...byRegime.entries.map((e) {
            final regimeData = e.value as Map<String, dynamic>;
            final total = regimeData['total'] as int? ?? 0;
            final acc = (regimeData['accuracy_pct'] as num?)?.toDouble() ?? 0;
            if (total < 2) return const SizedBox.shrink();
            final barWidth = (acc / 100).clamp(0.0, 1.0);
            final barColor = acc >= 60
                ? const Color(0xFF22C55E)
                : acc >= 40
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: barWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${acc.toStringAsFixed(1)}% ($total)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // Recommendations
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],

        // Total analyzed count
        const SizedBox(height: 8),
        Text(
          '基于 $totalAnalyzed 个已结算判断的分析',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.flatGray,
          ),
        ),
      ],
    );
  }
}

class _GenomeStatusSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genomeAsync = ref.watch(genomeStatusProvider);

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
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.biotech_rounded,
                    size: 16, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 10),
              const Text(
                '策略基因组',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '三个策略基因组通过自然选择进化。表现最差的定期变异，最优的指导AI判断。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          genomeAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox(
              height: 60,
              child: Center(
                child: Text('加载基因组数据失败',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ),
            data: (data) => _buildGenomeCards(data),
          ),
        ],
      ),
    );
  }

  Widget _buildGenomeCards(Map<String, dynamic> data) {
    final genomes = (data['genomes'] as List<dynamic>?) ?? [];
    final activeGenome = data['active_genome'] as String?;

    if (genomes.isEmpty) {
      return const Text('暂无基因组数据',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }

    return Column(
      children: genomes.map((g) {
        final name = g['name'] as String? ?? '';
        final gen = g['generation'] as int? ?? 1;
        final fitness = (g['fitness'] as num?)?.toDouble() ?? 0.0;
        final total = g['total_judgments'] as int? ?? 0;
        final isActive = name == activeGenome;
        final weights = g['weights'] as Map<String, dynamic>? ?? {};

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4CAF50).withValues(alpha: 0.06)
                : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '当前使用',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _genomeMetric('代数', '$gen'),
                  const SizedBox(width: 16),
                  _genomeMetric(
                      '适应度', '${(fitness * 100).toStringAsFixed(1)}%'),
                  const SizedBox(width: 16),
                  _genomeMetric('判断数', '$total'),
                ],
              ),
              const SizedBox(height: 8),
              _weightBar('动量',
                  (weights['momentum_weight'] as num?)?.toDouble() ?? 0.5),
              _weightBar('逆势',
                  (weights['contrarian_weight'] as num?)?.toDouble() ?? 0.3),
              _weightBar('量能',
                  (weights['volume_weight'] as num?)?.toDouble() ?? 0.4),
              _weightBar('联动',
                  (weights['cross_market_weight'] as num?)?.toDouble() ?? 0.3),
              _weightBar('趋势',
                  (weights['history_weight'] as num?)?.toDouble() ?? 0.4),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _genomeMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ],
    );
  }

  Widget _weightBar(String label, double weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: weight.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF2F2F7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    weight >= 0.7
                        ? AppTheme.primary
                        : weight >= 0.4
                            ? const Color(0xFFFFCC00)
                            : AppTheme.flatGray,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              weight.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════
// Leaderboard Section — top/bottom markets
// ═══════════════════════════════════════════════
class _LeaderboardSection extends ConsumerWidget {
  const _LeaderboardSection();

  static const _typeLabels = {
    'crypto': '加密货币',
    'cn-equities': 'A股',
    'us-equities': '美股',
    'hk-equities': '港股',
    'jp-equities': '日股',
    'eu-equities': '欧股',
    'global-indices': '全球指数',
    'forex': '外汇',
    'commodities': '大宗商品',
    'macro': '宏观指标',
    'etf': 'ETF基金',
    'prediction-markets': '预测市场',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(leaderboardProvider);

    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final topList = (data['top'] as List<dynamic>?) ?? [];
        final bottomList = (data['bottom'] as List<dynamic>?) ?? [];
        if (topList.isEmpty && bottomList.isEmpty) {
          return const SizedBox.shrink();
        }

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
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 16, color: Color(0xFF856404)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '排行榜',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Top 5
              if (topList.isNotEmpty) ...[
                const Text(
                  'AI最擅长的市场',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...topList.take(5).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  final symbol = item['symbol'] as String? ?? '';
                  final pct = (item['accuracy_pct'] as num?)?.toDouble() ?? 0;
                  final total = item['total'] as int? ?? 0;
                  final mt = item['market_type'] as String? ?? '';
                  final mtLabel = _typeLabels[mt] ?? mt;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: i == 0
                                  ? const Color(0xFF856404)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                symbol,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$mtLabel  ($total次结算)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: pct >= 60
                                ? AppTheme.upGreen
                                : pct >= 45
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

              if (topList.isNotEmpty && bottomList.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),

              // Bottom 5
              if (bottomList.isNotEmpty) ...[
                const Text(
                  'AI需改进的市场',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...bottomList.take(5).toList().asMap().entries.map((entry) {
                  final item = entry.value as Map<String, dynamic>;
                  final symbol = item['symbol'] as String? ?? '';
                  final pct = (item['accuracy_pct'] as num?)?.toDouble() ?? 0;
                  final total = item['total'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          child: Icon(Icons.warning_amber_rounded,
                              size: 14, color: AppTheme.downRed),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$symbol ($total次)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.downRed,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════
// Calibration Chart Section — predicted vs actual
// ═══════════════════════════════════════════════
class _CalibrationChartSection extends ConsumerWidget {
  const _CalibrationChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(calibrationChartProvider);

    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final buckets = (data['buckets'] as List<dynamic>?) ?? [];
        if (buckets.isEmpty) return const SizedBox.shrink();

        // Check if we have any data points
        final totalCount = buckets.fold<int>(
            0, (sum, b) => sum + ((b as Map<String, dynamic>)['count'] as int? ?? 0));
        if (totalCount == 0) return const SizedBox.shrink();

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
                    child: const Icon(Icons.ssid_chart_rounded,
                        size: 16, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '置信度校准图',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '对角线=完美校准。AI说70%就应70%命中。',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildCalibrationChart(buckets),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(AppTheme.primary, 'AI校准线'),
                  const SizedBox(width: 16),
                  _legendDot(AppTheme.flatGray, '完美校准'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCalibrationChart(List<dynamic> buckets) {
    // Build spots for actual hit rate
    final actualSpots = <FlSpot>[];
    final bucketLabels = <String>[];

    for (int i = 0; i < buckets.length; i++) {
      final b = buckets[i] as Map<String, dynamic>;
      final predAvg = (b['predicted_avg'] as num?)?.toDouble() ?? 0;
      final actualHit = (b['actual_hit_rate'] as num?)?.toDouble() ?? 0;
      final count = b['count'] as int? ?? 0;
      final label = b['bucket_label'] as String? ?? '';
      bucketLabels.add(label);

      if (count > 0) {
        actualSpots.add(FlSpot(predAvg, actualHit));
      }
    }

    // Perfect calibration diagonal
    final perfectSpots = [
      const FlSpot(10, 10),
      const FlSpot(30, 30),
      const FlSpot(50, 50),
      const FlSpot(70, 70),
      const FlSpot(90, 90),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 100,
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFF2F2F7),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: const Color(0xFFF2F2F7),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: const Text('实际命中率%',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 25 || value == 50 ||
                    value == 75 || value == 100) {
                  return Text('${value.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('预测概率%',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 25 || value == 50 ||
                    value == 75 || value == 100) {
                  return Text('${value.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Color(0xFFE5E5EA)),
            bottom: BorderSide(color: Color(0xFFE5E5EA)),
          ),
        ),
        lineBarsData: [
          // Perfect calibration diagonal (dashed reference)
          LineChartBarData(
            spots: perfectSpots,
            isCurved: false,
            color: AppTheme.flatGray,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            dashArray: [4, 4],
          ),
          // AI calibration line
          if (actualSpots.length >= 2)
            LineChartBarData(
              spots: actualSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.08),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.barIndex == 0) return null; // skip diagonal
                return LineTooltipItem(
                  '预测${spot.x.toStringAsFixed(0)}% 实际${spot.y.toStringAsFixed(0)}%',
                  const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
