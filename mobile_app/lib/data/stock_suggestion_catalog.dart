import '../models/stock_suggestion.dart';
import 'sample_positions.dart';

final List<StockSuggestion> stockSuggestionCatalog = [
  for (final position in samplePositions)
    StockSuggestion(
      code: position.code,
      name: position.name,
      market: marketFromCode(position.code),
      stockType: 'STOCK',
    ),
  const StockSuggestion(code: 'HK.00700', name: '腾讯控股', market: 'HK'),
  const StockSuggestion(code: 'HK.02318', name: '中国平安', market: 'HK'),
  const StockSuggestion(code: 'HK.02628', name: '中国人寿', market: 'HK'),
  const StockSuggestion(code: 'HK.01398', name: '工商银行', market: 'HK'),
  const StockSuggestion(code: 'HK.00939', name: '建设银行', market: 'HK'),
  const StockSuggestion(code: 'HK.03988', name: '中国银行', market: 'HK'),
  const StockSuggestion(code: 'HK.01288', name: '农业银行', market: 'HK'),
  const StockSuggestion(code: 'HK.09988', name: '阿里巴巴-W', market: 'HK'),
  const StockSuggestion(code: 'HK.03690', name: '美团-W', market: 'HK'),
  const StockSuggestion(code: 'HK.09618', name: '京东集团-SW', market: 'HK'),
  const StockSuggestion(code: 'HK.09868', name: '小鹏汽车-W', market: 'HK'),
  const StockSuggestion(code: 'HK.02015', name: '理想汽车-W', market: 'HK'),
  const StockSuggestion(code: 'HK.01211', name: '比亚迪股份', market: 'HK'),
  const StockSuggestion(code: 'US.AAPL', name: 'Apple', market: 'US'),
  const StockSuggestion(code: 'US.MSFT', name: 'Microsoft', market: 'US'),
  const StockSuggestion(code: 'US.NVDA', name: 'NVIDIA', market: 'US'),
  const StockSuggestion(code: 'US.TSLA', name: 'Tesla', market: 'US'),
  const StockSuggestion(code: 'US.BABA', name: 'Alibaba', market: 'US'),
];

String marketFromCode(String code) {
  final upperCode = code.toUpperCase();
  if (upperCode.contains('.')) return upperCode.split('.').first;
  return '';
}
