class PositionTradeDraft {
  const PositionTradeDraft({
    required this.action,
    required this.quantity,
    required this.price,
    this.fee = 0,
    this.note = '',
  });

  final String action;
  final double quantity;
  final double price;
  final double fee;
  final String note;

  Map<String, dynamic> toBackendJson() {
    return {
      'action': action,
      'quantity': quantity,
      'price': price,
      'fee': fee,
      'note': note,
    };
  }
}

class PositionTrade {
  const PositionTrade({
    required this.id,
    required this.positionId,
    required this.market,
    required this.code,
    required this.name,
    required this.currency,
    required this.action,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.tradeTime,
    required this.note,
  });

  final String id;
  final String positionId;
  final String market;
  final String code;
  final String name;
  final String currency;
  final String action;
  final double quantity;
  final double price;
  final double fee;
  final DateTime? tradeTime;
  final String note;

  factory PositionTrade.fromJson(Map<String, dynamic> json) {
    return PositionTrade(
      id: json['id'] as String? ?? '',
      positionId: json['position_id'] as String? ?? '',
      market: json['market'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      action: json['action'] as String? ?? '',
      quantity: _readDouble(json['quantity']),
      price: _readDouble(json['price']),
      fee: _readDouble(json['fee']),
      tradeTime: _readDateTime(json['trade_time']),
      note: json['note'] as String? ?? '',
    );
  }

  String get actionLabel {
    return switch (action) {
      'open' => '建仓',
      'add' => '加仓',
      'reduce' => '减仓',
      'close' => '清仓',
      _ => action,
    };
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
