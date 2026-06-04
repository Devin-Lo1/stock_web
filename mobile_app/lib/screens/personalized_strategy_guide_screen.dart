import 'package:flutter/material.dart';

import '../utils/theme_helpers.dart';
import '../widgets/common/page_title.dart';

class PersonalizedStrategyGuideScreen extends StatelessWidget {
  const PersonalizedStrategyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: const [
            _Header(),
            SizedBox(height: 12),
            _GuideCard(
              icon: Icons.today_rounded,
              title: '今天信号',
              body:
                  '今天信号使用当前行情临时代入策略。收盘前 10 分钟以前显示为“预估建议操作”，用于盘中参考；收盘前 10 分钟开始和收盘后显示为“策略信号”，更接近日 K 收盘确认口径。',
            ),
            _GuideCard(
              icon: Icons.history_rounded,
              title: '昨天收盘信号',
              body: '昨天收盘信号只使用上一根已经确认的日 K，适合盘前复盘和制定当天计划。它不会因为盘中价格跳动而变化。',
            ),
            _GuideCard(
              icon: Icons.radar_rounded,
              title: '动作状态',
              body:
                  '做多观察表示当前触发做多入场条件；做空观察表示当前触发做空入场条件；多头退出观察表示持多时应关注减仓或卖出；空头退出观察表示持空时应关注平空。',
            ),
            _GuideCard(
              icon: Icons.account_tree_outlined,
              title: '策略虚拟仓位',
              body:
                  '持有多头或持有空头是策略回放后的虚拟状态，不等于你的真实账户已经持仓。若空仓时看到“持有多头”，通常代表买点已经在前几天出现，当前不是新的入场触发。',
            ),
            _GuideCard(
              icon: Icons.compare_arrows_rounded,
              title: '空仓、持多、持空',
              body:
                  '空仓看“是否可以关注开仓”；持多看“继续持有还是退出观察”；持空看“继续持空还是平空观察”。如果显示暂无退出信号，表示策略没有给出卖出/平空条件，仍需按成本、仓位和止损计划管理。',
            ),
            _GuideCard(
              icon: Icons.warning_amber_rounded,
              title: '使用边界',
              body:
                  '专属策略信号是参考信号，不是自动交易指令。盘中预估信号可能被收盘价修正；行情刷新失败时页面会使用缓存并标注，遇到异常价格或数据不足时不要直接参考。',
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: PageTitle(title: '专属策略信号', subtitle: '实时参考、收盘确认和动作状态口径'),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: appAccentColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 13,
                    height: 1.45,
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
