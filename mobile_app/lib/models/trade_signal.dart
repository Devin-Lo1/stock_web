import 'package:flutter/material.dart';

class TradeSignal {
  const TradeSignal({
    required this.type,
    required this.stock,
    required this.time,
    required this.level,
    required this.color,
  });

  final String type;
  final String stock;
  final String time;
  final String level;
  final Color color;

  String get notificationKey => '$type|$stock';
}
