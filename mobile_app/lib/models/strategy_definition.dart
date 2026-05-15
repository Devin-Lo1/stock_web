class StrategyDefinition {
  const StrategyDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.defaultParameters,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final Map<String, Object?> defaultParameters;

  factory StrategyDefinition.fromJson(Map<String, dynamic> json) {
    return StrategyDefinition(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      defaultParameters: _readMap(json['default_parameters']),
    );
  }

  double defaultDouble(String key, double fallback) {
    final value = defaultParameters[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}
