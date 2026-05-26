import 'package:flutter_test/flutter_test.dart';

import 'package:stock_mobile/main.dart';

void main() {
  testWidgets('Dashboard renders core sections', (WidgetTester tester) async {
    await tester.pumpWidget(const StockSignalApp());

    expect(find.text('点击头像查看账户'), findsOneWidget);
    expect(find.text('总资产估值'), findsOneWidget);
    expect(find.text('持仓追踪'), findsOneWidget);
    expect(find.text('港股'), findsOneWidget);
    expect(find.text('美股'), findsOneWidget);
    expect(find.text('A股'), findsOneWidget);
    expect(find.text('腾讯控股'), findsOneWidget);
  });
}
