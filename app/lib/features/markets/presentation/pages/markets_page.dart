import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/favorites_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/market.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/markets_provider.dart';

/// Markets page — Apple-style flat, minimalist, tech-forward UI.
class MarketsPage extends ConsumerStatefulWidget {
  const MarketsPage({super.key});

  @override
  ConsumerState<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends ConsumerState<MarketsPage> {
  static const _typeLabels = {
    'crypto': '加密货币',
    'cn-equities': 'A股',
    'global-indices': '全球指数',
    'forex': '外汇',
    'macro': '宏观指标',
    'prediction-markets': '预测市场',
  };

  static const _filterChips = [
    _FilterChip(label: '全部', type: null),
    _FilterChip(label: '我的关注', type: '_favorites'),
    _FilterChip(label: '加密', type: 'crypto'),
    _FilterChip(label: 'A股', type: 'cn-equities'),
    _FilterChip(label: '外汇', type: 'forex'),
    _FilterChip(label: '宏观', type: 'macro'),
  ];

  String? _selectedFilter;
  String _searchQuery = '';

  String _localizedType(String type) {
    return _typeLabels[type.toLowerCase()] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final markets = ref.watch(marketsProvider);

    return Scaffold(
      body: SafeArea(
        child: markets.when(
          loading: () => const LoadingWidget(message: '加载市场...'),
          error: (err, _) => AppErrorWidget.fromError(
            error: err,
            onRetry: () => ref.invalidate(marketsProvider),
          ),
          data: (list) => _buildContent(list),
        ),
      ),
    );
  }

  Widget _buildContent(List<Market> list) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final favorites = favoritesAsync.valueOrNull ?? <String>{};

    // Compute counts per filter type for badges
    final typeCounts = <String?, int>{};
    typeCounts[null] = list.length; // "全部"
    typeCounts['_favorites'] = list.where((m) => favorites.contains(m.symbol)).length;
    for (final chip in _filterChips) {
      if (chip.type != null && chip.type != '_favorites') {
        typeCounts[chip.type] =
            list.where((m) => m.marketType == chip.type).length;
      }
    }

    // Apply type filter
    List<Market> filtered;
    if (_selectedFilter == null) {
      filtered = list;
    } else if (_selectedFilter == '_favorites') {
      filtered = list.where((m) => favorites.contains(m.symbol)).toList();
    } else {
      filtered = list.where((m) => m.marketType == _selectedFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((m) =>
              m.symbol.toLowerCase().contains(q) ||
              m.name.toLowerCase().contains(q))
          .toList();
    }

    // Group by market type
    final grouped = <String, List<Market>>{};
    for (final m in filtered) {
      grouped.putIfAbsent(m.marketType, () => []).add(m);
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(marketsProvider);
        await ref.read(marketsProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          // Large title header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
              child: const Text(
                '市场',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
              child: TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: '搜索市场...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterChips.map((chip) {
                    final isSelected = chip.type == _selectedFilter;
                    final count = typeCounts[chip.type] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = chip.type);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.textPrimary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${chip.label} ($count)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.background
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Empty state
          if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '暂无跟踪市场',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

          // Grouped market sections
          ...grouped.entries.expand((entry) {
            final typeLabel = _localizedType(entry.key);
            final items = entry.value;
            return [
              // Section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 20, 8),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              // Market rows
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
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
                    children: items.asMap().entries.map((e) {
                      final isLast = e.key == items.length - 1;
                      final isFav = favorites.contains(e.value.symbol);
                      return _MarketRow(
                        market: e.value,
                        showDivider: !isLast,
                        isFavorite: isFav,
                        onToggleFavorite: () {
                          ref.read(favoritesProvider.notifier).toggle(e.value.symbol);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ];
          }),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}

class _FilterChip {
  final String label;
  final String? type;

  const _FilterChip({required this.label, required this.type});
}

class _MarketRow extends StatelessWidget {
  final Market market;
  final bool showDivider;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _MarketRow({
    required this.market,
    this.showDivider = true,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = market.latestSnapshot;
    final changePct = snapshot?.changePct;
    final price = snapshot?.price;

    Color changeColor;
    Color changeBg;
    if (changePct != null) {
      if (changePct > 0) {
        changeColor = AppTheme.upGreen;
        changeBg = AppTheme.upGreen.withValues(alpha: 0.1);
      } else if (changePct < 0) {
        changeColor = AppTheme.downRed;
        changeBg = AppTheme.downRed.withValues(alpha: 0.1);
      } else {
        changeColor = AppTheme.flatGray;
        changeBg = AppTheme.flatGray.withValues(alpha: 0.1);
      }
    } else {
      changeColor = AppTheme.flatGray;
      changeBg = AppTheme.flatGray.withValues(alpha: 0.1);
    }

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/market/${market.symbol}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Star
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: isFavorite
                          ? const Color(0xFFFFB800)
                          : AppTheme.divider,
                    ),
                  ),
                ),
                // Left: Symbol + Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        market.symbol,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        market.name,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Right: Price + Change pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price != null ? _formatPrice(price) : '\u2014',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: changeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        changePct != null
                            ? '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%'
                            : '\u2014',
                        style: TextStyle(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: AppTheme.divider,
            ),
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
