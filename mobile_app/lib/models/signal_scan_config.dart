class SignalScanConfig {
  const SignalScanConfig({
    required this.id,
    required this.strategyCode,
    required this.strategyName,
    required this.parameters,
    required this.enabled,
    required this.pushCandidate,
    required this.sortOrder,
  });

  final String id;
  final String strategyCode;
  final String strategyName;
  final Map<String, Object?> parameters;
  final bool enabled;
  final bool pushCandidate;
  final int sortOrder;

  factory SignalScanConfig.fromJson(Map<String, dynamic> json) {
    return SignalScanConfig(
      id: json['id'] as String? ?? '',
      strategyCode: json['strategy_code'] as String? ?? '',
      strategyName: json['strategy_name'] as String? ?? '',
      parameters:
          (json['parameters'] as Map?)?.cast<String, Object?>() ?? const {},
      enabled: json['enabled'] as bool? ?? true,
      pushCandidate: json['push_candidate'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  SignalScanConfig copyWith({bool? enabled, bool? pushCandidate}) {
    return SignalScanConfig(
      id: id,
      strategyCode: strategyCode,
      strategyName: strategyName,
      parameters: parameters,
      enabled: enabled ?? this.enabled,
      pushCandidate: pushCandidate ?? this.pushCandidate,
      sortOrder: sortOrder,
    );
  }

  String get parameterLabel {
    if (parameters.isEmpty) return '-';
    return parameters.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
  }
}
