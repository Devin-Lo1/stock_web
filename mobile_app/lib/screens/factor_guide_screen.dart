import 'package:flutter/material.dart';

import '../utils/theme_helpers.dart';
import '../widgets/common/page_title.dart';

class FactorGuideScreen extends StatelessWidget {
  const FactorGuideScreen({super.key});

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
            _FactorCard(
              title: '放量突破',
              subtitle: '价格突破近期区间，同时成交量明显放大。',
              usage: '适合发现资金参与的趋势启动，也可用作组合因子的确认项。',
            ),
            _FactorCard(
              title: '跌破均线止损',
              subtitle: '收盘价跌破指定均线或带缓冲的止损线。',
              usage: '适合持仓风险提醒，尤其是已有利润但趋势变弱时。',
            ),
            _FactorCard(
              title: 'ATR 动态止损',
              subtitle: '用真实波幅衡量正常波动，跟随高点生成动态止损线。',
              usage: '适合波动较大的股票，避免固定百分比止损过死。',
            ),
            _FactorCard(
              title: 'RSI 超跌反弹',
              subtitle: 'RSI 从超卖区重新上穿，提示短线反弹可能。',
              usage: '适合震荡或急跌后的观察，不适合单独追强趋势。',
            ),
            _FactorCard(
              title: '趋势评分',
              subtitle: '综合价格位置、均线斜率、动量和成交量，得到 0-4 分。',
              usage: '适合做趋势强弱过滤，也适合和放量突破组合。',
            ),
            _FactorCard(
              title: '组合因子',
              subtitle: '选择多个因子，按“全部确认”或“任一触发”生成复合信号。',
              usage: '更推荐“全部确认”，信号更少但更稳；确认窗口越大，条件越宽松。',
            ),
            _NoticeCard(),
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
          child: PageTitle(title: '因子说明', subtitle: '策略监控、回测与组合因子使用说明'),
        ),
      ],
    );
  }
}

class _FactorCard extends StatelessWidget {
  const _FactorCard({
    required this.title,
    required this.subtitle,
    required this.usage,
  });

  final String title;
  final String subtitle;
  final String usage;

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
            subtitle,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            usage,
            style: TextStyle(color: primaryTextColor(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Text(
        '使用注意：策略信号是观察提醒，不是自动交易指令。创建监控后建议先用“扫描一次”检查日志；如果行情刷新失败，会使用本地缓存并在扫描日志里记录原因。组合因子越多，信号越少；确认窗口越大，信号越宽松。',
        style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
      ),
    );
  }
}
