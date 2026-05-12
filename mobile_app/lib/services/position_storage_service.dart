import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock_position.dart';

class PositionStorageService {
  static const _positionsKey = 'stock_positions';

  Future<List<StockPosition>?> loadPositions() async {
    final preferences = await SharedPreferences.getInstance();
    final rawPositions = preferences.getString(_positionsKey);
    if (rawPositions == null || rawPositions.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawPositions);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(StockPosition.fromJson)
          .toList();
    } on FormatException {
      return null;
    }
  }

  Future<void> savePositions(List<StockPosition> positions) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      positions.map((position) => position.toJson()).toList(),
    );
    await preferences.setString(_positionsKey, encoded);
  }
}
