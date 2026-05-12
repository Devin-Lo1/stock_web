import '../models/stock_position.dart';

const samplePositions = [
  StockPosition(
    name: '腾讯控股',
    code: 'HK.00700',
    quantity: 100,
    costPrice: 372.80,
    currentPrice: 382.40,
    previousClose: 375.42,
    changeRate: 1.86,
    signal: 'MA5 上穿 MA20',
  ),
  StockPosition(
    name: '中国平安',
    code: 'HK.02318',
    quantity: 300,
    costPrice: 41.41,
    currentPrice: 43.15,
    previousClose: 42.84,
    changeRate: 0.72,
    signal: '止盈观察',
  ),
  StockPosition(
    name: '小米集团-W',
    code: 'HK.01810',
    quantity: 600,
    costPrice: 18.13,
    currentPrice: 17.82,
    previousClose: 17.90,
    changeRate: -0.45,
    signal: '等待确认',
  ),
  StockPosition(
    name: 'Apple',
    code: 'US.AAPL',
    quantity: 20,
    costPrice: 182.30,
    currentPrice: 189.40,
    previousClose: 187.10,
    changeRate: 1.23,
    signal: '止盈观察',
  ),
];
