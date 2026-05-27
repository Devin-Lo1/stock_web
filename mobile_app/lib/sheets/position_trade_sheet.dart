import 'package:flutter/material.dart';

import '../models/position_trade.dart';
import '../models/stock_position.dart';
import '../utils/formatters.dart';

Future<PositionTradeDraft?> showPositionTradeSheet({
  required BuildContext context,
  required StockPosition position,
  required String action,
}) {
  return showModalBottomSheet<PositionTradeDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        PositionTradeSheet(position: position, action: action),
  );
}

class PositionTradeSheet extends StatefulWidget {
  const PositionTradeSheet({
    super.key,
    required this.position,
    required this.action,
  });

  final StockPosition position;
  final String action;

  @override
  State<PositionTradeSheet> createState() => _PositionTradeSheetState();
}

class _PositionTradeSheetState extends State<PositionTradeSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.action == 'close'
          ? formatNumberInput(widget.position.quantity)
          : '',
    );
    _priceController = TextEditingController(
      text: widget.position.currentPrice == 0
          ? ''
          : widget.position.currentPrice.toStringAsFixed(2),
    );
    _feeController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_actionLabel(widget.action)} ${widget.position.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _quantityController,
              enabled: widget.action != 'close',
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _validatePositive(value, '请输入数量'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: '成交价格'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _validateNonNegative(value, '请输入价格'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _feeController,
              decoration: const InputDecoration(
                labelText: '手续费（留空自动）',
                helperText: '港美股按系统规则估算；填数值则按手动值',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) =>
                  _validateOptionalNonNegative(value, '手续费不能为负'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLength: 120,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text('确认${_actionLabel(widget.action)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PositionTradeDraft(
        action: widget.action,
        quantity: _readDouble(_quantityController.text),
        price: _readDouble(_priceController.text),
        fee: _readOptionalDouble(_feeController.text),
        note: _noteController.text.trim(),
      ),
    );
  }
}

String? _validatePositive(String? value, String message) {
  final parsed = _readDouble(value);
  if (parsed <= 0) return message;
  return null;
}

String? _validateNonNegative(String? value, String message) {
  final parsed = _readDouble(value);
  if (value == null || value.trim().isEmpty || parsed < 0) return message;
  return null;
}

String? _validateOptionalNonNegative(String? value, String message) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = double.tryParse(text);
  if (parsed == null || parsed < 0) return message;
  return null;
}

double _readDouble(String? value) {
  return double.tryParse(value?.trim() ?? '') ?? 0;
}

double? _readOptionalDouble(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String _actionLabel(String action) {
  return switch (action) {
    'add' => '加仓',
    'reduce' => '减仓',
    'close' => '清仓',
    _ => '交易',
  };
}
