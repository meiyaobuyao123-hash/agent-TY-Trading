import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/judgment.dart';
import '../../../../shared/widgets/confidence_bar.dart';
import '../../../../shared/widgets/direction_badge.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/market_detail_provider.dart';

/// Detail page for a single market — iOS large title style.
class MarketDetailPage extends ConsumerWidget {
  final String symbol;

  const MarketDetailPage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(marketDetailProvider(symbol));
    final judgmentsAsync = ref.watch(marketJudgmentsProvider(symbol));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          symbol,
          style: const TextStyle(
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
      body: marketAsync.when(
        loading: () => const LoadingWidget(message: '加载中...'),
        error: (err, _) => AppErrorWidget(
          message: '加载失败:\n$err',
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

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(marketDetailProvider(symbol));
              ref.invalidate(marketJudgmentsProvider(symbol));
              await ref.read(marketDetailProvider(symbol).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Price header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          snap?.price != null
                              ? _formatPrice(snap!.price!)
                              : '--',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (changePct != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: changeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: changeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _infoChip(market.marketType),
                        const SizedBox(width: 8),
                        _infoChip(market.source),
                        if (market.isActive) ...[
                          const SizedBox(width: 8),
                          _infoChip('活跃', color: AppTheme.upGreen),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Section: AI判断历史
                _sectionHeader('AI判断历史'),
                const SizedBox(height: 12),

                judgmentsAsync.when(
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
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          '暂无判断记录',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section: 最新分析
                        if (judgments.first.reasoning != null) ...[
                          _sectionHeader('最新分析'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              judgments.first.reasoning!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // History list
                        ...judgments.map((j) => _JudgmentHistoryItem(
                              judgment: j,
                            )),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _infoChip(String label, {Color color = AppTheme.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}

class _JudgmentHistoryItem extends StatelessWidget {
  final Judgment judgment;

  const _JudgmentHistoryItem({required this.judgment});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DirectionBadge(direction: judgment.direction, size: 28),
                const SizedBox(height: 6),
                SizedBox(
                  width: 180,
                  child: ConfidenceBar(confidence: judgment.confidenceScore),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _settlementLabel(),
              const SizedBox(height: 4),
              Text(
                timeFormat.format(judgment.createdAt),
                style: const TextStyle(
                  color: AppTheme.flatGray,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settlementLabel() {
    if (!judgment.isSettled) {
      return const Text('待验证',
          style: TextStyle(color: AppTheme.flatGray, fontSize: 12));
    }
    if (judgment.isCorrect == true) {
      return const Text('正确',
          style: TextStyle(color: AppTheme.upGreen, fontSize: 12, fontWeight: FontWeight.w500));
    }
    return const Text('错误',
        style: TextStyle(color: AppTheme.downRed, fontSize: 12, fontWeight: FontWeight.w500));
  }
}
