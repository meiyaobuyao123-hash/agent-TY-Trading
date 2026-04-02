import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Settings page — Apple-style flat, minimalist, tech-forward.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _triggering = false;
  String? _triggerResult;
  int _triggerMarketCount = 0;

  // Health data
  bool _serverOnline = false;
  int _activePlugins = 0;
  String _aiModel = '--';
  String _backendVersion = '--';
  bool _healthLoading = true;
  List<_PluginInfo> _pluginList = [];
  bool _pluginsExpanded = false;

  // Data coverage
  int _totalMarkets = 0;
  int _marketsWithData = 0;
  double _coveragePct = 0.0;
  List<_TypeCoverage> _typeCoverages = [];
  bool _coverageLoading = true;
  bool _coverageExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchHealth();
    _fetchCoverage();
  }

  Future<void> _fetchHealth() async {
    setState(() => _healthLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/health');
      final data = response.data;
      final plugins = data['plugins'] as Map<String, dynamic>? ?? {};

      // Count active plugins (those with healthy: true)
      int active = 0;
      String aiName = '--';
      final pluginInfos = <_PluginInfo>[];
      for (final entry in plugins.entries) {
        final info = entry.value as Map<String, dynamic>? ?? {};
        final isHealthy = info['healthy'] == true;
        if (isHealthy) active++;
        pluginInfos.add(_PluginInfo(
          name: entry.key,
          healthy: isHealthy,
        ));
        // Detect AI model plugins
        if (entry.key.contains('deepseek') ||
            entry.key.contains('ai-consensus')) {
          aiName = 'DeepSeek';
        }
      }

      setState(() {
        _serverOnline = data['status'] == 'ok';
        _activePlugins = active;
        _aiModel = aiName;
        _backendVersion = data['version'] as String? ?? '--';
        _pluginList = pluginInfos;
        _healthLoading = false;
      });
    } catch (_) {
      setState(() {
        _serverOnline = false;
        _activePlugins = 0;
        _aiModel = '--';
        _backendVersion = '--';
        _pluginList = [];
        _healthLoading = false;
      });
    }
  }

  Future<void> _fetchCoverage() async {
    setState(() => _coverageLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/stats/data-coverage');
      final data = response.data;
      final byType = (data['by_type'] as List<dynamic>?) ?? [];

      setState(() {
        _totalMarkets = data['total_markets'] as int? ?? 0;
        _marketsWithData = data['markets_with_data'] as int? ?? 0;
        _coveragePct = (data['coverage_pct'] as num?)?.toDouble() ?? 0.0;
        _typeCoverages = byType.map((t) {
          final m = t as Map<String, dynamic>;
          return _TypeCoverage(
            marketType: m['market_type'] as String? ?? '',
            total: m['total'] as int? ?? 0,
            withData: m['with_data'] as int? ?? 0,
            coveragePct: (m['coverage_pct'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
        _coverageLoading = false;
      });
    } catch (_) {
      setState(() {
        _coverageLoading = false;
      });
    }
  }

  Future<void> _triggerJudgment() async {
    setState(() {
      _triggering = true;
      _triggerResult = null;
      _triggerMarketCount = 0;
    });

    try {
      final dio = ref.read(dioProvider);

      // 先获取活跃市场数量，用于显示进度
      try {
        final marketsResp = await dio.get('/stats/overview');
        setState(() {
          _triggerMarketCount =
              marketsResp.data['markets_tracked'] as int? ?? 0;
        });
      } catch (_) {
        // 忽略，使用默认值
      }

      final response = await dio.post(
        '/judgments/trigger',
        data: {'horizon_hours': 4},
        options: Options(
          headers: {'X-API-Key': 'ty-2026-secret-key'},
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      final triggered = response.data['triggered'] ?? 0;
      setState(() {
        _triggerResult = '完成: 成功分析 $triggered 个市场';
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message ?? '未知错误';
      setState(() {
        _triggerResult = '失败: $msg';
      });
    } finally {
      setState(() {
        _triggering = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            // ── Large title header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 4),
              child: Text(
                '设置',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),

            // ── Section: 系统状态 ──
            _sectionHeader('系统状态'),
            _groupedContainer([
              _settingsRow(
                icon: Icons.dns_rounded,
                iconColor:
                    _serverOnline ? AppTheme.upGreen : AppTheme.downRed,
                title: '服务器',
                value: _healthLoading
                    ? '检测中...'
                    : (_serverOnline ? '在线' : '离线'),
                leading: _statusDot(_serverOnline),
              ),
              _settingsRow(
                icon: Icons.cloud_outlined,
                iconColor: AppTheme.primary,
                title: '数据源',
                value: _healthLoading
                    ? '加载中...'
                    : '$_activePlugins 个活跃',
              ),
              _settingsRow(
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFF8E44AD),
                title: 'AI 模型',
                value: _healthLoading ? '加载中...' : _aiModel,
              ),
            ]),

            // ── Section: 数据覆盖率 ──
            _sectionHeader('数据覆盖率'),
            _groupedContainer([
              _settingsRow(
                icon: Icons.satellite_alt_rounded,
                iconColor: const Color(0xFF10B981),
                title: '实时数据',
                value: _coverageLoading
                    ? '加载中...'
                    : '$_totalMarkets个市场中$_marketsWithData个有实时数据',
              ),
              _settingsRow(
                icon: Icons.pie_chart_rounded,
                iconColor: AppTheme.primary,
                title: '覆盖率',
                value: _coverageLoading
                    ? '加载中...'
                    : '${_coveragePct.toStringAsFixed(1)}%',
                valueColor: _coveragePct >= 90
                    ? AppTheme.upGreen
                    : _coveragePct >= 70
                        ? const Color(0xFFFFCC00)
                        : AppTheme.downRed,
              ),
              _settingsRow(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF6366F1),
                title: '按类型查看',
                value: _coverageLoading
                    ? '加载中...'
                    : '${_typeCoverages.length} 个类型',
                trailing: Icon(
                  _coverageExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppTheme.flatGray,
                  size: 20,
                ),
                onTap: () =>
                    setState(() => _coverageExpanded = !_coverageExpanded),
              ),
            ]),

            // Expanded coverage breakdown
            if (_coverageExpanded && _typeCoverages.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColorOf(context),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: _typeCoverages.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.marketType,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${t.withData}/${t.total}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${t.coveragePct.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: t.coveragePct >= 90
                                    ? AppTheme.upGreen
                                    : t.coveragePct >= 70
                                        ? const Color(0xFFFFCC00)
                                        : AppTheme.downRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Section: 操作 ──
            _sectionHeader('操作'),
            _groupedContainer([
              _settingsRow(
                icon: Icons.play_arrow_rounded,
                iconColor: AppTheme.primary,
                title: '触发AI判断',
                value: _triggering
                    ? (_triggerMarketCount > 0
                        ? '正在分析$_triggerMarketCount个市场...'
                        : '准备中...')
                    : (_triggerResult ?? '手动执行一次判断周期'),
                valueColor: _triggerResult != null
                    ? (_triggerResult!.startsWith('失败')
                        ? AppTheme.downRed
                        : AppTheme.upGreen)
                    : _triggering
                        ? AppTheme.primary
                        : null,
                trailing: _triggering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.flatGray, size: 20),
                onTap: _triggering ? null : _triggerJudgment,
              ),
            ]),

            // ── Section: 开源共建 ──
            _sectionHeader('开源共建'),
            _groupedContainer([
              _settingsRow(
                icon: Icons.code_rounded,
                iconColor: AppTheme.textPrimary,
                title: 'GitHub',
                value: '查看源代码',
                trailing: const Icon(Icons.open_in_new_rounded,
                    color: AppTheme.flatGray, size: 16),
                onTap: () =>
                    _openUrl('https://github.com/project-ty/tianyan'),
              ),
              _settingsRow(
                icon: Icons.menu_book_rounded,
                iconColor: AppTheme.primary,
                title: '贡献指南',
                value: '参与共建',
                trailing: const Icon(Icons.open_in_new_rounded,
                    color: AppTheme.flatGray, size: 16),
                onTap: () => _openUrl(
                    'https://github.com/project-ty/tianyan/blob/main/CONTRIBUTING_zh.md'),
              ),
              _settingsRow(
                icon: Icons.extension_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: '插件架构',
                subtitle: '支持自定义数据源和AI模型',
              ),
              _settingsRow(
                icon: Icons.widgets_rounded,
                iconColor: const Color(0xFF10B981),
                title: '当前插件',
                value: _healthLoading
                    ? '加载中...'
                    : '${_pluginList.length} 个',
                trailing: Icon(
                  _pluginsExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppTheme.flatGray,
                  size: 20,
                ),
                onTap: () =>
                    setState(() => _pluginsExpanded = !_pluginsExpanded),
              ),
            ]),

            // Expanded plugin list
            if (_pluginsExpanded && _pluginList.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColorOf(context),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: _pluginList.map((p) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.healthy
                                  ? AppTheme.upGreen
                                  : AppTheme.downRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            p.healthy ? '正常' : '异常',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.healthy
                                  ? AppTheme.upGreen
                                  : AppTheme.downRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Section: 关于 ──
            _sectionHeader('关于'),
            _groupedContainer([
              _settingsRow(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.flatGray,
                title: '版本',
                value: '3.0.0 (Build 30)',
              ),
              _settingsRow(
                icon: Icons.dns_outlined,
                iconColor: AppTheme.primary,
                title: '后端版本',
                value: _healthLoading ? '加载中...' : _backendVersion,
              ),
              _settingsRow(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: '项目',
                value: '天演 -- AI金融世界模型',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Section header ──
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Grouped rounded container ──
  Widget _groupedContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColorOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(
                    height: 0.5,
                    color: AppTheme.divider,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Green/red status dot ──
  Widget _statusDot(bool isOnline) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.upGreen : AppTheme.downRed,
        shape: BoxShape.circle,
      ),
    );
  }

  // ── Single settings row ──
  Widget _settingsRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? value,
    Widget? trailing,
    Widget? leading,
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon in tinted circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            // Title + optional subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Optional leading widget (e.g. status dot)
            ?leading,
            // Value text
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            // Trailing widget (chevron, spinner, etc.)
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

class _PluginInfo {
  final String name;
  final bool healthy;

  _PluginInfo({required this.name, required this.healthy});
}

class _TypeCoverage {
  final String marketType;
  final int total;
  final int withData;
  final double coveragePct;

  _TypeCoverage({
    required this.marketType,
    required this.total,
    required this.withData,
    required this.coveragePct,
  });
}
