import 'package:flutter/material.dart';

import '../../models/trade_signal.dart';
import '../../utils/theme_helpers.dart';
import '../common/app_tag.dart';

class SignalTile extends StatelessWidget {
  const SignalTile({super.key, required this.signal});

  final TradeSignal signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: signal.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: signal.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.type,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${signal.stock} · ${signal.time}',
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
                if (signal.conditionLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    signal.conditionLabel,
                    style: TextStyle(
                      color: signal.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (signal.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    signal.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppTag(text: signal.level),
        ],
      ),
    );
  }
}
