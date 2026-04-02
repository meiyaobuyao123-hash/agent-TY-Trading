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
      backgroundColor: AppTheme.background,
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
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
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

                // ── Price chart section ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildPriceChartSection(ref),
                  ),
                ),

                // ── Related markets section ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildRelatedMarketsSection(ref),
                  ),
                ),

                // ── AI Analysis section ──
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
                            // AI analysis header + card
                            _buildAIAnalysisSection(context, judgments.first),
                            const SizedBox(height: 32),
                            // Judgment history
                            _buildHistorySection(context, judgments),
                          ],
                        );
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

        return _PriceChart(snapshots: validSnaps);
      },
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
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          return _TimelineItem(
            judgment: j,
            isLast: isLast,
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
          const Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                '价格走势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
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

  String _formatChartPrice(double price) {
    if (price >= 10000) return price.toStringAsFixed(0);
    if (price >= 100) return price.toStringAsFixed(1);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}

/// Timeline-style judgment history item with colored dot + connecting line.
class _TimelineItem extends StatelessWidget {
  final Judgment judgment;
  final bool isLast;
  final VoidCallback? onTapReasoning;

  const _TimelineItem({
    required this.judgment,
    required this.isLast,
    this.onTapReasoning,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MM-dd HH:mm');
    final isUp = judgment.direction.toLowerCase() == 'up';
    final isDown = judgment.direction.toLowerCase() == 'down';
    final dotColor = isUp
        ? AppTheme.upGreen
        : isDown
            ? AppTheme.downRed
            : AppTheme.flatGray;

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
                // Colored dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                // Connecting line
                if (!isLast)
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
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DirectionBadge(direction: judgment.direction, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConfidenceBar(
                          confidence: judgment.confidenceScore,
                          height: 3,
                        ),
                      ),
                    ],
                  ),
                  if (judgment.reasoning != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onTapReasoning,
                      child: Text(
                        judgment.reasoning!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (judgment.reasoning!.length > 80)
                      GestureDetector(
                        onTap: onTapReasoning,
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
                  timeFormat.format(judgment.createdAt.toLocal()),
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
    if (!judgment.isSettled) {
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
    if (judgment.isCorrect == true) {
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
