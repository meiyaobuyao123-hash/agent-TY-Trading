import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import 'signal_strength.dart';

/// Market signal card for the dashboard — direction + reasoning as hero content.
/// Designed for non-technical users: Chinese market names, plain language.
class SignalCard extends StatelessWidget {
  final String symbol;
  final String? name;
  final String price;
  final String? changePct;
  final String direction;
  final double confidence;
  final String? reasoning;
  final String? modelName;
  final int? horizonHours;
  final DateTime? createdAt;
  final bool? isSettled;
  final bool? isCorrect;
  final double? qualityScore;
  final double? upProbability;
  final double? downProbability;
  final double? flatProbability;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const SignalCard({
    super.key,
    required this.symbol,
    this.name,
    required this.price,
    this.changePct,
    required this.direction,
    required this.confidence,
    this.reasoning,
    this.modelName,
    this.horizonHours,
    this.createdAt,
    this.isSettled,
    this.isCorrect,
    this.qualityScore,
    this.upProbability,
    this.downProbability,
    this.flatProbability,
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
  });

  /// Strip "[model_name] " prefix from reasoning text.
  static String cleanReasoning(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'\[[\w-]+\]\s*'), '')
        .replaceAll(RegExp(r'\s*\|\s*'), '\n\n')
        .trim();
  }

  /// Map symbol to Chinese name for common markets.
  static String _chineseName(String symbol) {
    const nameMap = {
      'BTC-USD': '比特币 BTC',
      'ETH-USD': '以太坊 ETH',
      'SOL-USD': '索拉纳 SOL',
      'BNB-USD': '币安币 BNB',
      'XRP-USD': '瑞波币 XRP',
      'ADA-USD': '艾达币 ADA',
      'DOGE-USD': '狗狗币 DOGE',
      'DOT-USD': '波卡 DOT',
      'AVAX-USD': '雪崩 AVAX',
      'MATIC-USD': '多边形 MATIC',
      'LINK-USD': '链环 LINK',
      'UNI-USD': 'Uniswap UNI',
      'AAPL': '苹果 AAPL',
      'MSFT': '微软 MSFT',
      'GOOGL': '谷歌 GOOGL',
      'AMZN': '亚马逊 AMZN',
      'TSLA': '特斯拉 TSLA',
      'NVDA': '英伟达 NVDA',
      'META': 'Meta META',
      'AMD': '超威半导体 AMD',
      'NFLX': '奈飞 NFLX',
      'SPY': '标普500 SPY',
      'QQQ': '纳指100 QQQ',
      'DIA': '道指 DIA',
      'GLD': '黄金ETF GLD',
      'SLV': '白银ETF SLV',
      'TLT': '长期国债 TLT',
      'EUR-USD': '欧元/美元',
      'GBP-USD': '英镑/美元',
      'USD-JPY': '美元/日元',
      'USD-CNY': '美元/人民币',
      'AUD-USD': '澳元/美元',
      'XAU-USD': '黄金',
      'XAG-USD': '白银',
      'CL=F': '原油',
      'GC=F': '黄金期货',
      'SI=F': '白银期货',
      '^GSPC': '标普500指数',
      '^DJI': '道琼斯指数',
      '^IXIC': '纳斯达克指数',
      '^HSI': '恒生指数',
      '000001.SS': '上证指数',
      '399001.SZ': '深证成指',
      // 日股
      '7203.JP': '丰田汽车',
      '6758.JP': '索尼集团',
      '6861.JP': '基恩士',
      '9984.JP': '软银集团',
      '8306.JP': '三菱日联',
      // 欧股
      'SAP.DE': 'SAP 思爱普',
      'SIE.DE': '西门子',
      'BMW.DE': '宝马',
      'ASML.NL': 'ASML 阿斯麦',
      'MC.PA': 'LVMH 路威酩轩',
      'TTE.PA': '道达尔能源',
    };
    return nameMap[symbol] ?? symbol;
  }

  @override
  Widget build(BuildContext context) {
    final isUp = direction.toLowerCase() == 'up';
    final isDown = direction.toLowerCase() == 'down';
    final dirColor = isUp
        ? AppTheme.upGreen
        : isDown
            ? AppTheme.downRed
            : AppTheme.flatGray;
    final dirText = isUp ? '看涨' : isDown ? '看跌' : '观望';
    final dirArrow = isUp ? ' ↑' : isDown ? ' ↓' : ' →';

    final cleanedReasoning = cleanReasoning(reasoning);
    final displayName = _chineseName(symbol);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: star + name + quality + share/help ──
            Row(
              children: [
                // Star icon
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
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
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: AppTheme.textPrimaryOf(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Quality badge
                      if (qualityScore != null && qualityScore! >= 0.7) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.upGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '高质量',
                            style: TextStyle(
                              color: AppTheme.upGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _shareSignal(),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.ios_share_rounded,
                        size: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showFieldExplanation(context),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.divider,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: HERO — Direction prominently in Chinese ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dirColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI预测: $dirText$dirArrow',
                      style: TextStyle(
                        color: dirColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Settlement status
                  if (isSettled == true) ...[
                    Icon(
                      isCorrect == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                      color: isCorrect == true
                          ? AppTheme.upGreen
                          : AppTheme.downRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCorrect == true ? '判断正确' : '判断错误',
                      style: TextStyle(
                        color: isCorrect == true
                            ? AppTheme.upGreen
                            : AppTheme.downRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        horizonHours != null
                            ? '${horizonHours}h后验证'
                            : '待验证',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Probability bars ──
            if (upProbability != null &&
                downProbability != null &&
                flatProbability != null) ...[
              const SizedBox(height: 10),
              _buildProbabilityBars(context),
            ],

            const SizedBox(height: 10),

            // ── Row 3: AI reasoning — HERO content, first thing to read ──
            if (cleanedReasoning.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(
                      color: AppTheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  cleanedReasoning,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // ── Row 4: Fair price with context ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '合理价格',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$$price',
                      style: AppTheme.largeNumber,
                    ),
                  ],
                ),
                if (changePct != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _deviationContext(),
                      style: TextStyle(
                        color: isUp
                            ? AppTheme.upGreen
                            : isDown
                                ? AppTheme.downRed
                                : AppTheme.flatGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),

            const SizedBox(height: 10),

            // ── Row 5: signal strength + model + time ──
            Row(
              children: [
                const Text(
                  '信号强度',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                SignalStrength(confidence: confidence),
                const SizedBox(width: 8),
                Text(
                  'AI把握度 ${(confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (modelName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      modelName!,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (createdAt != null)
                  Text(
                    DateFormat('MM/dd HH:mm').format(createdAt!.toLocal()),
                    style: const TextStyle(
                      color: AppTheme.flatGray,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build probability distribution bars (green=up, red=down, gray=flat).
  Widget _buildProbabilityBars(BuildContext context) {
    final up = (upProbability! * 100).round();
    final down = (downProbability! * 100).round();
    final flat = (flatProbability! * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels row
        Text(
          '看涨$up%  看跌$down%  观望$flat%',
          style: TextStyle(
            color: AppTheme.textSecondaryOf(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        // Stacked bars
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                if (upProbability! > 0)
                  Flexible(
                    flex: up.clamp(1, 100),
                    child: Container(color: AppTheme.upGreen),
                  ),
                if (downProbability! > 0)
                  Flexible(
                    flex: down.clamp(1, 100),
                    child: Container(color: AppTheme.downRed),
                  ),
                if (flatProbability! > 0)
                  Flexible(
                    flex: flat.clamp(1, 100),
                    child: Container(color: AppTheme.flatGray),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build a context string for the deviation, e.g. "当前偏高2.1%"
  String _deviationContext() {
    if (changePct == null) return '';
    // Parse the changePct string (e.g. "+1.80%" or "-2.30%")
    final cleaned = changePct!.replaceAll('%', '').trim();
    final val = double.tryParse(cleaned);
    if (val == null) return '价格偏离 $changePct';
    if (val > 0) {
      return '当前偏低${val.abs().toStringAsFixed(1)}%';
    } else if (val < 0) {
      return '当前偏高${val.abs().toStringAsFixed(1)}%';
    }
    return '价格接近合理水平';
  }

  void _shareSignal() {
    final directionCn = direction.toLowerCase() == 'up'
        ? '看涨'
        : direction.toLowerCase() == 'down'
            ? '看跌'
            : '观望';
    final confPct = (confidence * 100).toStringAsFixed(0);
    final reasoningSnippet = cleanReasoning(reasoning);
    final snippet = reasoningSnippet.length > 50
        ? '${reasoningSnippet.substring(0, 50)}...'
        : reasoningSnippet;
    final displayName = _chineseName(symbol);

    final text =
        '天演AI信号 | $displayName $directionCn (把握度$confPct%) | 合理价格 \$$price | 分析: $snippet';
    Share.share(text);
  }

  void _showFieldExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
            const SizedBox(height: 20),
            Text(
              '看懂信号卡',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            _explainRow('AI预测方向', '看涨/看跌/观望',
                'AI对未来价格走势的判断。绿色看涨表示预计上涨，红色看跌表示预计下跌。'),
            _explainRow('AI分析', '灰色文本区',
                'AI模型对当前市场状况的分析推理，解释为什么做出这个判断。'),
            _explainRow('合理价格', '如 \$69,800',
                'AI认为该资产在预测周期内应该值多少钱。'),
            _explainRow('价格偏离', '如 当前偏高2.1%',
                '当前市场价格与AI认为的合理价格之间的差距。偏高意味着可能会跌回来。'),
            _explainRow('信号强度', '1-5格信号条',
                '表示AI对这次判断有多大把握。格数越多越有信心。'),
            _explainRow('验证状态', '待验证/正确/错误',
                '预测到期后，系统自动对比实际走势来检验AI判断是否准确。'),
          ],
        ),
      ),
    );
  }

  Widget _explainRow(String field, String example, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              field,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
