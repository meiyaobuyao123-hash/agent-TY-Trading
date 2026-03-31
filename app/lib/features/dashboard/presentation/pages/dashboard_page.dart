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
              'TY 天演',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.accent,
              ),
            ),
            Text(
              'AI Financial World Model',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: judgments.when(
        loading: () => const LoadingWidget(message: 'Loading judgments...'),
        error: (err, _) => AppErrorWidget(
          message: 'Failed to load judgments:\n$err',
          onRetry: () => ref.invalidate(latestJudgmentsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No judgments yet.\nWaiting for AI analysis cycle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () async {
              ref.invalidate(latestJudgmentsProvider);
              await ref.read(latestJudgmentsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: list.length,
              itemBuilder: (context, index) =>
                  JudgmentCard(judgment: list[index]),
            ),
          );
        },
      ),
    );
  }
}
