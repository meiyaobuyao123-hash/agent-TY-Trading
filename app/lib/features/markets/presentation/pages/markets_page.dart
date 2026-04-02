import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MarketsPageState extends ConsumerState<MarketsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    'kr-equities': '韩股',
    'in-equities': '印股',
    'uk-equities': '英股',
    'au-equities': '澳股',
    'latam-equities': '拉美股',
    'mena-equities': '中东股',
    'sg-equities': '新加坡',
    'tw-equities': '台股',
  };

  static const _filterChips = [
    _FilterChip(label: '全部', type: null),
    _FilterChip(label: '关注', type: '_favorites'),
    _FilterChip(label: '加密', type: 'crypto'),
    _FilterChip(label: '美股', type: 'us-equities'),
    _FilterChip(label: 'A股', type: 'cn-equities'),
    _FilterChip(label: 'ETF', type: 'etf'),
    _FilterChip(label: '外汇', type: 'forex'),
    _FilterChip(label: '宏观', type: 'macro'),
    _FilterChip(label: '日股', type: 'jp-equities'),
    _FilterChip(label: '欧股', type: 'eu-equities'),
    _FilterChip(label: '韩股', type: 'kr-equities'),
    _FilterChip(label: '印股', type: 'in-equities'),
    _FilterChip(label: '英股', type: 'uk-equities'),
    _FilterChip(label: '澳股', type: 'au-equities'),
  ];

  // Region grouping: region label -> market types in that region
  static const _regionGroups = {
    '\u{1F1FA}\u{1F1F8} 美国': ['us-equities', 'etf'],
    '\u{1F1E8}\u{1F1F3} 中国': ['cn-equities', 'hk-equities'],
    '\u{1F1EF}\u{1F1F5} 日本': ['jp-equities'],
    '\u{1F1F0}\u{1F1F7} 韩国': ['kr-equities'],
    '\u{1F1EE}\u{1F1F3} 印度': ['in-equities'],
    '\u{1F1F9}\u{1F1FC} 台湾': ['tw-equities'],
    '\u{1F1EA}\u{1F1FA} 欧洲': ['eu-equities', 'uk-equities'],
    '\u{1F1F8}\u{1F1EC} 新加坡': ['sg-equities'],
    '\u{1F1E6}\u{1F1FA} 大洋洲': ['au-equities'],
    '\u{1F30D} 全球': ['forex', 'commodities', 'global-indices', 'crypto', 'macro', 'prediction-markets', 'latam-equities', 'mena-equities'],
  };

  // 0 = by type, 1 = by region, 2 = by sector
  int _viewMode = 0;
  String? _selectedFilter;
  String _searchQuery = '';
  final List<Market> _compareSelection = [];

  void _toggleCompare(Market market, List<Market> allMarkets) {
    setState(() {
      if (_compareSelection.contains(market)) {
        _compareSelection.remove(market);
      } else if (_compareSelection.length < 2) {
        _compareSelection.add(market);
        if (_compareSelection.length == 2) {
          _showComparisonSheet(context, _compareSelection[0], _compareSelection[1]);
        }
      }
    });
  }

  void _clearCompare() {
    setState(() => _compareSelection.clear());
  }

  void _showComparisonSheet(
      BuildContext context, Market a, Market b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComparisonSheet(marketA: a, marketB: b),
    ).then((_) => _clearCompare());
  }

  String _localizedType(String type) {
    return _typeLabels[type.toLowerCase()] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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

    // Group by market type, region, or sector
    final grouped = <String, List<Market>>{};
    if (_viewMode == 1) {
      for (final entry in _regionGroups.entries) {
        final regionLabel = entry.key;
        final types = entry.value;
        final regionMarkets = filtered.where((m) => types.contains(m.marketType)).toList();
        if (regionMarkets.isNotEmpty) {
          grouped[regionLabel] = regionMarkets;
        }
      }
    } else {
      for (final m in filtered) {
        grouped.putIfAbsent(_localizedType(m.marketType), () => []).add(m);
      }
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(marketsProvider);
        await ref.read(marketsProvider.future);
        HapticFeedback.lightImpact();
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
      child: CustomScrollView(
        slivers: [
          // Large title header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
              child: Text(
                '市场',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
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
                  fillColor: AppTheme.surfaceOf(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimaryOf(context),
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
                          HapticFeedback.lightImpact();
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
                                ? AppTheme.textPrimaryOf(context)
                                : AppTheme.surfaceOf(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${chip.label} ($count)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.backgroundOf(context)
                                  : AppTheme.textSecondaryOf(context),
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

          // Toggle: 按类型 / 按地区 / 按板块
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 20, 4),
              child: Row(
                children: [
                  _ViewModeChip(
                    label: '按类型',
                    icon: Icons.category_rounded,
                    isSelected: _viewMode == 0,
                    onTap: () => setState(() => _viewMode = 0),
                  ),
                  const SizedBox(width: 8),
                  _ViewModeChip(
                    label: '按地区',
                    icon: Icons.public_rounded,
                    isSelected: _viewMode == 1,
                    onTap: () => setState(() => _viewMode = 1),
                  ),
                  const SizedBox(width: 8),
                  _ViewModeChip(
                    label: '按板块',
                    icon: Icons.pie_chart_outline_rounded,
                    isSelected: _viewMode == 2,
                    onTap: () => setState(() => _viewMode = 2),
                  ),
                ],
              ),
            ),
          ),

          // Sector view (R29)
          if (_viewMode == 2)
            SliverToBoxAdapter(
              child: _SectorPerformanceView(),
            ),

          // Global view summary (when region view active + "全部")
          if (_viewMode == 1 && _selectedFilter == null)
            SliverToBoxAdapter(
              child: _GlobalViewSummary(),
            ),

          // Compare hint bar
          if (_compareSelection.length == 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.compare_arrows_rounded,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已选 ${_compareSelection[0].symbol}，长按另一个市场进行对比',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearCompare,
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppTheme.primary),
                      ),
                    ],
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
            final typeLabel = entry.key;
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
                    color: AppTheme.cardColorOf(context),
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
                      final isSelected = _compareSelection.contains(e.value);
                      return _MarketRow(
                        market: e.value,
                        showDivider: !isLast,
                        isFavorite: isFav,
                        isCompareSelected: isSelected,
                        onToggleFavorite: () {
                          ref.read(favoritesProvider.notifier).toggle(e.value.symbol);
                        },
                        onLongPress: () => _toggleCompare(e.value, filtered),
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
  final bool isCompareSelected;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onLongPress;

  const _MarketRow({
    required this.market,
    this.showDivider = true,
    this.isFavorite = false,
    this.isCompareSelected = false,
    this.onToggleFavorite,
    this.onLongPress,
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
          onLongPress: onLongPress,
          child: Container(
            color: isCompareSelected
                ? AppTheme.primary.withValues(alpha: 0.06)
                : null,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
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
              color: AppTheme.dividerOf(context),
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

/// View mode chip button.
class _ViewModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sector performance view (R29) — shows sector cards for US stocks.
class _SectorPerformanceView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectorsAsync = ref.watch(sectorPerformanceProvider);

    return sectorsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '板块数据加载失败',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ),
      data: (sectors) {
        if (sectors.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '暂无板块数据',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 14,
                      color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '美股板块表现',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sector summary row (horizontal scroll)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sectors.map((s) {
                    final sectorName = s['sector'] as String? ?? '';
                    final avgChange = (s['avg_change'] as num?)?.toDouble() ?? 0.0;
                    final trend = s['trend'] as String? ?? '';

                    Color changeColor;
                    if (avgChange > 0.3) {
                      changeColor = AppTheme.upGreen;
                    } else if (avgChange < -0.3) {
                      changeColor = AppTheme.downRed;
                    } else {
                      changeColor = AppTheme.flatGray;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColorOf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: changeColor.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000)
                                  .withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sectorName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${avgChange >= 0 ? "+" : ""}${avgChange.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: changeColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trend,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: changeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Detailed sector cards
              const SizedBox(height: 12),
              ...sectors.map((s) {
                final sectorName = s['sector'] as String? ?? '';
                final avgChange = (s['avg_change'] as num?)?.toDouble() ?? 0.0;
                final trend = s['trend'] as String? ?? '';
                final up = s['up'] as int? ?? 0;
                final down = s['down'] as int? ?? 0;
                final total = s['total'] as int? ?? 0;
                final symbols = (s['symbols'] as List<dynamic>?)?.cast<String>() ?? [];

                Color changeColor;
                if (avgChange > 0.3) {
                  changeColor = AppTheme.upGreen;
                } else if (avgChange < -0.3) {
                  changeColor = AppTheme.downRed;
                } else {
                  changeColor = AppTheme.flatGray;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColorOf(context),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000)
                            .withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sectorName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: changeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${avgChange >= 0 ? "+" : ""}${avgChange.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: changeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trend,
                            style: TextStyle(
                              fontSize: 12,
                              color: changeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '涨$up 跌$down/$total',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      if (symbols.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: symbols.map((sym) {
                            return Text(
                              sym,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Global view summary — shows region-level direction summary.
class _GlobalViewSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalViewAsync = ref.watch(globalViewProvider);

    return globalViewAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final summaryText = data['summary_text'] as String? ?? '';
        if (summaryText.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '全球视图',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  summaryText,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Comparison bottom sheet — side-by-side view of two markets.
class _ComparisonSheet extends StatelessWidget {
  final Market marketA;
  final Market marketB;

  const _ComparisonSheet({required this.marketA, required this.marketB});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColorOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            '市场对比',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          // Two columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildColumn(context, marketA)),
              Container(
                width: 1,
                height: 180,
                color: AppTheme.dividerOf(context),
              ),
              Expanded(child: _buildColumn(context, marketB)),
            ],
          ),
          const SizedBox(height: 16),
          // Correlation text
          _buildCorrelationText(context),
        ],
      ),
    );
  }

  Widget _buildColumn(BuildContext context, Market market) {
    final snap = market.latestSnapshot;
    final price = snap?.price;
    final changePct = snap?.changePct;
    final changeColor = changePct != null
        ? (changePct > 0
            ? AppTheme.upGreen
            : changePct < 0
                ? AppTheme.downRed
                : AppTheme.flatGray)
        : AppTheme.flatGray;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            market.symbol,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            market.name,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Price
          Text(
            price != null ? _fmtPrice(price) : '--',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          // Change pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              changePct != null
                  ? '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%'
                  : '--',
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Market type
          Text(
            market.marketType,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationText(BuildContext context) {
    // Simple static correlation check
    final symA = marketA.symbol;
    final symB = marketB.symbol;

    String? correlationNote;
    if (symA == symB) {
      correlationNote = '相同市场';
    } else if (marketA.marketType == marketB.marketType) {
      correlationNote = '同类市场 (${marketA.marketType})，通常走势相关';
    }

    if (correlationNote == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              correlationNote,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}
