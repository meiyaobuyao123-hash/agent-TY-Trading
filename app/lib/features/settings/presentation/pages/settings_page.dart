import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Settings page — iOS Settings grouped list style.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _triggering = false;
  String? _triggerResult;

  Future<void> _triggerJudgment() async {
    setState(() {
      _triggering = true;
      _triggerResult = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/judgments/trigger',
          data: {'horizon_hours': 4});
      final triggered = response.data['triggered'] ?? 0;
      setState(() {
        _triggerResult = '成功触发 $triggered 个判断';
      });
    } on DioException catch (e) {
      setState(() {
        _triggerResult = '失败: ${e.message}';
      });
    } finally {
      setState(() {
        _triggering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的',
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Section: 系统
          _sectionHeader('系统'),
          _groupedContainer([
            _settingsRow(
              icon: Icons.dns_outlined,
              title: '服务器地址',
              subtitle: ApiConfig.baseUrl,
            ),
            _settingsRow(
              icon: Icons.play_circle_outline,
              title: '触发判断',
              subtitle: _triggering
                  ? '触发中...'
                  : (_triggerResult ?? '手动触发一次AI判断周期'),
              trailing: _triggering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.chevron_right,
                      color: AppTheme.divider, size: 18),
              onTap: _triggering ? null : _triggerJudgment,
              subtitleColor: _triggerResult != null
                  ? (_triggerResult!.startsWith('失败')
                      ? AppTheme.downRed
                      : AppTheme.upGreen)
                  : null,
            ),
          ]),

          // Section: 关于
          _sectionHeader('关于'),
          _groupedContainer([
            _settingsRow(
              icon: Icons.info_outline,
              title: '版本',
              subtitle: '1.0.0',
            ),
            _settingsRow(
              icon: Icons.code,
              title: 'GitHub',
              subtitle: 'github.com/TY-Trading',
            ),
            _settingsRow(
              icon: Icons.description_outlined,
              title: '项目介绍',
              subtitle: '天演 — AI金融世界模型，每4小时多模型共识判断',
            ),
          ]),

          // Section: 设置
          _sectionHeader('设置'),
          _groupedContainer([
            _settingsRow(
              icon: Icons.notifications_outlined,
              title: '通知设置',
              subtitle: '即将推出',
            ),
            _settingsRow(
              icon: Icons.language,
              title: '语言',
              subtitle: '简体中文',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _groupedContainer(List<Widget> children) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 0.5, color: AppTheme.divider),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor ?? AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
