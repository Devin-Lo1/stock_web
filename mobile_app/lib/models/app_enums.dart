enum MarketFilter { hk, us, cn }

extension MarketFilterLabel on MarketFilter {
  String get label {
    return switch (this) {
      MarketFilter.hk => '港股',
      MarketFilter.us => '美股',
      MarketFilter.cn => 'A股',
    };
  }

  String get currencyCode {
    return switch (this) {
      MarketFilter.hk => 'HKD',
      MarketFilter.us => 'USD',
      MarketFilter.cn => 'CNY',
    };
  }

  String get currencyPrefix {
    return switch (this) {
      MarketFilter.hk => 'HK\$',
      MarketFilter.us => 'US\$',
      MarketFilter.cn => 'CN¥',
    };
  }

  String get marketValueLabel {
    return switch (this) {
      MarketFilter.hk => '港股市值',
      MarketFilter.us => '美股市值',
      MarketFilter.cn => 'A股市值',
    };
  }

  String get defaultCodePrefix {
    return switch (this) {
      MarketFilter.hk => 'HK.',
      MarketFilter.us => 'US.',
      MarketFilter.cn => 'SH.',
    };
  }
}

enum DisplayMode { dark, light }
