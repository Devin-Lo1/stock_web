class CapitalFlowBucket {
  const CapitalFlowBucket({
    required this.bucket,
    required this.inflow,
    required this.outflow,
    required this.netInflow,
  });

  final String bucket;
  final double inflow;
  final double outflow;
  final double netInflow;

  factory CapitalFlowBucket.fromJson(Map<String, dynamic> json) {
    return CapitalFlowBucket(
      bucket: json['bucket'] as String? ?? '',
      inflow: _readDouble(json['inflow']),
      outflow: _readDouble(json['outflow']),
      netInflow: _readDouble(json['netInflow'] ?? json['net_inflow']),
    );
  }
}

class CapitalFlowPoint {
  const CapitalFlowPoint({
    required this.time,
    required this.netInflow,
    required this.superNetInflow,
    required this.bigNetInflow,
    required this.midNetInflow,
    required this.smallNetInflow,
  });

  final DateTime? time;
  final double netInflow;
  final double superNetInflow;
  final double bigNetInflow;
  final double midNetInflow;
  final double smallNetInflow;

  factory CapitalFlowPoint.fromJson(Map<String, dynamic> json) {
    return CapitalFlowPoint(
      time: _readDateTime(json['time']),
      netInflow: _readDouble(json['netInflow'] ?? json['net_inflow']),
      superNetInflow: _readDouble(
        json['superNetInflow'] ?? json['super_net_inflow'],
      ),
      bigNetInflow: _readDouble(json['bigNetInflow'] ?? json['big_net_inflow']),
      midNetInflow: _readDouble(json['midNetInflow'] ?? json['mid_net_inflow']),
      smallNetInflow: _readDouble(
        json['smallNetInflow'] ?? json['small_net_inflow'],
      ),
    );
  }
}

class CapitalFlowSnapshot {
  const CapitalFlowSnapshot({
    required this.code,
    required this.market,
    required this.currency,
    required this.updateTime,
    required this.totalInflow,
    required this.totalOutflow,
    required this.netInflow,
    required this.buckets,
    required this.points,
  });

  final String code;
  final String market;
  final String currency;
  final DateTime? updateTime;
  final double totalInflow;
  final double totalOutflow;
  final double netInflow;
  final List<CapitalFlowBucket> buckets;
  final List<CapitalFlowPoint> points;

  bool get hasData => buckets.isNotEmpty || points.isNotEmpty;

  factory CapitalFlowSnapshot.fromJson(Map<String, dynamic> json) {
    return CapitalFlowSnapshot(
      code: json['code'] as String? ?? '',
      market: json['market'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      updateTime: _readDateTime(json['updateTime'] ?? json['update_time']),
      totalInflow: _readDouble(json['totalInflow'] ?? json['total_inflow']),
      totalOutflow: _readDouble(json['totalOutflow'] ?? json['total_outflow']),
      netInflow: _readDouble(json['netInflow'] ?? json['net_inflow']),
      buckets: (json['buckets'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CapitalFlowBucket.fromJson)
          .toList(),
      points: (json['points'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CapitalFlowPoint.fromJson)
          .toList(),
    );
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
