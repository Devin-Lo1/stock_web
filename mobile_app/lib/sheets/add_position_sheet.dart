import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/stock_position.dart';
import '../models/stock_suggestion.dart';
import '../services/api_client.dart';
import '../services/quote_api_service.dart';
import '../services/stock_search_api_service.dart';
import '../utils/formatters.dart';
import '../utils/stock_suggestion_search.dart';
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
  late final QuoteApiService _quoteService;
  Timer? _searchDebounce;
  Timer? _quoteDebounce;
  int _searchRequestId = 0;
  int _quoteRequestId = 0;
  String? _lastQuoteCode;
  List<StockSuggestion> _suggestions = const [];
  bool _isSearching = false;
  bool _isApplyingSuggestion = false;
  bool _isLoadingQuote = false;
  String? _quoteErrorText;

  bool get _isEditing => widget.initialPosition != null;

  @override
  void initState() {
    super.initState();
    final position = widget.initialPosition;
    final apiClient = ApiClient();
    _stockSearchService = StockSearchApiService(apiClient);
    _quoteService = QuoteApiService(apiClient);
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
    if (position == null) {
      _scheduleQuoteFill(immediate: true);
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_updateSuggestions);
    _nameController.removeListener(_updateSuggestions);
    _searchDebounce?.cancel();
    _quoteDebounce?.cancel();
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
              if (!_isEditing && (_isLoadingQuote || _quoteErrorText != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _QuoteFillStatus(
                    isLoading: _isLoadingQuote,
                    errorText: _quoteErrorText,
                  ),
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
    _scheduleQuoteFill();
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

    final localSuggestions = searchStockSuggestions(query);
    if (_hasExactCurrentSuggestion(localSuggestions)) {
      _searchDebounce?.cancel();
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    if (!sameStockSuggestions(_suggestions, localSuggestions)) {
      setState(() => _suggestions = localSuggestions);
    }

    _searchDebounce?.cancel();
    if (normalizedStockSearchQuery(query).isEmpty) {
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
        normalizedStockSearchQuery(query),
        includeDerivatives: shouldIncludeStockDerivatives(query),
      );
      if (!mounted || requestId != _searchRequestId) return;
      final suggestions = results
          .map(
            (result) => StockSuggestion(
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
              ? searchStockSuggestions(query)
              : suggestions;
        }
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _isSearching = false);
    }
  }

  void _applySuggestion(StockSuggestion suggestion) {
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
    _scheduleQuoteFill(immediate: true);
  }

  bool _hasExactCurrentSuggestion(List<StockSuggestion> suggestions) {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) return false;
    return suggestions.any(
      (suggestion) =>
          suggestion.code.toUpperCase() == code && suggestion.name == name,
    );
  }

  Future<void> _submit() async {
    if (!_isEditing &&
        (_currentPriceController.text.trim().isEmpty ||
            _previousCloseController.text.trim().isEmpty)) {
      await _fillQuoteForCode(_codeController.text, forceRefresh: true);
      if (!mounted) return;
    }
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

  void _scheduleQuoteFill({bool immediate = false}) {
    if (_isEditing) return;
    final code = _normalizedQuoteCode(_codeController.text);
    _quoteDebounce?.cancel();
    if (code == null) {
      if (_quoteErrorText != null || _isLoadingQuote) {
        setState(() {
          _quoteErrorText = null;
          _isLoadingQuote = false;
        });
      }
      return;
    }
    if (code == _lastQuoteCode &&
        _currentPriceController.text.trim().isNotEmpty &&
        _previousCloseController.text.trim().isNotEmpty) {
      return;
    }

    if (immediate) {
      unawaited(_fillQuoteForCode(code));
      return;
    }
    _quoteDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _fillQuoteForCode(code),
    );
  }

  Future<bool> _fillQuoteForCode(
    String rawCode, {
    bool forceRefresh = false,
  }) async {
    final code = _normalizedQuoteCode(rawCode);
    if (code == null) return false;
    final requestId = ++_quoteRequestId;
    if (mounted) {
      setState(() {
        _isLoadingQuote = true;
        _quoteErrorText = null;
      });
    }
    try {
      final quotes = forceRefresh
          ? await _quoteService.refreshQuotes([code])
          : await _quoteService.fetchQuotes([code]);
      var quote = quotes[code];
      if (quote == null && !forceRefresh) {
        quote = (await _quoteService.refreshQuotes([code]))[code];
      }
      if (!mounted || requestId != _quoteRequestId) return false;
      if (quote == null) {
        setState(() {
          _isLoadingQuote = false;
          _quoteErrorText = '行情未返回现价和昨收，可稍后重试或手动填写';
        });
        return false;
      }
      _currentPriceController.text = formatNumberInput(quote.currentPrice);
      _previousCloseController.text = formatNumberInput(quote.previousClose);
      _lastQuoteCode = code;
      setState(() {
        _isLoadingQuote = false;
        _quoteErrorText = null;
      });
      return true;
    } catch (_) {
      if (!mounted || requestId != _quoteRequestId) return false;
      setState(() {
        _isLoadingQuote = false;
        _quoteErrorText = '行情同步失败，可稍后重试或手动填写';
      });
      return false;
    }
  }
}

class _QuoteFillStatus extends StatelessWidget {
  const _QuoteFillStatus({required this.isLoading, required this.errorText});

  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final text = errorText;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        color: secondaryTextColor(context),
        fontSize: 12,
        fontWeight: FontWeight.w700,
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
                  value: formatMarketMoney(
                    position.market,
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

String _defaultCodePrefix(MarketFilter market) {
  return market.defaultCodePrefix;
}

String? _normalizedQuoteCode(String rawCode) {
  final code = rawCode.trim().toUpperCase();
  final match = RegExp(r'^(HK|US|SH|SZ|CN)\.[A-Z0-9.\-]+$').firstMatch(code);
  if (match == null) return null;
  final symbol = code.split('.').skip(1).join('.');
  if (symbol.isEmpty) return null;
  return code;
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
