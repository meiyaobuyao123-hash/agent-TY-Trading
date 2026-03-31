import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../providers/dashboard_provider.dart';
import '../widgets/judgment_card.dart';

/// Dashboard page showing latest AI judgments across all markets.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final judgments = ref.watch(latestJudgmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              '天演',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'AI金融世界模型',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: AppTheme.divider,
          ),
        ),
      ),
      body: judgments.when(
        loading: () => const LoadingWidget(message: '加载判断中...'),
        error: (err, _) => AppErrorWidget(
          message: '加载失败:\n$err',
          onRetry: () => ref.invalidate(latestJudgmentsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                '暂无判断\n等待AI分析周期',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(latestJudgmentsProvider);
              await ref.read(latestJudgmentsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 0, bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(
                height: 0.5,
                indent: 72,
                color: AppTheme.divider,
              ),
              itemBuilder: (context, index) =>
                  JudgmentCard(judgment: list[index]),
            ),
          );
        },
      ),
    );
  }
}
