import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Signal strength indicator — 1-5 bars like WiFi/cell signal.
/// Maps confidence 0-1 to bars: 0-20%=1, 20-40%=2, 40-60%=3, 60-80%=4, 80-100%=5.
/// Colors: 1-2 bars gray, 3 bars yellow, 4-5 bars green.
class SignalStrength extends StatelessWidget {
  final double confidence;
  final double barWidth;
  final double barSpacing;
  final double maxBarHeight;

  const SignalStrength({
    super.key,
    required this.confidence,
    this.barWidth = 4,
    this.barSpacing = 2,
    this.maxBarHeight = 16,
  });

  int get _bars {
    final pct = (confidence * 100).clamp(0.0, 100.0);
    if (pct >= 80) return 5;
    if (pct >= 60) return 4;
    if (pct >= 40) return 3;
    if (pct >= 20) return 2;
    return 1;
  }

  Color get _activeColor {
    final bars = _bars;
    if (bars >= 4) return AppTheme.upGreen;
    if (bars == 3) return const Color(0xFFFFCC00);
    return AppTheme.flatGray;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final color = _activeColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final barIndex = i + 1;
        final isActive = barIndex <= bars;
        final height = maxBarHeight * (0.3 + 0.7 * barIndex / 5);

        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? barSpacing : 0),
          child: Container(
            width: barWidth,
            height: height,
            decoration: BoxDecoration(
              color: isActive ? color : AppTheme.divider,
              borderRadius: BorderRadius.circular(barWidth / 2),
            ),
          ),
        );
      }),
    );
  }
}
