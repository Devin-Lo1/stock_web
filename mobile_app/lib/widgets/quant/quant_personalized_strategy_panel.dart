import 'package:flutter/material.dart';

import '../../models/personalized_strategy.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';

class QuantPersonalizedStrategyPanel extends StatefulWidget {
  const QuantPersonalizedStrategyPanel({
    super.key,
    required this.templates,
    required this.scanResults,
    required this.recommendations,
    required this.scanningTemplateCodes,
    required this.isLoading,
    required this.isScanningAll,
    required this.onReload,
    required this.onScan,
    required this.onScanAll,
  });

  final List<PersonalizedStrategyTemplate> templates;
  final Map<String, PersonalizedStrategyScanResult> scanResults;
  final List<PersonalizedStrategyRecommendation> recommendations;
  final Set<String> scanningTemplateCodes;
  final bool isLoading;
  final bool isScanningAll;
  final VoidCallback onReload;
  final ValueChanged<PersonalizedStrategyTemplate> onScan;
  final VoidCallback onScanAll;

  @override
  State<QuantPersonalizedStrategyPanel> createState() =>
      _QuantPersonalizedStrategyPanelState();
}

class _QuantPersonalizedStrategyPanelState
    extends State<QuantPersonalizedStrategyPanel> {
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() => _filterText = _filterController.text.trim());
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupTemplates(
      widget.templates,
    ).where((group) => _matchesFilter(group, _filterText)).toList();
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: '个股专属策略',
            icon: Icons.psychology_alt_rounded,
            trailing: IconButton(
              onPressed: widget.isLoading ? null : widget.onReload,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新专属策略',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '每个模板只对应自己的股票，用于研究回测和单次扫描；暂不作为直接交易指令。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _PersonalizedStrategyToolbar(
            controller: _filterController,
            isScanningAll: widget.isScanningAll,
            onClear: () => _filterController.clear(),
            onScanAll: widget.templates.isEmpty ? null : widget.onScanAll,
          ),
          if (widget.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecommendationPanel(recommendations: widget.recommendations),
          ],
          const SizedBox(height: 12),
          if (widget.isLoading)
            const LinearProgressIndicator()
          else if (widget.templates.isEmpty)
            Text(
              '暂无专属策略模板',
              style: TextStyle(color: secondaryTextColor(context)),
            )
          else if (groups.isEmpty)
            Text(
              '没有匹配的股票',
              style: TextStyle(color: secondaryTextColor(context)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final groupWidth = constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < groups.length; index++) ...[
                        SizedBox(
                          width: groupWidth,
                          child: _PersonalizedStrategySymbolSection(
                            group: groups[index],
                            scanResults: widget.scanResults,
                            scanningTemplateCodes: widget.scanningTemplateCodes,
                            onScan: widget.onScan,
                          ),
                        ),
                        if (index != groups.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<_PersonalizedStrategySymbolGroup> _groupTemplates(
    List<PersonalizedStrategyTemplate> templates,
  ) {
    final grouped = <String, List<PersonalizedStrategyTemplate>>{};
    for (final template in templates) {
      final key = template.symbol.toUpperCase();
      grouped.putIfAbsent(key, () => []).add(template);
    }
    final groups = grouped.entries.map((entry) {
      final sorted = [...entry.value]
        ..sort((a, b) {
          final riskCompare = _riskOrder(
            a.riskLevel,
          ).compareTo(_riskOrder(b.riskLevel));
          if (riskCompare != 0) return riskCompare;
          return a.name.compareTo(b.name);
        });
      return _PersonalizedStrategySymbolGroup(
        symbol: entry.key,
        templates: sorted,
      );
    }).toList()..sort((a, b) => a.symbol.compareTo(b.symbol));
    return groups;
  }

  bool _matchesFilter(
    _PersonalizedStrategySymbolGroup group,
    String filterText,
  ) {
    final query = filterText.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (group.symbol.toLowerCase().contains(query)) return true;
    return group.templates.any((template) {
      return template.name.toLowerCase().contains(query) ||
          template.code.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query);
    });
  }

  int _riskOrder(String value) {
    return switch (value) {
      'steady' => 0,
      'aggressive' => 1,
      _ => 2,
    };
  }
}

class _PersonalizedStrategySymbolGroup {
  const _PersonalizedStrategySymbolGroup({
    required this.symbol,
    required this.templates,
  });

  final String symbol;
  final List<PersonalizedStrategyTemplate> templates;
}

class _PersonalizedStrategyToolbar extends StatelessWidget {
  const _PersonalizedStrategyToolbar({
    required this.controller,
    required this.isScanningAll,
    required this.onClear,
    required this.onScanAll,
  });

  final TextEditingController controller;
  final bool isScanningAll;
  final VoidCallback onClear;
  final VoidCallback? onScanAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 210,
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              labelText: '筛选股票',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '清空筛选',
                    ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: isScanningAll ? null : onScanAll,
          icon: isScanningAll
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.manage_search_rounded, size: 18),
          label: Text(isScanningAll ? '扫描中' : '集体扫描'),
        ),
      ],
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.recommendations});

  final List<PersonalizedStrategyRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: appAccentColor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前买入/持仓 Top 3',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < recommendations.length; index++)
            _RecommendationTile(
              rank: index + 1,
              recommendation: recommendations[index],
            ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.rank, required this.recommendation});

  final int rank;
  final PersonalizedStrategyRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(recommendation.action, context);
    final latestText = recommendation.latestPrice == null
        ? '--'
        : recommendation.latestPrice!.toStringAsFixed(2);
    final signalDate = recommendation.signalDate == null
        ? '--'
        : quantDateText(recommendation.signalDate);
    return Container(
      margin: EdgeInsets.only(top: rank == 1 ? 0 : 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Chip(text: recommendation.riskText),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.templateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      recommendation.actionLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '现价 $latestText',
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '信号 $signalDate',
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (recommendation.summary.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    recommendation.summary,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalizedStrategySymbolSection extends StatelessWidget {
  const _PersonalizedStrategySymbolSection({
    required this.group,
    required this.scanResults,
    required this.scanningTemplateCodes,
    required this.onScan,
  });

  final _PersonalizedStrategySymbolGroup group;
  final Map<String, PersonalizedStrategyScanResult> scanResults;
  final Set<String> scanningTemplateCodes;
  final ValueChanged<PersonalizedStrategyTemplate> onScan;

  @override
  Widget build(BuildContext context) {
    final steady = group.templates
        .where((template) => template.riskLevel == 'steady')
        .toList();
    final aggressive = group.templates
        .where((template) => template.riskLevel == 'aggressive')
        .toList();
    final others = group.templates
        .where(
          (template) =>
              template.riskLevel != 'steady' &&
              template.riskLevel != 'aggressive',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.symbol,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${group.templates.length} 个模板',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._cardsFor(context, '稳健型', steady),
        ..._cardsFor(context, '进取型', aggressive),
        ..._cardsFor(context, '其它', others),
      ],
    );
  }

  List<Widget> _cardsFor(
    BuildContext context,
    String title,
    List<PersonalizedStrategyTemplate> templates,
  ) {
    if (templates.isEmpty) return const [];
    return [
      _RiskSectionLabel(title: title),
      const SizedBox(height: 6),
      for (final template in templates) ...[
        _PersonalizedStrategyCard(
          template: template,
          result: scanResults[template.code.toUpperCase()],
          isScanning: scanningTemplateCodes.contains(
            template.code.toUpperCase(),
          ),
          onScan: () => onScan(template),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _RiskSectionLabel extends StatelessWidget {
  const _RiskSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: appAccentColor(context),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

// ignore: unused_element
class _LegacyQuantPersonalizedStrategyPanel extends StatelessWidget {
  const _LegacyQuantPersonalizedStrategyPanel({
    required this.templates,
    required this.scanResults,
    required this.scanningTemplateCodes,
    required this.isLoading,
    required this.onReload,
    required this.onScan,
  });

  final List<PersonalizedStrategyTemplate> templates;
  final Map<String, PersonalizedStrategyScanResult> scanResults;
  final Set<String> scanningTemplateCodes;
  final bool isLoading;
  final VoidCallback onReload;
  final ValueChanged<PersonalizedStrategyTemplate> onScan;

  @override
  Widget build(BuildContext context) {
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: '个股专属策略',
            icon: Icons.psychology_alt_rounded,
            trailing: IconButton(
              onPressed: isLoading ? null : onReload,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新专属策略',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '每个模板只对应自己的股票，用于研究回测和单次扫描；暂不作为直接交易指令。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const LinearProgressIndicator()
          else if (templates.isEmpty)
            Text(
              '暂无专属策略模板',
              style: TextStyle(color: secondaryTextColor(context)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final template in templates) ...[
                    SizedBox(
                      width: 330,
                      child: _PersonalizedStrategyCard(
                        template: template,
                        result: scanResults[template.code.toUpperCase()],
                        isScanning: scanningTemplateCodes.contains(
                          template.code.toUpperCase(),
                        ),
                        onScan: () => onScan(template),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonalizedStrategyCard extends StatelessWidget {
  const _PersonalizedStrategyCard({
    required this.template,
    required this.result,
    required this.isScanning,
    required this.onScan,
  });

  final PersonalizedStrategyTemplate template;
  final PersonalizedStrategyScanResult? result;
  final bool isScanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _Chip(text: template.riskText),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(text: template.directionText),
              _Chip(text: '基准 ${template.benchmarkSymbol}'),
              _Chip(
                text: template.maxHoldDays == null
                    ? '不限定持仓'
                    : '${template.maxHoldDays} 日退出',
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final segment in template.segments)
            _SegmentLine(segment: segment),
          const SizedBox(height: 10),
          _ScanResultBanner(result: result),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showPersonalizedStrategyDetails(context, template),
                  icon: const Icon(Icons.rule_folder_rounded, size: 18),
                  label: const Text('策略细节'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isScanning ? null : onScan,
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar_rounded, size: 18),
                  label: Text(isScanning ? '扫描中' : '扫描一次'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showPersonalizedStrategyDetails(
  BuildContext context,
  PersonalizedStrategyTemplate template,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: pageBackgroundColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return _PersonalizedStrategyDetailSheet(
            template: template,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _PersonalizedStrategyDetailSheet extends StatelessWidget {
  const _PersonalizedStrategyDetailSheet({
    required this.template,
    required this.scrollController,
  });

  final PersonalizedStrategyTemplate template;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor(context),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.symbol,
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.name,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '策略定位',
            children: [
              Text(
                template.description,
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              _DetailKeyValue(label: '策略代码', value: template.code),
              _DetailKeyValue(label: '方向', value: template.directionText),
              _DetailKeyValue(label: '基准', value: template.benchmarkSymbol),
              _DetailKeyValue(
                label: '仓位',
                value: formatPercent(template.positionRatio * 100),
              ),
              _DetailKeyValue(label: '风险', value: template.riskText),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '入场规则',
            children: [_RuleList(rules: template.entryRules)],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '退出规则',
            children: [_RuleList(rules: template.exitRules)],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '参数',
            children: [
              for (final entry in template.parameters.entries)
                _DetailKeyValue(
                  label: _parameterLabel(entry.key),
                  value: _parameterValue(entry.key, entry.value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: '分段验证',
            children: [
              for (final segment in template.segments)
                _DetailSegmentRow(segment: segment),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '说明：这里展示的是当前专属策略模板的规则和参数；今天信号会用实时价生成预估参考，昨日收盘信号使用已确认日 K。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softCardColor(context),
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
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({required this.rules});

  final List<String> rules;

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return Text('--', style: TextStyle(color: secondaryTextColor(context)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rules.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: appAccentColor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rules[index],
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailKeyValue extends StatelessWidget {
  const _DetailKeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSegmentRow extends StatelessWidget {
  const _DetailSegmentRow({required this.segment});

  final PersonalizedStrategySegment segment;

  @override
  Widget build(BuildContext context) {
    final totalReturn = segment.totalReturn * 100;
    final maxDrawdown = segment.maxDrawdown * 100;
    final winRate = segment.winRate * 100;
    final start = segment.startDate == null
        ? '--'
        : quantDateText(segment.startDate);
    final end = segment.endDate == null ? '--' : quantDateText(segment.endDate);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${segment.label} · $start - $end',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniMetric(
                label: '收益',
                value: formatPercent(totalReturn),
                color: quantProfitColor(totalReturn),
              ),
              _MiniMetric(
                label: '回撤',
                value: formatPercent(maxDrawdown),
                color: const Color(0xFFFF3B45),
              ),
              _MiniMetric(
                label: '胜率',
                value: '${winRate.toStringAsFixed(2)}%',
                color: appAccentColor(context),
              ),
              _MiniMetric(
                label: '回合',
                value: '${segment.roundTripCount}',
                color: secondaryTextColor(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _parameterLabel(String key) {
  return switch (key) {
    'engine' => '引擎',
    'short_window' => '短均线',
    'long_window' => '长均线',
    'entry_channel_days' => '入场通道',
    'exit_channel_days' => '退出通道',
    'trend_ma' => '自身趋势',
    'benchmark_ma' => '基准均线',
    'benchmark_roc_days' => '基准动量',
    'benchmark_roc_min' => '基准阈值',
    'own_roc_days' => '自身动量',
    'own_roc_min' => '自身阈值',
    'relative_strength_days' => '相对强弱',
    'relative_strength_min' => '强弱阈值',
    'exit_ma' => '退出均线',
    'fixed_stop' => '固定止损',
    'trailing_stop' => '移动止损',
    'take_profit' => '止盈',
    'max_hold_days' => '持仓上限',
    'own_slope_days' => '自身斜率',
    'own_slope_min' => '自身斜率阈值',
    'qqq_slope_days' => '自身斜率',
    'qqq_slope_min' => '自身斜率阈值',
    'benchmark_slope_days' => '基准斜率',
    'benchmark_slope_min' => '基准斜率阈值',
    'trend_ma_kind' => '趋势均线类型',
    'benchmark_ma_kind' => '基准均线类型',
    'exit_ma_kind' => '退出均线类型',
    'atr_days' => 'ATR周期',
    'atr_pct_min' => 'ATR%下限',
    'atr_pct_max' => 'ATR%上限',
    'atr_stop_mult' => 'ATR止损倍数',
    'atr_trail_mult' => 'ATR移动止损倍数',
    'volume_window' => '成交量周期',
    'volume_ratio_min' => '成交量比例',
    _ => key,
  };
}

String _parameterValue(String key, Object? value) {
  if (value == null) return '--';
  if (key == 'engine') {
    return switch (value.toString()) {
      'ma_cross' => '均线多空交叉',
      'channel' => '通道突破/跌破',
      _ => value.toString(),
    };
  }
  if (value is num) {
    final rateKeys = {
      'benchmark_roc_min',
      'own_roc_min',
      'own_slope_min',
      'qqq_slope_min',
      'benchmark_slope_min',
      'relative_strength_min',
      'atr_pct_min',
      'atr_pct_max',
      'fixed_stop',
      'trailing_stop',
      'take_profit',
    };
    if (rateKeys.contains(key)) return formatPercent(value.toDouble() * 100);
    if (key.endsWith('_days') ||
        key.endsWith('_window') ||
        key.endsWith('_ma') ||
        key == 'max_hold_days') {
      return value.toInt().toString();
    }
    final raw = value.toDouble();
    if (raw == raw.roundToDouble()) return raw.toInt().toString();
    return raw.toStringAsFixed(4);
  }
  return value.toString();
}

class _SegmentLine extends StatelessWidget {
  const _SegmentLine({required this.segment});

  final PersonalizedStrategySegment segment;

  @override
  Widget build(BuildContext context) {
    final totalReturn = segment.totalReturn * 100;
    final maxDrawdown = segment.maxDrawdown * 100;
    final winRate = segment.winRate * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${formatPercent(totalReturn)} / ${formatPercent(maxDrawdown)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: quantProfitColor(totalReturn),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${winRate.toStringAsFixed(0)}% ${segment.roundTripCount}次',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanResultBanner extends StatelessWidget {
  const _ScanResultBanner({required this.result});

  final PersonalizedStrategyScanResult? result;

  @override
  Widget build(BuildContext context) {
    final scanResult = result;
    if (scanResult == null) {
      return _BannerText(
        text: '未扫描',
        subtitle: '点击后同时检查今天实时参考和昨日收盘信号',
        color: secondaryTextColor(context),
      );
    }

    final todaySignal = scanResult.todaySignal;
    final previousSignal = scanResult.previousCloseSignal;
    return Column(
      children: [
        if (todaySignal == null)
          _BannerText(
            text: '今天 · 实时参考不可用',
            subtitle: scanResult.refreshError ?? '暂无实时行情或基准行情',
            color: secondaryTextColor(context),
          )
        else
          _DecisionBlock(
            section: '今天',
            decision: todaySignal,
            note: scanResult.refreshError == null ? null : '行情刷新失败时使用缓存',
          ),
        const SizedBox(height: 8),
        if (previousSignal == null)
          _BannerText(
            text: '昨天收盘 · 暂无确认信号',
            subtitle: '日 K 数据不足或基准数据不足',
            color: secondaryTextColor(context),
          )
        else
          _DecisionBlock(section: '昨天收盘', decision: previousSignal),
      ],
    );
  }
}

class _DecisionBlock extends StatelessWidget {
  const _DecisionBlock({
    required this.section,
    required this.decision,
    this.note,
  });

  final String section;
  final PersonalizedStrategyDecision decision;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(decision.action, context);
    final latestText = decision.latestDate == null
        ? '--'
        : quantDateText(decision.latestDate);
    final priceText = decision.latestPrice == null
        ? '--'
        : decision.latestPrice!.toStringAsFixed(2);
    final signalText = decision.signalDate == null
        ? '无新触发'
        : '信号 ${quantDateText(decision.signalDate)}';
    final suffix = note == null ? '' : ' · $note';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$section · ${decision.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${decision.actionLabel} · $latestText 价 $priceText · $signalText$suffix',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          _DecisionLine(label: '空仓', text: decision.flatDecision),
          _DecisionLine(label: '持多', text: decision.longDecision),
          _DecisionLine(label: '持空', text: decision.shortDecision),
        ],
      ),
    );
  }
}

class _DecisionLine extends StatelessWidget {
  const _DecisionLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '--' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerText extends StatelessWidget {
  const _BannerText({
    required this.text,
    required this.subtitle,
    required this.color,
  });

  final String text;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor(context)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _actionColor(String action, BuildContext context) {
  if (action.contains('short') || action.contains('exit')) {
    return const Color(0xFFFF3B45);
  }
  if (action.contains('long')) return const Color(0xFF12B886);
  return secondaryTextColor(context);
}
