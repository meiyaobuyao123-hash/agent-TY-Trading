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

/// Detail page for a single market showing price, judgments, and reasoning.
class MarketDetailPage extends ConsumerWidget {
  final String symbol;

  const MarketDetailPage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(marketDetailProvider(symbol));
    final judgmentsAsync = ref.watch(marketJudgmentsProvider(symbol));

    return Scaffold(
      appBar: AppBar(title: Text(symbol)),
      body: marketAsync.when(
        loading: () => const LoadingWidget(message: 'Loading market...'),
        error: (err, _) => AppErrorWidget(
          message: 'Failed to load market:\n$err',
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
            color: AppTheme.accent,
            onRefresh: () async {
              ref.invalidate(marketDetailProvider(symbol));
              ref.invalidate(marketJudgmentsProvider(symbol));
              await ref.read(marketDetailProvider(symbol).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Market header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              snap?.price != null
                                  ? _formatPrice(snap!.price!)
                                  : '--',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (changePct != null)
                              Text(
                                '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: changeColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _infoChip(market.marketType),
                            const SizedBox(width: 8),
                            _infoChip(market.source),
                            if (market.isActive) ...[
                              const SizedBox(width: 8),
                              _infoChip('Active',
                                  color: AppTheme.upGreen),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Judgment history
                const Text(
                  'Judgment History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                judgmentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: LoadingWidget(),
                  ),
                  error: (err, _) => AppErrorWidget(
                    message: 'Failed to load judgments',
                    onRetry: () =>
                        ref.invalidate(marketJudgmentsProvider(symbol)),
                  ),
                  data: (judgments) {
                    if (judgments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No judgments yet for this market.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Latest reasoning (expanded)
                        if (judgments.first.reasoning != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Latest AI Reasoning',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    judgments.first.reasoning!,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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

  Widget _infoChip(String label, {Color color = AppTheme.accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DirectionBadge(direction: judgment.direction, size: 28),
                _settlementIcon(),
              ],
            ),
            const SizedBox(height: 8),
            ConfidenceBar(confidence: judgment.confidenceScore),
            const SizedBox(height: 8),
            Text(
              timeFormat.format(judgment.createdAt),
              style: const TextStyle(
                color: AppTheme.flatGray,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settlementIcon() {
    if (!judgment.isSettled) {
      return const Icon(Icons.schedule, color: AppTheme.flatGray, size: 18);
    }
    if (judgment.isCorrect == true) {
      return const Icon(Icons.check_circle, color: AppTheme.upGreen, size: 18);
    }
    return const Icon(Icons.cancel, color: AppTheme.downRed, size: 18);
  }
}
