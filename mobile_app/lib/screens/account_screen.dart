import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../utils/theme_helpers.dart';
import 'display_settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: pageBackgroundColor(context),
        title: const Text('我的'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _AccountHeader(),
            const SizedBox(height: 14),
            _MembershipBanner(),
            const SizedBox(height: 14),
            const _AccountMenuTile(
              icon: Icons.notifications_none_rounded,
              title: '消息提醒设置',
            ),
            _AccountMenuTile(
              icon: Icons.view_list_outlined,
              title: '显示设置',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => DisplaySettingsScreen(
                    displayMode: displayMode,
                    onDisplayModeChanged: onDisplayModeChanged,
                    onRefresh: onRefresh,
                  ),
                ),
              ),
            ),
            const _AccountMenuTile(
              icon: Icons.pie_chart_outline_rounded,
              title: '盈亏分析',
            ),
            const _AccountMenuTile(
              icon: Icons.emoji_events_outlined,
              title: '策略实盘记录',
            ),
            const SizedBox(height: 12),
            const _AccountMenuTile(
              icon: Icons.mail_outline_rounded,
              title: '建议反馈',
            ),
            const _AccountMenuTile(
              icon: Icons.info_outline_rounded,
              title: '关于我们',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: softCardColor(context),
            child: Icon(
              Icons.person_rounded,
              color: primaryTextColor(context),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用户 812690',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'AIquant 已陪伴您 91 天',
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: mutedIconColor(context)),
        ],
      ),
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A2E17) : const Color(0xFFFFF2CC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8B6B2C)),
      ),
      child: const Row(
        children: [
          Icon(Icons.diamond_outlined, color: Color(0xFFF6C76B)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '开通会员',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '查看会员专属权限',
            style: TextStyle(color: Color(0xFFF6C76B), fontSize: 13),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFFF6C76B)),
        ],
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: mutedIconColor(context)),
        title: Text(
          title,
          style: TextStyle(
            color: primaryTextColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: mutedIconColor(context),
        ),
      ),
    );
  }
}
