import 'package:flutter/material.dart';

import '../utils/theme_helpers.dart';
import '../widgets/common/page_title.dart';

class DataGuideScreen extends StatelessWidget {
  const DataGuideScreen({super.key});

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
              icon: Icons.show_chart_rounded,
              title: '行情与 K 线',
              body:
                  'App 通过后端 FastAPI 访问 FutuOpenD 和 futu-api。K 线会写入本地后端缓存；策略扫描可选择刷新行情，刷新失败时会使用缓存并在扫描日志里说明原因。',
            ),
            _GuideCard(
              icon: Icons.account_balance_wallet_outlined,
              title: '持仓收益',
              body:
                  '持仓数量、摊薄成本、已实现盈亏、当日收益、持有收益和总收益以后端持仓快照为准。加仓、减仓和清仓会先写入交易历史，再由后端重新计算持仓指标。',
            ),
            _GuideCard(
              icon: Icons.waterfall_chart_rounded,
              title: '今日资金流向',
              body:
                  '资金流向来自 Futu OpenD 的资金分布和日内资金流接口，页面按“万元”展示，并将超大单和大单合并为“大单”。不同券商或行情 App 的大中小单阈值、刷新时间和数据供应商不同，因此数字可能不完全一致。',
            ),
            _GuideCard(
              icon: Icons.science_outlined,
              title: '回测与策略监控',
              body:
                  '回测、单股监控和组合因子共用后端策略实现。策略信号只代表观察提醒，不是买卖指令；创建监控后建议先执行一次扫描，并查看扫描日志确认行情、样本和触发原因。',
            ),
            _GuideCard(
              icon: Icons.notifications_active_outlined,
              title: '推送与历史信号',
              body:
                  '策略扫描先生成历史信号，再按设备开关、推送候选、重要通知开关和去重规则写入推送记录。真实推送需要后端生产通道配置完成，未配置时只会记录跳过原因。',
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
          child: PageTitle(title: '数据说明', subtitle: '行情、收益、资金流和推送口径'),
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
        '使用注意：本 App 是个人持仓和策略观察工具，不提供投资建议。遇到行情超时、资金流差异或推送跳过时，优先查看数据说明、扫描日志和推送记录，再决定是否调整监控配置。',
        style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
      ),
    );
  }
}
