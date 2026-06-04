import 'package:flutter/material.dart';

import '../utils/theme_helpers.dart';
import '../widgets/common/page_title.dart';
import 'data_guide_screen.dart';
import 'factor_guide_screen.dart';
import 'personalized_strategy_guide_screen.dart';

class DocumentationScreen extends StatelessWidget {
  const DocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            const _Header(),
            const SizedBox(height: 12),
            _DocumentTile(
              icon: Icons.psychology_alt_rounded,
              title: '专属策略信号说明',
              subtitle: '今天/昨天信号、空仓/持多/持空动作口径',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const PersonalizedStrategyGuideScreen(),
                ),
              ),
            ),
            _DocumentTile(
              icon: Icons.menu_book_outlined,
              title: '因子说明',
              subtitle: '策略因子、组合因子与使用注意',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const FactorGuideScreen(),
                ),
              ),
            ),
            _DocumentTile(
              icon: Icons.dataset_outlined,
              title: '数据说明',
              subtitle: '行情、收益、资金流和推送口径',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const DataGuideScreen(),
                ),
              ),
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
          child: PageTitle(title: '说明文档', subtitle: '信号、因子和数据口径集中入口'),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor(context)),
            ),
            child: Row(
              children: [
                Icon(icon, color: appAccentColor(context), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryTextColor(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: secondaryTextColor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
