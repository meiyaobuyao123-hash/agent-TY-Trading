import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/providers/dashboard_provider.dart';

/// 日报页面 — 简洁报纸式排版，展示每日AI分析汇总。
class DailyReportPage extends ConsumerWidget {
  const DailyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dailyReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      appBar: AppBar(
        title: const Text(
          '日报',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
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
              Text('加载失败', style: TextStyle(color: AppTheme.textSecondary)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题区
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      data['date'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 情绪指示
                _buildMoodIndicator(mood, upCount, downCount, flatCount),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 核心数据卡片
          Row(
            children: [
              Expanded(child: _buildStatCard('覆盖', '$marketsAnalyzed/$totalMarkets', '市场')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('准确率', '${accuracyToday.toStringAsFixed(1)}%', '今日结算')),
            ],
          ),

          const SizedBox(height: 16),

          // 报告正文
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '完整报告',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 16),
                SelectableText(
                  report,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Menlo, monospace',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMoodIndicator(String mood, int up, int down, int flat) {
    Color moodColor;
    IconData moodIcon;
    if (mood.contains('乐观')) {
      moodColor = AppTheme.upGreen;
      moodIcon = Icons.trending_up;
    } else if (mood.contains('悲观')) {
      moodColor = AppTheme.downRed;
      moodIcon = Icons.trending_down;
    } else {
      moodColor = AppTheme.flatGray;
      moodIcon = Icons.trending_flat;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: moodColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(moodIcon, size: 16, color: moodColor),
              const SizedBox(width: 6),
              Text(
                mood,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: moodColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '涨$up / 跌$down / 平$flat',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
