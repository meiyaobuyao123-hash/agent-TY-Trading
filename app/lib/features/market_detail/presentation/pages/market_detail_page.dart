import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/judgment.dart';
import '../../../../shared/models/market_snapshot.dart';
import '../../../../shared/widgets/confidence_bar.dart';
import '../../../../shared/widgets/direction_badge.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'package:go_router/go_router.dart';
import '../../providers/market_detail_provider.dart';

/// Market detail page — Apple-style flat, minimalist, tech-forward.
class MarketDetailPage extends ConsumerWidget {
  final String symbol;

  const MarketDetailPage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(marketDetailProvider(symbol));
    final judgmentsAsync = ref.watch(marketJudgmentsProvider(symbol));

    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      body: marketAsync.when(
        loading: () => const LoadingWidget(message: '加载中...'),
        error: (err, _) => AppErrorWidget.fromError(
          error: err,
          onRetry: () {
            ref.invalidate(marketDetailProvider(symbol));
            ref.invalidate(marketJudgmentsProvider(symbol));
          },
        ),
        data: (market) {
          final snap = market.latestSnapshot;
          final changePct = snap?.changePct;
          final changeColor = changePct != null
              ? (changePct >= 0 ? AppTheme.upGreen : AppTheme.downRed)
              : AppTheme.flatGray;
          final updateTime = snap != null
              ? DateFormat('HH:mm').format(snap.capturedAt.toLocal())
              : '--:--';

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(marketDetailProvider(symbol));
              ref.invalidate(marketJudgmentsProvider(symbol));
              ref.invalidate(marketSnapshotsProvider(symbol));
              await ref.read(marketDetailProvider(symbol).future);
            },
            child: CustomScrollView(
              slivers: [
                // ── Top section: back button + price hero ──
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Market name (small gray)
                                Text(
                                  market.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // HUGE price
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      snap?.price != null
                                          ? _formatPrice(snap!.price!)
                                          : '--',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryOf(context),
                                        letterSpacing: 1.2,
                                        height: 1.0,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Change % pill
                                    if (changePct != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: changeColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: changeColor,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Info pills row
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _infoPill(market.marketType),
                                    _infoPill(market.source),
                                    _infoPill('$updateTime 更新',
                                        icon: Icons.access_time_rounded),
                                    if (market.isActive)
                                      _infoPill('活跃',
                                          color: AppTheme.upGreen),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Section 1: AI最新判断 — direction + confidence + bias ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: judgmentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: LoadingWidget(),
                      ),
                      error: (err, _) => AppErrorWidget(
                        message: '加载判断失败',
                        onRetry: () =>
                            ref.invalidate(marketJudgmentsProvider(symbol)),
                      ),
                      data: (judgments) {
                        if (judgments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty_rounded,
                                    size: 48,
                                    color: AppTheme.divider,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '该市场暂无数据',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'AI将在下次分析周期自动获取数据。',
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Market accuracy stat
                            _buildMarketAccuracy(judgments),
                            const SizedBox(height: 20),
                            // Section 1: AI最新判断
                            _buildAIAnalysisSection(context, judgments.first),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // ── Section 2b: 判断准确率趋势 ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: judgmentsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (judgments) =>
                          _buildAccuracyTrendChart(judgments),
                    ),
                  ),
                ),

                // ── Section 3: 价格走势 — chart ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildPriceChartSection(ref),
                  ),
                ),

                // ── Section 3b: 市场统计 — per-market stats ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildMarketStatsSection(context, ref),
                  ),
                ),

                // ── Section 4: 相关市场 — horizontal scroll ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildRelatedMarketsSection(ref),
                  ),
                ),

                // ── Section 5: 历史判断 — timeline ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: judgmentsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (judgments) {
                        if (judgments.isEmpty) return const SizedBox.shrink();
                        return _buildHistorySection(context, judgments);
                      },
                    ),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Price chart section ──
  Widget _buildPriceChartSection(WidgetRef ref) {
    final snapshotsAsync = ref.watch(marketSnapshotsProvider(symbol));

    return snapshotsAsync.when(
      loading: () => Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (snapshots) {
        // Filter out snapshots with null prices
        final validSnaps =
            snapshots.where((s) => s.price != null).toList();

        if (validSnaps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.show_chart_rounded,
                    size: 32, color: AppTheme.divider),
                SizedBox(height: 8),
                Text(
                  '暂无价格数据',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        if (validSnaps.length < 3) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.hourglass_top_rounded,
                    size: 32, color: AppTheme.divider),
                SizedBox(height: 8),
                Text(
                  '数据积累中',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '需要更多数据点才能显示走势图',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return _PriceChart(snapshots: validSnaps);
      },
    );
  }

  // ── Market stats section ──
  Widget _buildMarketStatsSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(marketStatsProvider(symbol));

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) return const SizedBox.shrink();
        final totalJ = stats['total_judgments'] as int? ?? 0;
        if (totalJ == 0) return const SizedBox.shrink();

        final accuracy = (stats['accuracy_pct'] as num?)?.toDouble() ?? 0.0;
        final avgConf = (stats['avg_confidence'] as num?)?.toDouble() ?? 0.0;
        final streak = stats['streak'] as int? ?? 0;
        final streakType = stats['streak_type'] as String? ?? 'correct';
        final bestRegime = stats['best_regime'] as String?;
        final bestRegimeAcc = (stats['best_regime_accuracy'] as num?)?.toDouble();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColorOf(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '市场统计',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _statItem(
                      '总判断',
                      totalJ.toString(),
                      AppTheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _statItem(
                      '准确率',
                      '${accuracy.toStringAsFixed(1)}%',
                      accuracy > 50
                          ? AppTheme.upGreen
                          : accuracy > 30
                              ? AppTheme.flatGray
                              : AppTheme.downRed,
                    ),
                  ),
                  Expanded(
                    child: _statItem(
                      '平均置信度',
                      '${(avgConf * 100).toStringAsFixed(0)}%',
                      AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statItem(
                      '连续${streakType == "correct" ? "正确" : "错误"}',
                      '${streak.abs()}次',
                      streak > 0 ? AppTheme.upGreen : AppTheme.downRed,
                    ),
                  ),
                  if (bestRegime != null && bestRegimeAcc != null)
                    Expanded(
                      child: _statItem(
                        '最佳行情',
                        '$bestRegime ${bestRegimeAcc.toStringAsFixed(0)}%',
                        AppTheme.primary,
                      ),
                    ),
                  if (bestRegime == null)
                    const Expanded(child: SizedBox.shrink()),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Related markets section ──
  Widget _buildRelatedMarketsSection(WidgetRef ref) {
    final relatedAsync = ref.watch(relatedMarketsProvider(symbol));

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (related) {
        if (related.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_rounded,
                    size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text(
                  '相关市场',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: related.length,
                separatorBuilder: (c, idx) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final r = related[i];
                  final price = r['price'] as num?;
                  final changePct = r['change_pct'] as num?;
                  final sym = r['symbol'] as String? ?? '';
                  final changeColor = changePct != null
                      ? (changePct >= 0 ? AppTheme.upGreen : AppTheme.downRed)
                      : AppTheme.flatGray;

                  return GestureDetector(
                    onTap: () => context.push('/market/$sym'),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sym,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  price != null
                                      ? _formatPrice(price.toDouble())
                                      : '--',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (changePct != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        changeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: changeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Market accuracy stat ──
  Widget _buildMarketAccuracy(List<Judgment> judgments) {
    final settled = judgments.where((j) => j.isSettled).toList();
    if (settled.isEmpty) return const SizedBox.shrink();

    final correct = settled.where((j) => j.isCorrect == true).length;
    final total = settled.length;
    final pct = (correct / total * 100).toStringAsFixed(1);
    final color = correct / total >= 0.6
        ? AppTheme.upGreen
        : correct / total >= 0.45
            ? const Color(0xFFFFCC00)
            : AppTheme.downRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.analytics_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '该市场判断准确率',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$pct% ($correct/$total)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Accuracy trend chart (mini line chart of rolling accuracy) ──
  Widget _buildAccuracyTrendChart(List<Judgment> judgments) {
    // Only show if there are 5+ settled judgments
    final settled = judgments.where((j) => j.isSettled).toList();
    if (settled.length < 5) return const SizedBox.shrink();

    // Compute rolling accuracy (window of 5)
    // settled is already ordered newest first, reverse for chronological
    final chronological = settled.reversed.toList();
    const windowSize = 5;
    final rollingPoints = <FlSpot>[];

    for (int i = windowSize - 1; i < chronological.length; i++) {
      int correct = 0;
      for (int w = i - windowSize + 1; w <= i; w++) {
        if (chronological[w].isCorrect == true) correct++;
      }
      final acc = correct / windowSize * 100;
      rollingPoints.add(FlSpot(
        (i - windowSize + 1).toDouble(),
        acc,
      ));
    }

    if (rollingPoints.length < 2) return const SizedBox.shrink();

    final lastAcc = rollingPoints.last.y;
    final lineColor = lastAcc >= 50 ? AppTheme.upGreen : AppTheme.downRed;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text(
                '判断准确率趋势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lineColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${lastAcc.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: lineColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '基于最近${settled.length}个已验证判断 (滚动窗口$windowSize)',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.divider,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.flatGray,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  // 50% reference line
                  LineChartBarData(
                    spots: [
                      FlSpot(rollingPoints.first.x, 50),
                      FlSpot(rollingPoints.last.x, 50),
                    ],
                    color: AppTheme.flatGray.withValues(alpha: 0.3),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                  // Accuracy trend line
                  LineChartBarData(
                    spots: rollingPoints,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: lineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Analysis section ──
  Widget _buildAIAnalysisSection(BuildContext context, Judgment latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            const Text(
              'AI 分析',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Direction + confidence row
        Row(
          children: [
            DirectionBadge(direction: latest.direction, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI把握度',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 4,
                    child: ConfidenceBar(
                      confidence: latest.confidenceScore,
                      showLabel: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(latest.confidenceScore * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // Bias flags warning cards
        if (latest.biasFlags != null && latest.biasFlags!.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...latest.biasFlags!.map((flag) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: flag.severity == 'high'
                    ? const Color(0xFFFFF3CD)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\u26A0\uFE0F ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flag.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF856404),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flag.detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF856404),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
        // Reasoning card with left blue border — show full text
        if (latest.reasoning != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                left: BorderSide(
                  color: AppTheme.primary,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              latest.reasoning!,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.65,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // "查看全部分析" button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _showFullReasoningSheet(context, latest),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
              ),
              child: const Text(
                '查看全部分析',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // AI analysis explanation
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: AppTheme.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '以上分析由DeepSeek AI模型生成，结合价格走势、成交量和跨市场关联进行综合判断。',
                    style: TextStyle(
                      fontSize: 11,
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

  void _showFullReasoningSheet(BuildContext context, Judgment judgment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundOf(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 完整分析',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Direction badge
                    DirectionBadge(direction: judgment.direction, size: 28),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.divider),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Confidence row
                    Row(
                      children: [
                        const Text(
                          '置信度',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(judgment.confidenceScore * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 4,
                      child: ConfidenceBar(
                        confidence: judgment.confidenceScore,
                        showLabel: false,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Time
                    Row(
                      children: [
                        const Text(
                          '分析时间',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(judgment.createdAt.toLocal()),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Full reasoning
                    const Text(
                      '分析推理',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      judgment.reasoning ?? '无推理数据',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.7,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── History section ──
  Widget _buildHistorySection(BuildContext context, List<Judgment> judgments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded,
                size: 18, color: AppTheme.textSecondary),
            SizedBox(width: 6),
            Text(
              '历史判断',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Timeline list
        ...List.generate(judgments.length, (i) {
          final j = judgments[i];
          final isLast = i == judgments.length - 1;
          final isFirst = i == 0;
          return _TimelineItem(
            judgment: j,
            isLast: isLast,
            isLatest: isFirst,
            onTapReasoning: () => _showFullReasoningSheet(context, j),
          );
        }),
      ],
    );
  }

  Widget _infoPill(String label,
      {Color color = AppTheme.textSecondary, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}

/// Price chart widget using fl_chart.
class _PriceChart extends StatelessWidget {
  final List<MarketSnapshot> snapshots;

  const _PriceChart({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final prices = snapshots.map((s) => s.price!).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final padding = priceRange == 0 ? maxPrice * 0.05 : priceRange * 0.15;

    // Determine trend color
    final isUp = prices.last >= prices.first;
    final lineColor = isUp ? AppTheme.upGreen : AppTheme.downRed;

    final spots = <FlSpot>[];
    for (int i = 0; i < snapshots.length; i++) {
      spots.add(FlSpot(i.toDouble(), snapshots[i].price!));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text(
                '价格走势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _timePeriodLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Adapt chart height based on available width
              final chartHeight = constraints.maxWidth < 350 ? 120.0 : 160.0;
              return SizedBox(
                height: chartHeight,
                child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: priceRange == 0
                      ? 1
                      : priceRange / 4,
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
                      reservedSize: 56,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatChartPrice(value),
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
                      interval: snapshots.length > 6
                          ? (snapshots.length / 4).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= snapshots.length) {
                          return const SizedBox.shrink();
                        }
                        final time = snapshots[idx].capturedAt.toLocal();
                        return Text(
                          DateFormat('HH:mm').format(time),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.flatGray,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minPrice - padding,
                maxY: maxPrice + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: lineColor,
                    barWidth: 2,
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
                        final time = idx >= 0 && idx < snapshots.length
                            ? DateFormat('MM/dd HH:mm')
                                .format(snapshots[idx].capturedAt.toLocal())
                            : '';
                        return LineTooltipItem(
                          '${_formatChartPrice(spot.y)}\n$time',
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
            },
          ),
        ],
      ),
    );
  }

  String _timePeriodLabel() {
    if (snapshots.length < 2) return '数据不足';
    final first = snapshots.first.capturedAt;
    final last = snapshots.last.capturedAt;
    final days = last.difference(first).inDays;
    if (days <= 1) return '近24小时';
    if (days <= 3) return '近3天';
    if (days <= 7) return '近7天';
    if (days <= 14) return '近14天';
    if (days <= 30) return '近30天';
    return '近$days天';
  }

  String _formatChartPrice(double price) {
    if (price >= 10000) return price.toStringAsFixed(0);
    if (price >= 100) return price.toStringAsFixed(1);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}

/// Timeline-style judgment history item with colored dot + connecting line.
class _TimelineItem extends StatefulWidget {
  final Judgment judgment;
  final bool isLast;
  final bool isLatest;
  final VoidCallback? onTapReasoning;

  const _TimelineItem({
    required this.judgment,
    required this.isLast,
    this.isLatest = false,
    this.onTapReasoning,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isLatest) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MM-dd HH:mm');
    final isUp = widget.judgment.direction.toLowerCase() == 'up';
    final isDown = widget.judgment.direction.toLowerCase() == 'down';
    final dotColor = isUp
        ? AppTheme.upGreen
        : isDown
            ? AppTheme.downRed
            : AppTheme.flatGray;

    Widget dotWidget = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    // Pulse animation for the latest dot
    if (widget.isLatest && _pulseAnimation != null) {
      dotWidget = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation!.value,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.4),
                    blurRadius: 6 * (_pulseAnimation!.value - 1.0) * 2,
                    spreadRadius: 2 * (_pulseAnimation!.value - 1.0) * 2,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: dot + vertical line ──
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                dotWidget,
                // Connecting line
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppTheme.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Middle: direction + confidence ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DirectionBadge(direction: widget.judgment.direction, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConfidenceBar(
                          confidence: widget.judgment.confidenceScore,
                          height: 3,
                        ),
                      ),
                    ],
                  ),
                  if (widget.judgment.reasoning != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: widget.onTapReasoning,
                      child: Text(
                        widget.judgment.reasoning!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (widget.judgment.reasoning!.length > 80)
                      GestureDetector(
                        onTap: widget.onTapReasoning,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '查看全部分析',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Right: date + settlement ──
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _settlementIcon(),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(widget.judgment.createdAt.toLocal()),
                  style: const TextStyle(
                    color: AppTheme.flatGray,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementIcon() {
    if (!widget.judgment.isSettled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '待验证',
          style: TextStyle(
            color: AppTheme.flatGray,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    if (widget.judgment.isCorrect == true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: AppTheme.upGreen),
          const SizedBox(width: 3),
          Text(
            '正确',
            style: TextStyle(
              color: AppTheme.upGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cancel_rounded, size: 16, color: AppTheme.downRed),
        const SizedBox(width: 3),
        Text(
          '错误',
          style: TextStyle(
            color: AppTheme.downRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
