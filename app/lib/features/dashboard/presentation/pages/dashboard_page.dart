import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/favorites_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/judgment.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/signal_card.dart';
import '../../providers/dashboard_provider.dart';

/// Dashboard page — Apple-style flat, minimalist, tech-forward UI.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _showOnboarding = false;
  bool _onboardingChecked = false;
  bool _showAllSignals = false;
  static const int _initialSignalCount = 20;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('onboarding_dismissed') ?? false;
    if (mounted) {
      setState(() {
        _showOnboarding = !dismissed;
        _onboardingChecked = true;
      });
    }
  }

  Future<void> _dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_dismissed', true);
    if (mounted) {
      setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final judgments = ref.watch(latestJudgmentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      body: SafeArea(
        child: judgments.when(
          loading: () => const LoadingWidget(message: '加载判断中...'),
          error: (err, _) => AppErrorWidget.fromError(
            error: err,
            onRetry: () => ref.invalidate(latestJudgmentsProvider),
          ),
          data: (list) => _buildContent(context, ref, list),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<Judgment> list) {
    // Filter to only judgments with real data
    final validList = list
        .where((j) =>
            j.rationalPrice != null ||
            j.deviationPct != null ||
            (j.modelVotes != null &&
                j.modelVotes!.any((v) => v.rationalPrice != null)))
        .toList();

    // Compute metrics from valid judgments
    final totalCount = validList.length;
    final upCount =
        validList.where((j) => j.direction.toLowerCase() == 'up').length;
    final downCount =
        validList.where((j) => j.direction.toLowerCase() == 'down').length;
    final activeMarkets =
        validList.map((j) => j.symbol ?? j.marketId).toSet().length;

    // Find most recent judgment time for "last updated"
    String? lastUpdatedStr;
    if (list.isNotEmpty) {
      final mostRecent = list.fold<DateTime>(
        list.first.createdAt,
        (prev, j) => j.createdAt.isAfter(prev) ? j.createdAt : prev,
      );
      lastUpdatedStr =
          DateFormat('HH:mm').format(mostRecent.toLocal());
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(latestJudgmentsProvider);
        ref.invalidate(overviewStatsProvider);
        ref.invalidate(insightsProvider);
        await ref.read(latestJudgmentsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 16),

          // Header row
          _buildHeader(),

          // Last updated indicator
          if (lastUpdatedStr != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '最后更新: $lastUpdatedStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.flatGray,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

          // Dashboard info text
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI每4小时分析全球195个市场，给出方向判断和合理价格估值',
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
          ),

          const SizedBox(height: 16),

          // Onboarding card (dismissible)
          if (_onboardingChecked && _showOnboarding) ...[
            _buildOnboardingCard(),
            const SizedBox(height: 16),
          ],

          // Market overview summary card
          _buildMarketOverview(upCount, downCount, totalCount - upCount - downCount),

          const SizedBox(height: 12),

          // Summary metric cards
          _buildMetricRow(activeMarkets, totalCount, upCount, downCount),

          const SizedBox(height: 20),

          // AI Discoveries section (Smart Scanner)
          _buildDiscoveriesSection(ref),

          const SizedBox(height: 20),

          // AI Evolution section
          _buildEvolutionSection(ref),

          const SizedBox(height: 20),

          // Today's highlights
          _buildHighlightsSection(ref),

          const SizedBox(height: 12),

          // AI Insights section
          _buildInsightsSection(ref),

          const SizedBox(height: 28),

          // Section header: 实时 AI 信号
          _buildSectionHeader(),

          const SizedBox(height: 16),

          // Signal cards — sorted by confidence desc, then abs deviation desc
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.signal_cellular_alt_rounded,
                      size: 48,
                      color: AppTheme.divider,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '暂无信号',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '等待 AI 分析周期',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.flatGray,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._buildSortedSignalCards(context, ref, list),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Onboarding card ──
  Widget _buildOnboardingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '欢迎使用天演',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'AI 金融世界模型',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _dismissOnboarding,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _onboardingBullet(
              Icons.search_rounded, 'AI 每4小时分析全球市场'),
          const SizedBox(height: 10),
          _onboardingBullet(
              Icons.touch_app_rounded, '点击任意信号卡查看详细分析'),
          const SizedBox(height: 10),
          _onboardingBullet(
              Icons.trending_up_rounded, '系统自动追踪判断准确率'),
          const SizedBox(height: 10),
          _onboardingBullet(
              Icons.auto_awesome_rounded, 'AI 通过历史表现不断自我进化'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _dismissOnboarding,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '知道了',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onboardingBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // ── AI Discoveries section ──
  Widget _buildDiscoveriesSection(WidgetRef ref) {
    final discoveriesAsync = ref.watch(discoveriesProvider);

    return discoveriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (discoveries) {
        if (discoveries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'AI 发现',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${discoveries.length}条',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...discoveries.map((d) {
              final type = d['type'] as String? ?? '';
              final desc = d['description'] as String? ?? '';
              final severity = d['severity'] as String? ?? 'low';

              IconData icon;
              Color iconColor;
              switch (type) {
                case 'divergence':
                  icon = Icons.compare_arrows_rounded;
                  iconColor = const Color(0xFFFF6B00);
                  break;
                case 'volume_spike':
                  icon = Icons.trending_up_rounded;
                  iconColor = const Color(0xFF5856D6);
                  break;
                case 'direction_change':
                  icon = Icons.swap_vert_rounded;
                  iconColor = AppTheme.downRed;
                  break;
                default:
                  icon = Icons.lightbulb_outline_rounded;
                  iconColor = AppTheme.primary;
              }

              final isSevere = severity == 'high';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSevere
                        ? iconColor.withValues(alpha: 0.06)
                        : AppTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: isSevere
                        ? Border.all(
                            color: iconColor.withValues(alpha: 0.2),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          desc,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSevere ? FontWeight.w600 : FontWeight.w400,
                            color: AppTheme.textPrimaryOf(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ── AI Evolution section ──
  Widget _buildEvolutionSection(WidgetRef ref) {
    final statsAsync = ref.watch(overviewStatsProvider);

    return statsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
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
      data: (stats) {
        final daysRunning = stats['days_running'] ?? 0;
        final totalJudgments = stats['total_judgments'] ?? 0;
        final settledJudgments = stats['settled_judgments'] ?? 0;
        final overallAccuracy = (stats['overall_accuracy'] as num?)?.toDouble() ?? 0.0;
        final marketsTracked = stats['markets_tracked'] ?? 0;
        final marketsWithData = stats['markets_with_data'] ?? 0;
        final models = (stats['active_models'] as List?)?.cast<String>() ?? [];

        // Color based on accuracy performance
        Color accuracyColor;
        if (overallAccuracy >= 60) {
          accuracyColor = AppTheme.upGreen;
        } else if (overallAccuracy >= 45) {
          accuracyColor = const Color(0xFFFFCC00);
        } else {
          accuracyColor = AppTheme.downRed;
        }

        final isPerformingWell = overallAccuracy >= 60;
        final statusText = isPerformingWell ? 'AI表现良好' : '进化中...';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with mini accuracy ring
              Row(
                children: [
                  // Mini accuracy ring (60x60)
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CustomPaint(
                      painter: _MiniAccuracyRingPainter(
                        percentage: overallAccuracy,
                        color: accuracyColor,
                        trackColor: AppTheme.dividerOf(context),
                      ),
                      child: Center(
                        child: Text(
                          '${overallAccuracy.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accuracyColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 进化',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (!isPerformingWell)
                              _PulsingDot(color: accuracyColor)
                            else
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppTheme.upGreen),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: accuracyColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.upGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      models.isNotEmpty ? models.first : 'AI',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.upGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Stats grid
              Row(
                children: [
                  _evolutionStat('运行天数', '$daysRunning'),
                  _evolutionDivider(),
                  _evolutionStat('总判断', '$totalJudgments'),
                  _evolutionDivider(),
                  _evolutionStat('已验证', '$settledJudgments'),
                ],
              ),
              const SizedBox(height: 14),
              // Markets info row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundOf(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public_rounded,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '追踪 $marketsTracked 个市场，$marketsWithData 个有数据',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (settledJudgments < 10) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 14, color: Color(0xFF856404)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '数据积累中... 准确率将随验证数据增多而更可靠',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF856404),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _evolutionStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _evolutionDivider() {
    return Container(
      width: 0.5,
      height: 32,
      color: AppTheme.dividerOf(context),
    );
  }

  // ── Today's highlights section ──
  Widget _buildHighlightsSection(WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final statsAsync = ref.watch(overviewStatsProvider);

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (insightsData) {
        final bigDev = insightsData['biggest_deviation'] as Map<String, dynamic>?;

        // Build highlight cards
        final cards = <Widget>[];

        // 1. Biggest deviation highlight
        if (bigDev != null) {
          final devPct = (bigDev['deviation_pct'] as num?)?.toDouble() ?? 0;
          final sym = bigDev['symbol'] as String? ?? '--';
          final isOvervalued = devPct < 0;
          cards.add(_highlightCard(
            emoji: '\ud83d\udd25',
            text: '$sym \u504f\u79bb${devPct.abs().toStringAsFixed(1)}% \u2014 AI\u8ba4\u4e3a\u88ab${isOvervalued ? "\u4e25\u91cd\u9ad8\u4f30" : "\u4e25\u91cd\u4f4e\u4f30"}',
            color: AppTheme.downRed,
          ));
        }

        // 2. Fear & Greed from overview stats
        statsAsync.whenData((stats) {
          final breadth = stats['market_breadth'] as Map<String, dynamic>?;
          if (breadth != null) {
            final mood = breadth['mood'] as String? ?? '\u4e2d\u6027';
            final upPct = (breadth['up_pct'] as num?)?.toDouble() ?? 50;
            String emoji;
            Color moodColor;
            if (upPct < 30) {
              emoji = '\ud83d\ude30';
              moodColor = AppTheme.downRed;
            } else if (upPct > 70) {
              emoji = '\ud83e\udd11';
              moodColor = AppTheme.upGreen;
            } else {
              emoji = '\ud83d\ude10';
              moodColor = AppTheme.flatGray;
            }
            cards.add(_highlightCard(
              emoji: emoji,
              text: '\u5e02\u573a\u60c5\u7eea: $mood (${upPct.toStringAsFixed(0)}%\u4e0a\u6da8)',
              color: moodColor,
            ));
          }
        });

        if (cards.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\u4eca\u65e5\u4eae\u70b9',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cards.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: c,
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _highlightCard({
    required String emoji,
    required String text,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Insights section ──
  Widget _buildInsightsSection(WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final highConf = data['highest_confidence'] as Map<String, dynamic>?;
        final bigDev = data['biggest_deviation'] as Map<String, dynamic>?;
        final streaks = (data['streaks'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Don't show section if nothing to display
        if (highConf == null && bigDev == null && streaks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 洞察',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Cards row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (highConf != null)
                    _insightCard(
                      icon: Icons.bolt_rounded,
                      iconColor: AppTheme.primary,
                      title: '最高置信信号',
                      value: highConf['symbol'] as String? ?? '--',
                      subtitle: '${highConf['direction'] == 'up' ? '看涨' : highConf['direction'] == 'down' ? '看跌' : '观望'} ${((highConf['confidence_score'] as num? ?? 0) * 100).toStringAsFixed(0)}%',
                    ),
                  if (bigDev != null) ...[
                    const SizedBox(width: 10),
                    _insightCard(
                      icon: Icons.show_chart_rounded,
                      iconColor: AppTheme.downRed,
                      title: '最大偏差',
                      value: bigDev['symbol'] as String? ?? '--',
                      subtitle: '${(bigDev['deviation_pct'] as num? ?? 0).toStringAsFixed(1)}% 偏差',
                    ),
                  ],
                  if (streaks.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _insightCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppTheme.upGreen,
                      title: '连续正确',
                      value: streaks.first['symbol'] as String? ?? '--',
                      subtitle: '${streaks.first['correct_streak']}次连续命中',
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _insightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSortedSignalCards(
      BuildContext context, WidgetRef ref, List<Judgment> list) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final favorites = favoritesAsync.valueOrNull ?? <String>{};

    final validList = list
        .where((j) =>
            j.rationalPrice != null ||
            j.deviationPct != null ||
            (j.modelVotes != null &&
                j.modelVotes!.any((v) => v.rationalPrice != null)))
        .toList();

    // Sort: favorites first, then by confidence, then by deviation
    validList.sort((a, b) {
      final aFav = favorites.contains(a.symbol) ? 0 : 1;
      final bFav = favorites.contains(b.symbol) ? 0 : 1;
      if (aFav != bFav) return aFav.compareTo(bFav);
      final confCmp = b.confidenceScore.compareTo(a.confidenceScore);
      if (confCmp != 0) return confCmp;
      final aDevAbs = (a.deviationPct ?? 0).abs();
      final bDevAbs = (b.deviationPct ?? 0).abs();
      return bDevAbs.compareTo(aDevAbs);
    });

    // Limit to top N by confidence on initial load (R13 performance)
    final displayList = _showAllSignals
        ? validList
        : validList.take(_initialSignalCount).toList();
    final hasMore = validList.length > _initialSignalCount && !_showAllSignals;

    final cards = displayList
        .map((j) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSignalCard(context, j,
                  isFavorite: favorites.contains(j.symbol),
                  onToggleFavorite: () {
                    ref.read(favoritesProvider.notifier).toggle(j.symbol ?? '');
                  }),
            ))
        .toList();

    if (hasMore) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _showAllSignals = true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
              ),
              child: Text(
                '查看更多 (${validList.length - _initialSignalCount}个市场)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  /// Compute system health color: green/yellow/red based on /health data.
  Color _systemHealthColor(AsyncValue<Map<String, dynamic>> healthAsync) {
    final data = healthAsync.valueOrNull;
    if (data == null) {
      // Loading or error => red if error, gray if loading
      return healthAsync.hasError ? AppTheme.downRed : AppTheme.flatGray;
    }
    if (data['status'] != 'ok') return AppTheme.downRed;

    // Check last_cycle_time — if >5h ago, yellow
    final lastCycleStr = data['last_cycle_time'] as String?;
    if (lastCycleStr != null) {
      try {
        final lastCycle = DateTime.parse(lastCycleStr);
        final hoursSince = DateTime.now().toUtc().difference(lastCycle).inHours;
        if (hoursSince > 5) return const Color(0xFFF59E0B); // yellow
      } catch (_) {}
    } else {
      // No cycle ever run — yellow
      return const Color(0xFFF59E0B);
    }

    // Check plugins health
    final plugins = data['plugins'] as Map<String, dynamic>? ?? {};
    int unhealthy = 0;
    for (final entry in plugins.values) {
      final info = entry as Map<String, dynamic>? ?? {};
      if (info['healthy'] != true) unhealthy++;
    }
    if (unhealthy > 2) return const Color(0xFFF59E0B); // yellow

    return AppTheme.upGreen;
  }

  String _systemHealthLabel(Color color) {
    if (color == AppTheme.upGreen) return '系统正常';
    if (color == AppTheme.downRed) return '系统离线';
    if (color == AppTheme.flatGray) return '检测中...';
    return '部分异常';
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('MM月dd日').format(now);
    final alertsAsync = ref.watch(alertsProvider);
    final alertCount = alertsAsync.valueOrNull?.length ?? 0;
    final healthAsync = ref.watch(healthStatusProvider);
    final healthColor = _systemHealthColor(healthAsync);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left: title + system status
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '天演',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                // System health dot
                GestureDetector(
                  onTap: () {
                    final label = _systemHealthLabel(healthColor);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(label),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: healthColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: healthColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'AI 金融世界模型',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Alerts bell
        GestureDetector(
          onTap: () => _showAlertsSheet(context),
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: AppTheme.textSecondary,
                ),
                if (alertCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.downRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          alertCount > 9 ? '9+' : '$alertCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Right: time
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAlertsSheet(BuildContext context) {
    final alertsAsync = ref.read(alertsProvider);
    final alerts = alertsAsync.valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '通知',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '暂无通知',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (c, idx) => const Divider(
                    height: 1,
                    color: AppTheme.divider,
                  ),
                  itemBuilder: (_, i) {
                    final a = alerts[i];
                    final type = a['type'] as String? ?? '';
                    IconData icon;
                    Color iconColor;
                    switch (type) {
                      case 'high_confidence':
                        icon = Icons.bolt_rounded;
                        iconColor = AppTheme.primary;
                      case 'large_deviation':
                        icon = Icons.show_chart_rounded;
                        iconColor = AppTheme.downRed;
                      case 'accuracy_milestone':
                        icon = Icons.emoji_events_rounded;
                        iconColor = const Color(0xFFFFB800);
                      case 'streak':
                        icon = Icons.local_fire_department_rounded;
                        iconColor = AppTheme.upGreen;
                      default:
                        icon = Icons.info_outline_rounded;
                        iconColor = AppTheme.textSecondary;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 16, color: iconColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['title'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a['detail'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverview(int upCount, int downCount, int flatCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
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
                child: const Icon(Icons.public_rounded,
                    size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                '市场概览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              children: [
                const TextSpan(text: '今日全球市场：'),
                TextSpan(
                  text: '$upCount涨',
                  style: const TextStyle(
                    color: AppTheme.upGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: '$downCount跌',
                  style: const TextStyle(
                    color: AppTheme.downRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: '$flatCount横盘',
                  style: const TextStyle(
                    color: AppTheme.flatGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Market breadth mood indicator
          Builder(
            builder: (context) {
              final total = upCount + downCount + flatCount;
              final upPct = total > 0 ? (upCount / total * 100) : 50.0;
              String mood;
              Color moodColor;
              if (upPct > 70) {
                mood = '贪婪';
                moodColor = AppTheme.upGreen;
              } else if (upPct < 30) {
                mood = '恐慌';
                moodColor = AppTheme.downRed;
              } else {
                mood = '中性';
                moodColor = AppTheme.flatGray;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: moodColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      upPct > 70
                          ? Icons.trending_up_rounded
                          : upPct < 30
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      size: 14,
                      color: moodColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\u5E02\u573A\u60C5\u7EEA: $mood (${upPct.toStringAsFixed(0)}%\u4E0A\u6DA8)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: moodColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            upCount > downCount
                ? '整体偏多头，市场情绪积极'
                : downCount > upCount
                    ? '整体偏空头，市场情绪谨慎'
                    : '多空均衡，市场处于观望状态',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      int activeMarkets, int totalCount, int upCount, int downCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On very small screens (iPhone SE), use 2+1 layout
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: '活跃市场',
                      value: '$activeMarkets',
                      icon: Icons.show_chart_rounded,
                      iconColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      title: '总判断',
                      value: '$totalCount',
                      icon: Icons.analytics_outlined,
                      iconColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MetricCard(
                title: '看涨/看跌',
                value: '$upCount / $downCount',
                icon: Icons.swap_vert_rounded,
                iconColor:
                    upCount >= downCount ? AppTheme.upGreen : AppTheme.downRed,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: MetricCard(
                title: '活跃市场',
                value: '$activeMarkets',
                icon: Icons.show_chart_rounded,
                iconColor: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                title: '总判断',
                value: '$totalCount',
                icon: Icons.analytics_outlined,
                iconColor: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                title: '看涨/看跌',
                value: '$upCount / $downCount',
                icon: Icons.swap_vert_rounded,
                iconColor:
                    upCount >= downCount ? AppTheme.upGreen : AppTheme.downRed,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '实时 AI 信号',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSignalCard(BuildContext context, Judgment j,
      {bool isFavorite = false, VoidCallback? onToggleFavorite}) {
    // Extract rational price from model votes or top-level field
    String priceStr = '--';
    if (j.rationalPrice != null) {
      priceStr = j.rationalPrice!.toStringAsFixed(2);
    } else if (j.modelVotes != null && j.modelVotes!.isNotEmpty) {
      final priceVote =
          j.modelVotes!.where((v) => v.rationalPrice != null).toList();
      if (priceVote.isNotEmpty) {
        priceStr = priceVote.first.rationalPrice!.toStringAsFixed(2);
      }
    }

    // Deviation as change percentage string
    String? changePctStr;
    if (j.deviationPct != null) {
      final sign = j.deviationPct! >= 0 ? '+' : '';
      changePctStr = '$sign${j.deviationPct!.toStringAsFixed(2)}%';
    }

    // Extract model name from votes
    String? modelName;
    if (j.modelVotes != null && j.modelVotes!.isNotEmpty) {
      modelName = j.modelVotes!.map((v) => v.modelName).join(' + ');
    }

    return SignalCard(
      symbol: j.symbol ?? '未知',
      price: priceStr,
      changePct: changePctStr,
      direction: j.direction,
      confidence: j.confidenceScore,
      reasoning: j.reasoning,
      modelName: modelName,
      horizonHours: j.horizonHours,
      createdAt: j.createdAt,
      isSettled: j.isSettled,
      isCorrect: j.isCorrect,
      qualityScore: j.qualityScore,
      upProbability: j.upProbability,
      downProbability: j.downProbability,
      flatProbability: j.flatProbability,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onTap: () {
        if (j.symbol != null) {
          context.push('/market/${j.symbol}');
        }
      },
    );
  }
}

/// Mini accuracy ring painter for the evolution card.
class _MiniAccuracyRingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color trackColor;

  _MiniAccuracyRingPainter({
    required this.percentage,
    required this.color,
    this.trackColor = const Color(0xFFF2F2F7),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 8) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage > 0) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      final sweepAngle = (percentage / 100) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniAccuracyRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}

/// Pulsing dot animation for "进化中..." status.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
