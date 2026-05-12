import 'package:flutter/material.dart';

import '../../models/app_enums.dart';

class MarketSwitch extends StatelessWidget {
  const MarketSwitch({
    super.key,
    required this.selectedMarket,
    required this.onChanged,
  });

  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MarketFilter>(
      segments: const [
        ButtonSegment(value: MarketFilter.hk, label: Text('港股')),
        ButtonSegment(value: MarketFilter.us, label: Text('美股')),
      ],
      selected: {selectedMarket},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
