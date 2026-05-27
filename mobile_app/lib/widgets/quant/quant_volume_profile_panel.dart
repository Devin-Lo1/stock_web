import 'package:flutter/material.dart';

import 'quant_common_widgets.dart';

class QuantVolumeProfilePanel extends StatelessWidget {
  const QuantVolumeProfilePanel({
    super.key,
    required this.stockCodeController,
    required this.deviationThresholdController,
    required this.bucketCountController,
    required this.startDate,
    required this.endDate,
    required this.isRunning,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onRun,
  });

  final TextEditingController stockCodeController;
  final TextEditingController deviationThresholdController;
  final TextEditingController bucketCountController;
  final DateTime startDate;
  final DateTime endDate;
  final bool isRunning;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(
            title: '价值区回归',
            icon: Icons.view_sidebar_rounded,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: stockCodeController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '股票/ETF 代码'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantDateButton(
                  label: '开始日期',
                  value: startDate,
                  onChanged: onStartDateChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuantDateButton(
                  label: '结束日期',
                  value: endDate,
                  onChanged: onEndDateChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantNumberField(
                  controller: deviationThresholdController,
                  label: '偏离阈值',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuantNumberField(
                  controller: bucketCountController,
                  label: '价格桶数',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isRunning ? null : onRun,
              icon: isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stacked_line_chart_rounded),
              label: Text(isRunning ? '计算中' : '启动价值区回测'),
            ),
          ),
        ],
      ),
    );
  }
}
