import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/market.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/markets_provider.dart';

/// Markets page showing all tracked markets in a list.
class MarketsPage extends ConsumerWidget {
  const MarketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markets = ref.watch(marketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Markets')),
      body: markets.when(
        loading: () => const LoadingWidget(message: 'Loading markets...'),
        error: (err, _) => AppErrorWidget(
          message: 'Failed to load markets:\n$err',
          onRetry: () => ref.invalidate(marketsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No markets tracked yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () async {
              ref.invalidate(marketsProvider);
              await ref.read(marketsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: list.length,
              itemBuilder: (context, index) =>
                  _MarketTile(market: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final Market market;

  const _MarketTile({required this.market});

  @override
  Widget build(BuildContext context) {
    final snapshot = market.latestSnapshot;
    final changePct = snapshot?.changePct;
    final price = snapshot?.price;

    final changeColor = changePct != null
        ? (changePct >= 0 ? AppTheme.upGreen : AppTheme.downRed)
        : AppTheme.flatGray;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.push('/market/${market.symbol}'),
        title: Text(
          market.symbol,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${market.name}  |  ${market.marketType}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price != null ? _formatPrice(price) : '--',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 16,
              ),
            ),
            if (changePct != null)
              Text(
                '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}
