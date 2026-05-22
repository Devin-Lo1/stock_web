import 'package:flutter/material.dart';

import '../../models/stock_suggestion.dart';
import '../../utils/theme_helpers.dart';

class QuantStockSuggestionList extends StatelessWidget {
  const QuantStockSuggestionList({
    super.key,
    required this.suggestions,
    required this.isSearching,
    required this.onSelected,
  });

  final List<StockSuggestion> suggestions;
  final bool isSearching;
  final ValueChanged<StockSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSearching) const LinearProgressIndicator(minHeight: 2),
          for (final suggestion in suggestions.take(5))
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () => onSelected(suggestion),
              leading: _QuantMarketBadge(market: suggestion.market),
              title: Text(
                suggestion.name,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                suggestion.subtitle,
                style: TextStyle(color: secondaryTextColor(context)),
              ),
              trailing: const Icon(Icons.check_circle_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _QuantMarketBadge extends StatelessWidget {
  const _QuantMarketBadge({required this.market});

  final String market;

  @override
  Widget build(BuildContext context) {
    final text = market.isEmpty ? '--' : market;
    final accent = appAccentColor(context);
    final backgroundColor = isDarkMode(context)
        ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
        : appAccentContainerColor(context);
    return Container(
      width: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
