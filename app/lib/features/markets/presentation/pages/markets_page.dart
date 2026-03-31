import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/market.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/markets_provider.dart';

/// Markets page — iOS Settings style grouped list.
class MarketsPage extends ConsumerWidget {
  const MarketsPage({super.key});

  static const _typeLabels = {
    'crypto': '加密货币',
    'stock': 'A股港股',
    'forex': '外汇',
    'macro': '宏观',
    'prediction': '预测市场',
  };

  String _localizedType(String type) {
    return _typeLabels[type.toLowerCase()] ?? type;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markets = ref.watch(marketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '跟踪市场',
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
      body: markets.when(
        loading: () => const LoadingWidget(message: '加载市场...'),
        error: (err, _) => AppErrorWidget(
          message: '加载市场失败:\n$err',
          onRetry: () => ref.invalidate(marketsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                '暂无跟踪市场',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          // Group by market type
          final grouped = <String, List<Market>>{};
          for (final m in list) {
            grouped.putIfAbsent(m.marketType, () => []).add(m);
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(marketsProvider);
              await ref.read(marketsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 0, bottom: 24),
              itemCount: grouped.entries.length,
              itemBuilder: (context, sectionIndex) {
                final entry = grouped.entries.elementAt(sectionIndex);
                final typeLabel = _localizedType(entry.key);
                final items = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    // Rows
                    Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                        border: Border(
                          top: BorderSide(color: AppTheme.divider, width: 0.5),
                          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
                        ),
                      ),
                      child: Column(
                        children: items.asMap().entries.map((e) {
                          final isLast = e.key == items.length - 1;
                          return _MarketRow(
                            market: e.value,
                            showDivider: !isLast,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final Market market;
  final bool showDivider;

  const _MarketRow({required this.market, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final snapshot = market.latestSnapshot;
    final changePct = snapshot?.changePct;
    final price = snapshot?.price;

    final changeColor = changePct != null
        ? (changePct >= 0 ? AppTheme.upGreen : AppTheme.downRed)
        : AppTheme.flatGray;

    return Column(
      children: [
        InkWell(
          onTap: () => context.push('/market/${market.symbol}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Market name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        market.symbol,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        market.name,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price + change badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price != null ? _formatPrice(price) : '--',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    if (changePct != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.divider,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 0.5, color: AppTheme.divider),
          ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}
