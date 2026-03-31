import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Settings page with server info, trigger button, and about section.
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
        _triggerResult = 'Triggered $triggered judgments successfully.';
      });
    } on DioException catch (e) {
      setState(() {
        _triggerResult = 'Failed: ${e.message}';
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server URL
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns_outlined, color: AppTheme.accent),
              title: const Text('Server URL'),
              subtitle: const Text(
                ApiConfig.baseUrl,
                style: TextStyle(
                  color: AppTheme.accent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // App version
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.accent),
              title: const Text('App Version'),
              subtitle: const Text('1.0.0'),
            ),
          ),

          const SizedBox(height: 24),

          // Trigger judgment button
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Manually trigger an AI judgment cycle across all active markets.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _triggering ? null : _triggerJudgment,
                    icon: _triggering
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textPrimary,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_triggering
                        ? 'Triggering...'
                        : 'Trigger Judgment Cycle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (_triggerResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _triggerResult!,
                      style: TextStyle(
                        color: _triggerResult!.startsWith('Failed')
                            ? AppTheme.downRed
                            : AppTheme.upGreen,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About TY
          const Text(
            'About TY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TY (天演) — AI Financial World Model',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'An AI system that autonomously perceives, reasons, and evolves '
                    'across all financial markets. Every 4 hours, multiple AI models '
                    '(Claude, GPT-4o, Gemini) reach consensus on market direction, '
                    'confidence, and rational price for each tracked asset.\n\n'
                    'The system tracks its own accuracy and calibration over time, '
                    'enabling continuous self-improvement through evolutionary feedback.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.code, color: AppTheme.flatGray, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'github.com/TY-Trading',
                        style: TextStyle(
                          color: AppTheme.accent.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
