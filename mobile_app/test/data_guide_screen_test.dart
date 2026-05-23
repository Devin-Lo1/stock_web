import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/screens/data_guide_screen.dart';

void main() {
  testWidgets('DataGuideScreen explains core data sources', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DataGuideScreen()));

    expect(find.text('数据说明'), findsOneWidget);
    expect(find.text('行情与 K 线'), findsOneWidget);
    expect(find.text('持仓收益'), findsOneWidget);
    expect(find.text('今日资金流向'), findsOneWidget);
    expect(find.text('推送与历史信号'), findsOneWidget);
  });
}
