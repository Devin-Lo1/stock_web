import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sample_positions.dart';
import '../models/app_enums.dart';
import '../models/stock_position.dart';
import '../services/api_client.dart';
import '../services/stock_search_api_service.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/page_title.dart';

class AddPositionSheet extends StatefulWidget {
  const AddPositionSheet({
    super.key,
    this.initialPosition,
    this.initialMarket = MarketFilter.hk,
  });

  final StockPosition? initialPosition;
  final MarketFilter initialMarket;

  @override
  State<AddPositionSheet> createState() => _AddPositionSheetState();
}

class _AddPositionSheetState extends State<AddPositionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _currentPriceController;
  late final TextEditingController _previousCloseController;
  late final StockSearchApiService _stockSearchService;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  List<_StockSuggestion> _suggestions = const [];
  bool _isSearching = false;
  bool _isApplyingSuggestion = false;

  bool get _isEditing => widget.initialPosition != null;

  @override
  void initState() {
    super.initState();
    final position = widget.initialPosition;
    _stockSearchService = StockSearchApiService(ApiClient());
    _codeController = TextEditingController(
      text: position?.code ?? _defaultCodePrefix(widget.initialMarket),
    );
    _nameController = TextEditingController(text: position?.name ?? '');
    _quantityController = TextEditingController(
      text: position == null ? '' : formatNumberInput(position.quantity),
    );
    _costPriceController = TextEditingController(
      text: position == null ? '' : formatNumberInput(position.costPrice),
    );
    _currentPriceController = TextEditingController(
      text: position == null ? '' : formatNumberInput(position.currentPrice),
    );
    _previousCloseController = TextEditingController(
      text: position == null ? '' : formatNumberInput(position.previousClose),
    );
    _codeController.addListener(_updateSuggestions);
    _nameController.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _codeController.removeListener(_updateSuggestions);
    _nameController.removeListener(_updateSuggestions);
    _searchDebounce?.cancel();
    _codeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _currentPriceController.dispose();
    _previousCloseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageTitle(
                title: _isEditing ? '编辑持仓' : '添加持仓',
                subtitle: _isEditing
                    ? '只修改持仓基础信息，行情由后端统一更新'
                    : '先录入基础信息，行情后续由后端补齐',
              ),
              const SizedBox(height: 16),
              _PositionInput(
                controller: _codeController,
                label: '股票代码',
                hint: 'HK.00700',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 10),
              _PositionInput(
                controller: _nameController,
                label: '股票名称',
                hint: '腾讯控股',
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                _StockSuggestionList(
                  suggestions: _suggestions,
                  isSearching: _isSearching,
                  onSelected: _applySuggestion,
                ),
              ] else if (_isSearching) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PositionInput(
                      controller: _quantityController,
                      label: '数量',
                      hint: '100',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PositionInput(
                      controller: _costPriceController,
                      label: '成本价',
                      hint: '350.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isEditing)
                _QuoteReadOnlyCard(position: widget.initialPosition!)
              else
                Row(
                  children: [
                    Expanded(
                      child: _PositionInput(
                        controller: _currentPriceController,
                        label: '现价',
                        hint: '382.40',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PositionInput(
                        controller: _previousCloseController,
                        label: '昨收',
                        hint: '375.40',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_isEditing ? '保存修改' : '添加持仓'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateSuggestions() {
    if (_isApplyingSuggestion) return;
    final query = '${_codeController.text} ${_nameController.text}'.trim();
    if (_hasExactCurrentSuggestion(_suggestions)) {
      _searchDebounce?.cancel();
      if (_suggestions.isNotEmpty || _isSearching) {
        setState(() {
          _suggestions = const [];
          _isSearching = false;
        });
      }
      return;
    }

    final localSuggestions = _searchStockSuggestions(query);
    if (_hasExactCurrentSuggestion(localSuggestions)) {
      _searchDebounce?.cancel();
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    if (!_sameSuggestions(_suggestions, localSuggestions)) {
      setState(() => _suggestions = localSuggestions);
    }

    _searchDebounce?.cancel();
    if (_normalizedSearchQuery(query).isEmpty) {
      setState(() => _isSearching = false);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchRemoteSuggestions(query),
    );
  }

  Future<void> _searchRemoteSuggestions(String query) async {
    final requestId = ++_searchRequestId;
    setState(() => _isSearching = true);
    try {
      final results = await _stockSearchService.search(
        _normalizedSearchQuery(query),
        includeDerivatives: _shouldIncludeDerivatives(query),
      );
      if (!mounted || requestId != _searchRequestId) return;
      final suggestions = results
          .map(
            (result) => _StockSuggestion(
              code: result.code,
              name: result.name,
              market: result.market,
              stockType: result.stockType,
              lotSize: result.lotSize,
            ),
          )
          .toList();
      setState(() {
        if (_hasExactCurrentSuggestion(suggestions)) {
          _suggestions = const [];
        } else {
          _suggestions = suggestions.isEmpty
              ? _searchStockSuggestions(query)
              : suggestions;
        }
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _isSearching = false);
    }
  }

  void _applySuggestion(_StockSuggestion suggestion) {
    _isApplyingSuggestion = true;
    _codeController.text = suggestion.code;
    _nameController.text = suggestion.name;
    _isApplyingSuggestion = false;
    _searchDebounce?.cancel();
    _searchRequestId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _isSearching = false;
    });
  }

  bool _hasExactCurrentSuggestion(List<_StockSuggestion> suggestions) {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) return false;
    return suggestions.any(
      (suggestion) =>
          suggestion.code.toUpperCase() == code && suggestion.name == name,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final initialPosition = widget.initialPosition;
    final currentPrice =
        initialPosition?.currentPrice ??
        double.parse(_currentPriceController.text);
    final previousClose =
        initialPosition?.previousClose ??
        double.parse(_previousCloseController.text);
    Navigator.of(context).pop(
      StockPosition(
        id: initialPosition?.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        quantity: double.parse(_quantityController.text),
        costPrice: double.parse(_costPriceController.text),
        currentPrice: currentPrice,
        previousClose: previousClose,
        changeRate: previousClose == 0
            ? 0
            : (currentPrice - previousClose) / previousClose * 100,
        signal: initialPosition?.signal ?? '未生成信号',
      ),
    );
  }
}

class _QuoteReadOnlyCard extends StatelessWidget {
  const _QuoteReadOnlyCard({required this.position});

  final StockPosition position;

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
            '行情由市场更新',
            style: TextStyle(
              color: primaryTextColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuoteReadOnlyMetric(label: '现价', value: position.price),
              ),
              Expanded(
                child: _QuoteReadOnlyMetric(
                  label: '昨收',
                  value: formatHkd(
                    position.previousClose,
                    showSign: false,
                    decimals: 2,
                  ),
                ),
              ),
              Expanded(
                child: _QuoteReadOnlyMetric(
                  label: '涨跌幅',
                  value: position.change,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteReadOnlyMetric extends StatelessWidget {
  const _QuoteReadOnlyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: secondaryTextColor(context))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: primaryTextColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StockSuggestionList extends StatelessWidget {
  const _StockSuggestionList({
    required this.suggestions,
    required this.isSearching,
    required this.onSelected,
  });

  final List<_StockSuggestion> suggestions;
  final bool isSearching;
  final ValueChanged<_StockSuggestion> onSelected;

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
          for (final suggestion in suggestions)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () => onSelected(suggestion),
              leading: _MarketBadge(market: suggestion.market),
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
              trailing: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _MarketBadge extends StatelessWidget {
  const _MarketBadge({required this.market});

  final String market;

  @override
  Widget build(BuildContext context) {
    final label = market.isEmpty ? 'ST' : market;
    return Container(
      width: 28,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _marketBadgeColor(label),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PositionInput extends StatelessWidget {
  const _PositionInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: softCardColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return '必填';
        if (keyboardType != null && double.tryParse(text) == null) {
          return '请输入数字';
        }
        return null;
      },
    );
  }
}

class _StockSuggestion {
  const _StockSuggestion({
    required this.code,
    required this.name,
    this.market = '',
    this.stockType = '',
    this.lotSize = 0,
  });

  final String code;
  final String name;
  final String market;
  final String stockType;
  final double lotSize;

  String get subtitle {
    final details = <String>[code];
    if (stockType.isNotEmpty) details.add(stockType);
    if (lotSize > 0) details.add('${lotSize.toStringAsFixed(0)}股/手');
    return details.join(' · ');
  }
}

final List<_StockSuggestion> _stockSuggestionCatalog = [
  for (final position in samplePositions)
    _StockSuggestion(
      code: position.code,
      name: position.name,
      market: _marketFromCode(position.code),
      stockType: 'STOCK',
    ),
  const _StockSuggestion(code: 'HK.00700', name: '腾讯控股', market: 'HK'),
  const _StockSuggestion(code: 'HK.02318', name: '中国平安', market: 'HK'),
  const _StockSuggestion(code: 'HK.02628', name: '中国人寿', market: 'HK'),
  const _StockSuggestion(code: 'HK.01398', name: '工商银行', market: 'HK'),
  const _StockSuggestion(code: 'HK.00939', name: '建设银行', market: 'HK'),
  const _StockSuggestion(code: 'HK.03988', name: '中国银行', market: 'HK'),
  const _StockSuggestion(code: 'HK.01288', name: '农业银行', market: 'HK'),
  const _StockSuggestion(code: 'HK.09988', name: '阿里巴巴-W', market: 'HK'),
  const _StockSuggestion(code: 'HK.03690', name: '美团-W', market: 'HK'),
  const _StockSuggestion(code: 'HK.09618', name: '京东集团-SW', market: 'HK'),
  const _StockSuggestion(code: 'HK.09868', name: '小鹏汽车-W', market: 'HK'),
  const _StockSuggestion(code: 'HK.02015', name: '理想汽车-W', market: 'HK'),
  const _StockSuggestion(code: 'HK.01211', name: '比亚迪股份', market: 'HK'),
  const _StockSuggestion(code: 'US.AAPL', name: 'Apple', market: 'US'),
  const _StockSuggestion(code: 'US.MSFT', name: 'Microsoft', market: 'US'),
  const _StockSuggestion(code: 'US.NVDA', name: 'NVIDIA', market: 'US'),
  const _StockSuggestion(code: 'US.TSLA', name: 'Tesla', market: 'US'),
  const _StockSuggestion(code: 'US.BABA', name: 'Alibaba', market: 'US'),
];

List<_StockSuggestion> _searchStockSuggestions(String query) {
  final normalizedQuery = query.trim().toUpperCase();
  if (normalizedQuery.isEmpty) return const [];
  final tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && token != 'HK.' && token != 'US.')
      .toList();
  if (tokens.isEmpty) return const [];
  final seenCodes = <String>{};
  final matches = <_StockSuggestion>[];

  for (final suggestion in _stockSuggestionCatalog) {
    final code = suggestion.code.toUpperCase();
    final name = suggestion.name.toUpperCase();
    final codeDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
    final isMatch = tokens.any((token) {
      final digitToken = token.replaceAll(RegExp(r'[^0-9]'), '');
      return code.contains(token) ||
          name.contains(token) ||
          (digitToken.isNotEmpty && codeDigits.contains(digitToken));
    });
    if (!isMatch || !seenCodes.add(code)) continue;
    matches.add(suggestion);
    if (matches.length >= 6) break;
  }

  return matches;
}

String _normalizedSearchQuery(String query) {
  return query
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && token != 'HK.' && token != 'US.')
      .join(' ');
}

bool _shouldIncludeDerivatives(String query) {
  final normalizedQuery = query.trim().toUpperCase();
  final digitQuery = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitQuery.length >= 5) return true;
  if (normalizedQuery.startsWith('HK.') && digitQuery.length >= 4) {
    return true;
  }
  return normalizedQuery.contains('购') ||
      normalizedQuery.contains('沽') ||
      normalizedQuery.contains('牛') ||
      normalizedQuery.contains('熊') ||
      normalizedQuery.contains('轮') ||
      normalizedQuery.contains('WARRANT') ||
      normalizedQuery.contains('CBBC');
}

String _defaultCodePrefix(MarketFilter market) {
  return switch (market) {
    MarketFilter.us => 'US.',
    MarketFilter.hk => 'HK.',
  };
}

String _marketFromCode(String code) {
  final upperCode = code.toUpperCase();
  if (upperCode.contains('.')) return upperCode.split('.').first;
  return '';
}

Color _marketBadgeColor(String market) {
  return switch (market) {
    'HK' => const Color(0xFF7E57C2),
    'US' => const Color(0xFF2563EB),
    'SH' => const Color(0xFFE05A5A),
    'SZ' => const Color(0xFFE05A5A),
    _ => const Color(0xFF64748B),
  };
}

bool _sameSuggestions(
  List<_StockSuggestion> current,
  List<_StockSuggestion> next,
) {
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index++) {
    if (current[index].code != next[index].code) return false;
  }
  return true;
}
