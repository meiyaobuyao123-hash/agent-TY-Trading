import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/providers/dashboard_provider.dart';

/// 日报页面 — 视觉丰富版，大标题+数据卡片+信号卡片+分享按钮。
class DailyReportPage extends ConsumerWidget {
  const DailyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dailyReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          '日报',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryOf(context)),
        actions: [
          reportAsync.maybeWhen(
            data: (data) => IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: '复制报告',
              onPressed: () {
                final report = data['report'] as String? ?? '';
                Clipboard.setData(ClipboardData(text: report));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('日报已复制到剪贴板'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text('生成日报中...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.flatGray),
              const SizedBox(height: 12),
              const Text('加载失败', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(dailyReportProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) => _buildReport(context, data),
      ),
    );
  }

  Widget _buildReport(BuildContext context, Map<String, dynamic> data) {
    final report = data['report'] as String? ?? '暂无数据';
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final mood = stats['mood'] as String? ?? '中性';
    final marketsAnalyzed = stats['markets_analyzed'] as int? ?? 0;
    final totalMarkets = stats['total_markets'] as int? ?? 0;
    final upCount = stats['up_count'] as int? ?? 0;
    final downCount = stats['down_count'] as int? ?? 0;
    final flatCount = stats['flat_count'] as int? ?? 0;
    final accuracyToday = (stats['accuracy_today'] as num?)?.toDouble() ?? 0.0;
    final topSignals = (stats['top_signals'] as List<dynamic>?) ?? [];
    final dateStr = data['date'] as String? ?? '';

    // Determine mood emoji and color
    String moodEmoji;
    Color moodColor;
    String moodLabel;
    if (mood.contains('乐观') || mood.contains('贪婪')) {
      moodEmoji = '\u{1F4C8}';
      moodColor = AppTheme.upGreen;
      moodLabel = '市场偏多';
    } else if (mood.contains('悲观') || mood.contains('恐慌')) {
      moodEmoji = '\u{1F4C9}';
      moodColor = AppTheme.downRed;
      moodLabel = '市场偏空';
    } else {
      moodEmoji = '\u{2696}\u{FE0F}';
      moodColor = AppTheme.flatGray;
      moodLabel = '市场中性';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 头部: 大标题 + 情绪 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  moodColor.withValues(alpha: 0.08),
                  moodColor.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: moodColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date row
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 12),
                // Big mood headline
                Row(
                  children: [
                    Text(
                      moodEmoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moodLabel,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryOf(context),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '涨 $upCount  跌 $downCount  平 $flatCount',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 关键数据行 ──
          Row(
            children: [
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.analytics_outlined,
                  iconColor: AppTheme.primary,
                  label: '已分析',
                  value: '$marketsAnalyzed',
                  sub: '/$totalMarkets 市场',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppTheme.upGreen,
                  label: '看涨信号',
                  value: '$upCount',
                  sub: '个市场',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMiniCard(
                  icon: Icons.trending_down_rounded,
                  iconColor: AppTheme.downRed,
                  label: '看跌信号',
                  value: '$downCount',
                  sub: '个市场',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Accuracy card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: accuracyToday > 50 ? AppTheme.upGreen : AppTheme.flatGray),
                const SizedBox(width: 10),
                Text(
                  '今日结算准确率',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${accuracyToday.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accuracyToday > 50 ? AppTheme.upGreen : AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Top 3 信号卡片 ──
          if (topSignals.isNotEmpty) ...[
            Text(
              '今日重点信号',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 10),
            ...topSignals.take(3).map((sig) {
              final sigMap = sig as Map<String, dynamic>;
              final sym = sigMap['symbol'] as String? ?? '';
              final dir = sigMap['direction'] as String? ?? 'flat';
              final conf = (sigMap['confidence_score'] as num?)?.toDouble() ?? 0.0;
              final reasoning = sigMap['reasoning'] as String? ?? '';

              Color dirColor;
              IconData dirIcon;
              String dirLabel;
              if (dir == 'up') {
                dirColor = AppTheme.upGreen;
                dirIcon = Icons.arrow_upward_rounded;
                dirLabel = '看涨';
              } else if (dir == 'down') {
                dirColor = AppTheme.downRed;
                dirIcon = Icons.arrow_downward_rounded;
                dirLabel = '看跌';
              } else {
                dirColor = AppTheme.flatGray;
                dirIcon = Icons.remove_rounded;
                dirLabel = '观望';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColorOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: dirColor.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: dirColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(dirIcon, size: 16, color: dirColor),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sym,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dirColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$dirLabel ${(conf * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dirColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reasoning.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasoning.length > 100
                            ? '${reasoning.substring(0, 100)}...'
                            : reasoning,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // ── 完整报告 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColorOf(context),
              borderRadius: BorderRadius.circular(16),
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
                    Icon(Icons.article_outlined, size: 16,
                        color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 6),
                    Text(
                      '完整报告',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.dividerOf(context)),
                const SizedBox(height: 16),
                SelectableText(
                  report,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: AppTheme.textPrimaryOf(context),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 分享日报按钮 ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                final shareText = '天演AI日报 $dateStr\n$moodLabel\n\n$report';
                Share.share(shareText);
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text(
                '分享日报',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Mini stat card used in the key stats row.
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _StatMiniCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColorOf(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
