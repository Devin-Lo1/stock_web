import 'package:flutter/material.dart';

void main() {
  runApp(const StockSignalApp());
}

class StockSignalApp extends StatefulWidget {
  const StockSignalApp({super.key});

  @override
  State<StockSignalApp> createState() => _StockSignalAppState();
}

class _StockSignalAppState extends State<StockSignalApp> {
  DisplayMode _displayMode = DisplayMode.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = _displayMode == DisplayMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智能量化助手',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: isDark
            ? const Color(0xFF071018)
            : const Color(0xFFF7FAFC),
      ),
      home: AppShell(
        displayMode: _displayMode,
        onDisplayModeChanged: (mode) => setState(() => _displayMode = mode),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  MarketFilter _marketFilter = MarketFilter.hk;
  final List<StockPosition> _positions = List.of(_samplePositions);
  StrategySettings _settings = StrategySettings.defaults;

  @override
  Widget build(BuildContext context) {
    final visible = _positions
        .where((position) => position.market == _marketFilter)
        .toList();
    final signals = _buildSignals(visible, _settings);
    final pages = [
      DashboardScreen(
        positions: visible,
        signals: signals,
        selectedMarket: _marketFilter,
        onMarketChanged: (market) => setState(() => _marketFilter = market),
        onAccountTap: _openAccount,
        onAddPosition: _addPosition,
        onEditPosition: _editPosition,
        onDeletePosition: _deletePosition,
      ),
      PositionsScreen(
        positions: visible,
        selectedMarket: _marketFilter,
        onMarketChanged: (market) => setState(() => _marketFilter = market),
        onAddPosition: _addPosition,
        onEditPosition: _editPosition,
        onDeletePosition: _deletePosition,
      ),
      SignalsScreen(signals: signals),
      SettingsScreen(
        settings: _settings,
        displayMode: widget.displayMode,
        onSettingsChanged: (settings) => setState(() => _settings = settings),
        onDisplayModeChanged: widget.onDisplayModeChanged,
      ),
    ];

    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: _isDark(context)
            ? const Color(0xFF0B141D)
            : const Color(0xFFEAF6FF),
        indicatorColor: _isDark(context)
            ? const Color(0xFF1C3445)
            : const Color(0xFFD1E9FF),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: '持仓',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: '信号',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AccountScreen(
          displayMode: widget.displayMode,
          onDisplayModeChanged: widget.onDisplayModeChanged,
        ),
      ),
    );
  }

  Future<void> _addPosition() async {
    final position = await showModalBottomSheet<StockPosition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => const AddPositionSheet(),
    );
    if (position == null) return;
    setState(() => _positions.insert(0, position));
  }

  Future<StockPosition?> _editPosition(StockPosition position) async {
    final updated = await showModalBottomSheet<StockPosition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => AddPositionSheet(initialPosition: position),
    );
    if (updated == null) return null;
    setState(() {
      final index = _positions.indexOf(position);
      if (index != -1) _positions[index] = updated;
    });
    return updated;
  }

  void _deletePosition(StockPosition position) {
    setState(() => _positions.remove(position));
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.positions,
    required this.signals,
    required this.selectedMarket,
    required this.onMarketChanged,
    required this.onAccountTap,
    required this.onAddPosition,
    required this.onEditPosition,
    required this.onDeletePosition,
  });

  final List<StockPosition> positions;
  final List<TradeSignal> signals;
  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onMarketChanged;
  final VoidCallback onAccountTap;
  final VoidCallback onAddPosition;
  final Future<StockPosition?> Function(StockPosition position) onEditPosition;
  final ValueChanged<StockPosition> onDeletePosition;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onAccountTap: onAccountTap),
                const SizedBox(height: 14),
                _AssetOverview(positions: positions),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: '持仓追踪',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MarketSwitch(
                        selectedMarket: selectedMarket,
                        onChanged: onMarketChanged,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: onAddPosition,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('添加'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: positions.isEmpty ? 1 : positions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (positions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: '还没有持仓',
                  subtitle: '添加第一只股票后，这里会展示现价、盈亏和信号。',
                  actionLabel: '添加持仓',
                  onAction: onAddPosition,
                ),
              );
            }
            final position = positions[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PositionTile(
                position: position,
                onEdit: onEditPosition,
                onDelete: () => onDeletePosition(position),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: '最新信号'),
                const SizedBox(height: 8),
                if (signals.isEmpty)
                  const _ReadOnlyEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: '暂无信号',
                    subtitle: '触发止盈、止损或当日异动后会出现在这里。',
                  )
                else
                  ...signals.map(
                    (signal) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SignalTile(signal: signal),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PositionsScreen extends StatelessWidget {
  const PositionsScreen({
    super.key,
    required this.positions,
    required this.selectedMarket,
    required this.onMarketChanged,
    required this.onAddPosition,
    required this.onEditPosition,
    required this.onDeletePosition,
  });

  final List<StockPosition> positions;
  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onMarketChanged;
  final VoidCallback onAddPosition;
  final Future<StockPosition?> Function(StockPosition position) onEditPosition;
  final ValueChanged<StockPosition> onDeletePosition;

  @override
  Widget build(BuildContext context) {
    final totalProfit = positions.fold<double>(
      0,
      (sum, position) => sum + position.profit,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      itemCount: positions.isEmpty ? 2 : positions.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PageTitle(
            title: '持仓',
            subtitle:
                '${positions.length} 只股票 · 总盈亏 ${_formatHkd(totalProfit)}',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MarketSwitch(
                  selectedMarket: selectedMarket,
                  onChanged: onMarketChanged,
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onAddPosition,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加'),
                ),
              ],
            ),
          );
        }
        if (positions.isEmpty) {
          return _EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            title: '还没有持仓',
            subtitle: '先添加持仓，下一步再接后端行情和策略信号。',
            actionLabel: '添加持仓',
            onAction: onAddPosition,
          );
        }
        final position = positions[index - 1];
        return PositionTile(
          position: position,
          onEdit: onEditPosition,
          onDelete: () => onDeletePosition(position),
        );
      },
    );
  }
}

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key, required this.signals});

  final List<TradeSignal> signals;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        _PageTitle(
          title: '信号',
          subtitle: '${signals.length} 条本地策略信号 · 强信号优先提醒',
        ),
        const SizedBox(height: 14),
        if (signals.isEmpty)
          const _ReadOnlyEmptyState(
            icon: Icons.notifications_none_rounded,
            title: '暂无信号',
            subtitle: '当持仓触发止盈、止损或当日异动时，这里会自动展示。',
          )
        else
          ...signals.map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SignalTile(signal: signal),
            ),
          ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.displayMode,
    required this.onSettingsChanged,
    required this.onDisplayModeChanged,
  });

  final StrategySettings settings;
  final DisplayMode displayMode;
  final ValueChanged<StrategySettings> onSettingsChanged;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const _PageTitle(title: '设置', subtitle: '开发阶段配置与连接状态'),
        const SizedBox(height: 12),
        StrategySettingsPanel(
          settings: settings,
          onSettingsChanged: onSettingsChanged,
        ),
        const SizedBox(height: 12),
        _SettingTile(
          icon: Icons.palette_outlined,
          title: '显示设置',
          subtitle: displayMode == DisplayMode.dark ? '夜间模式' : '日间模式',
          status: '可切换',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => DisplaySettingsScreen(
                displayMode: displayMode,
                onDisplayModeChanged: onDisplayModeChanged,
              ),
            ),
          ),
        ),
        const _SettingTile(
          icon: Icons.cloud_done_outlined,
          title: '后端 API',
          subtitle: 'http://192.168.x.x:8000',
          status: '待连接',
        ),
        const _SettingTile(
          icon: Icons.notifications_active_outlined,
          title: '手机推送',
          subtitle: 'Firebase Messaging',
          status: '未配置',
        ),
        const _SettingTile(
          icon: Icons.show_chart_rounded,
          title: '富途行情',
          subtitle: 'FutuOpenD + futu-api',
          status: '下一步',
        ),
        const _SettingTile(
          icon: Icons.info_outline_rounded,
          title: '版本',
          subtitle: 'Android MVP 0.1.0',
          status: '开发中',
        ),
      ],
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: _pageBackgroundColor(context),
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _AccountHeader(),
          const SizedBox(height: 14),
          _MembershipBanner(),
          const SizedBox(height: 14),
          const _AccountMenuTile(
            icon: Icons.notifications_none_rounded,
            title: '消息提醒设置',
          ),
          _AccountMenuTile(
            icon: Icons.view_list_outlined,
            title: '显示设置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => DisplaySettingsScreen(
                  displayMode: displayMode,
                  onDisplayModeChanged: onDisplayModeChanged,
                ),
              ),
            ),
          ),
          const _AccountMenuTile(
            icon: Icons.pie_chart_outline_rounded,
            title: '盈亏分析',
          ),
          const _AccountMenuTile(
            icon: Icons.emoji_events_outlined,
            title: '策略实盘记录',
          ),
          const SizedBox(height: 12),
          const _AccountMenuTile(
            icon: Icons.mail_outline_rounded,
            title: '建议反馈',
          ),
          const _AccountMenuTile(
            icon: Icons.info_outline_rounded,
            title: '关于我们',
          ),
        ],
      ),
    );
  }
}

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: _pageBackgroundColor(context),
        title: const Text('显示设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DisplayModeTile(
            icon: Icons.dark_mode_outlined,
            title: '夜间模式',
            subtitle: '深色背景，适合夜间和行情盯盘',
            selected: displayMode == DisplayMode.dark,
            onTap: () => onDisplayModeChanged(DisplayMode.dark),
          ),
          const SizedBox(height: 10),
          _DisplayModeTile(
            icon: Icons.light_mode_outlined,
            title: '日间模式',
            subtitle: '白色背景、黑色文字、浅蓝色卡片',
            selected: displayMode == DisplayMode.light,
            onTap: () => onDisplayModeChanged(DisplayMode.light),
          ),
        ],
      ),
    );
  }
}

class PositionDetailScreen extends StatefulWidget {
  const PositionDetailScreen({
    super.key,
    required this.position,
    required this.onEdit,
    required this.onDelete,
  });

  final StockPosition position;
  final Future<StockPosition?> Function(StockPosition position) onEdit;
  final VoidCallback onDelete;

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  late StockPosition _position = widget.position;

  Future<void> _editPosition() async {
    final updated = await widget.onEdit(_position);
    if (updated != null && mounted) setState(() => _position = updated);
  }

  void _deletePosition() {
    widget.onDelete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: _pageBackgroundColor(context),
        title: Column(
          children: [
            Text(_position.name, style: const TextStyle(fontSize: 19)),
            Text(
              _position.code,
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '编辑持仓',
            onPressed: _editPosition,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          Text(
            _position.price,
            style: TextStyle(
              color: _profitColor(_position.dailyProfit),
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${_formatHkd(_position.currentPrice - _position.previousClose)}  ${_position.change}',
            style: TextStyle(
              color: _profitColor(_position.dailyProfit),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuoteStat(
                  label: '昨收',
                  value: _formatHkd(
                    _position.previousClose,
                    showSign: false,
                    decimals: 2,
                  ),
                ),
              ),
              Expanded(
                child: _QuoteStat(label: '最高', value: _position.price),
              ),
              Expanded(
                child: _QuoteStat(
                  label: '最低',
                  value: _formatHkd(
                    _position.previousClose * 0.982,
                    showSign: false,
                    decimals: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _ChartTabs(),
          const SizedBox(height: 10),
          _KLinePreview(position: _position),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: _position.signal),
              _Tag(text: '数量 ${_formatNumberInput(_position.quantity)}'),
              _Tag(text: '现价 ${_position.price}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: '当日收益',
                  value: _formatHkd(_position.dailyProfit),
                  subValue: _formatPercent(_position.dailyProfitRate),
                  color: _profitColor(_position.dailyProfit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailMetric(
                  label: '持有收益',
                  value: _position.pnl,
                  subValue: _formatPercent(_position.profitRate),
                  color: _profitColor(_position.profit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: '成本价',
                  value: _formatHkd(
                    _position.costPrice,
                    showSign: false,
                    decimals: 2,
                  ),
                  subValue:
                      '成本 ${_formatHkd(_position.costValue, showSign: false)}',
                  color: _primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailMetric(
                  label: '昨收',
                  value: _formatHkd(
                    _position.previousClose,
                    showSign: false,
                    decimals: 2,
                  ),
                  subValue: '涨跌 ${_position.change}',
                  color: _primaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _editPosition,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('修改持仓'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _deletePosition,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddPositionSheet extends StatefulWidget {
  const AddPositionSheet({super.key, this.initialPosition});

  final StockPosition? initialPosition;

  @override
  State<AddPositionSheet> createState() => _AddPositionSheetState();
}

class _AddPositionSheetState extends State<AddPositionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _currentPriceController;
  late final TextEditingController _previousCloseController;

  bool get _isEditing => widget.initialPosition != null;

  @override
  void initState() {
    super.initState();
    final position = widget.initialPosition;
    _codeController = TextEditingController(text: position?.code ?? 'HK.');
    _nameController = TextEditingController(text: position?.name ?? '');
    _quantityController = TextEditingController(
      text: position == null ? '' : _formatNumberInput(position.quantity),
    );
    _costPriceController = TextEditingController(
      text: position == null ? '' : _formatNumberInput(position.costPrice),
    );
    _currentPriceController = TextEditingController(
      text: position == null ? '' : _formatNumberInput(position.currentPrice),
    );
    _previousCloseController = TextEditingController(
      text: position == null ? '' : _formatNumberInput(position.previousClose),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _currentPriceController.dispose();
    _previousCloseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageTitle(
                title: _isEditing ? '编辑持仓' : '添加持仓',
                subtitle: _isEditing
                    ? '修改数量或成本价后，首页盈亏会立即重算'
                    : '先录入基础信息，行情后续由后端补齐',
              ),
              const SizedBox(height: 16),
              _PositionInput(
                controller: _codeController,
                label: '股票代码',
                hint: 'HK.00700',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 10),
              _PositionInput(
                controller: _nameController,
                label: '股票名称',
                hint: '腾讯控股',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PositionInput(
                      controller: _quantityController,
                      label: '数量',
                      hint: '100',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PositionInput(
                      controller: _costPriceController,
                      label: '成本价',
                      hint: '350.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PositionInput(
                      controller: _currentPriceController,
                      label: '现价',
                      hint: '382.40',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PositionInput(
                      controller: _previousCloseController,
                      label: '昨收',
                      hint: '375.40',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_isEditing ? '保存修改' : '添加持仓'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final currentPrice = double.parse(_currentPriceController.text);
    final previousClose = double.parse(_previousCloseController.text);
    Navigator.of(context).pop(
      StockPosition(
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        quantity: double.parse(_quantityController.text),
        costPrice: double.parse(_costPriceController.text),
        currentPrice: currentPrice,
        previousClose: previousClose,
        changeRate: previousClose == 0
            ? 0
            : (currentPrice - previousClose) / previousClose * 100,
        signal: widget.initialPosition?.signal ?? '未生成信号',
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAccountTap});

  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: _softCardColor(context),
              foregroundColor: _primaryTextColor(context),
            ),
            onPressed: onAccountTap,
            icon: const Icon(Icons.person_rounded, size: 28),
            tooltip: '查看账户',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '行情连接正常 · 09:45 更新',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '点击头像查看账户',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: _softCardColor(context),
            foregroundColor: _primaryTextColor(context),
          ),
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新行情',
        ),
      ],
    );
  }
}

class _AssetOverview extends StatelessWidget {
  const _AssetOverview({required this.positions});

  final List<StockPosition> positions;

  @override
  Widget build(BuildContext context) {
    final totalMarketValue = positions.fold<double>(
      0,
      (sum, position) => sum + position.marketValue,
    );
    final totalCost = positions.fold<double>(
      0,
      (sum, position) => sum + position.costValue,
    );
    final totalDailyProfit = positions.fold<double>(
      0,
      (sum, position) => sum + position.dailyProfit,
    );
    final totalProfit = totalMarketValue - totalCost;
    final totalProfitRate = totalCost == 0
        ? 0.0
        : totalProfit / totalCost * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总资产估值',
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _formatHkd(totalMarketValue, showSign: false, decimals: 2),
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '当日收益',
                  value: _formatHkd(totalDailyProfit),
                  subValue: _formatPercent(_dailyProfitRate(positions)),
                  color: _profitColor(totalDailyProfit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: '持有收益',
                  value: _formatHkd(totalProfit),
                  subValue: _formatPercent(totalProfitRate),
                  color: _profitColor(totalProfit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PositionTile extends StatelessWidget {
  const PositionTile({
    super.key,
    required this.position,
    required this.onEdit,
    required this.onDelete,
  });

  final StockPosition position;
  final Future<StockPosition?> Function(StockPosition position) onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _profitColor(position.profit);
    final dailyAccent = _profitColor(position.dailyProfit);

    return Material(
      color: _cardColor(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PositionDetailScreen(
              position: position,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${position.code} · ${_formatNumberInput(position.quantity)}股',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 18,
                child: _CompactMetric(
                  label: '实时',
                  value: position.shortPrice,
                  rate: position.change,
                  color: dailyAccent,
                ),
              ),
              Expanded(
                flex: 20,
                child: _CompactMetric(
                  label: '当日',
                  value: _formatCompactHkd(position.dailyProfit),
                  rate: _formatPercent(position.dailyProfitRate),
                  color: dailyAccent,
                ),
              ),
              Expanded(
                flex: 20,
                child: _CompactMetric(
                  label: '持有',
                  value: _formatCompactHkd(position.profit),
                  rate: _formatPercent(position.profitRate),
                  color: accent,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _mutedIconColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignalTile extends StatelessWidget {
  const SignalTile({super.key, required this.signal});

  final TradeSignal signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: signal.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: signal.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.type,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${signal.stock} · ${signal.time}',
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _Tag(text: signal.level),
        ],
      ),
    );
  }
}

class StrategySettingsPanel extends StatefulWidget {
  const StrategySettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final StrategySettings settings;
  final ValueChanged<StrategySettings> onSettingsChanged;

  @override
  State<StrategySettingsPanel> createState() => _StrategySettingsPanelState();
}

class _StrategySettingsPanelState extends State<StrategySettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _takeProfitController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _dailySurgeController;
  late final TextEditingController _dailyDropController;

  @override
  void initState() {
    super.initState();
    _takeProfitController = TextEditingController(
      text: _settingText(widget.settings.takeProfitPercent),
    );
    _stopLossController = TextEditingController(
      text: _settingText(widget.settings.stopLossPercent),
    );
    _dailySurgeController = TextEditingController(
      text: _settingText(widget.settings.dailySurgePercent),
    );
    _dailyDropController = TextEditingController(
      text: _settingText(widget.settings.dailyDropPercent),
    );
  }

  @override
  void dispose() {
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _dailySurgeController.dispose();
    _dailyDropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '策略阈值',
              style: TextStyle(
                color: _primaryTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '留空会使用默认值：止盈 5%，止损 -5%，当日异动 ±5%。',
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StrategyInput(
                    controller: _takeProfitController,
                    label: '止盈观察 %',
                    hint: '5',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StrategyInput(
                    controller: _stopLossController,
                    label: '止损观察 %',
                    hint: '-5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StrategyInput(
                    controller: _dailySurgeController,
                    label: '上涨异动 %',
                    hint: '5',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StrategyInput(
                    controller: _dailyDropController,
                    label: '下跌异动 %',
                    hint: '-5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('默认值'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _takeProfitController.text = '5';
    _stopLossController.text = '-5';
    _dailySurgeController.text = '5';
    _dailyDropController.text = '-5';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSettingsChanged(
      StrategySettings(
        takeProfitPercent: _readSetting(
          _takeProfitController,
          StrategySettings.defaults.takeProfitPercent,
        ),
        stopLossPercent: _readSetting(
          _stopLossController,
          StrategySettings.defaults.stopLossPercent,
        ),
        dailySurgePercent: _readSetting(
          _dailySurgeController,
          StrategySettings.defaults.dailySurgePercent,
        ),
        dailyDropPercent: _readSetting(
          _dailyDropController,
          StrategySettings.defaults.dailyDropPercent,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.subValue,
    required this.color,
  });

  final String label;
  final String value;
  final String? subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subValue != null)
            Text(
              subValue!,
              style: TextStyle(
                color: color.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.rate,
    required this.color,
  });

  final String label;
  final String value;
  final String rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$label $rate',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _MarketSwitch extends StatelessWidget {
  const _MarketSwitch({required this.selectedMarket, required this.onChanged});

  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MarketFilter>(
      segments: const [
        ButtonSegment(value: MarketFilter.hk, label: Text('港股')),
        ButtonSegment(value: MarketFilter.us, label: Text('美股')),
      ],
      selected: {selectedMarket},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: _softCardColor(context),
            child: Icon(
              Icons.person_rounded,
              color: _primaryTextColor(context),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '用户 812690',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '智能量化助手已陪伴您 91 天',
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _mutedIconColor(context)),
        ],
      ),
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A2E17) : const Color(0xFFFFF2CC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8B6B2C)),
      ),
      child: const Row(
        children: [
          Icon(Icons.diamond_outlined, color: Color(0xFFF6C76B)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '开通会员',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '查看会员专属权限',
            style: TextStyle(color: Color(0xFFF6C76B), fontSize: 13),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFFF6C76B)),
        ],
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: _cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: _mutedIconColor(context)),
        title: Text(
          title,
          style: TextStyle(
            color: _primaryTextColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: _mutedIconColor(context),
        ),
      ),
    );
  }
}

class _DisplayModeTile extends StatelessWidget {
  const _DisplayModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: selected ? _softCardColor(context) : _cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xFF38BDF8) : _borderColor(context),
        ),
      ),
      leading: Icon(icon, color: selected ? const Color(0xFF38BDF8) : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: _cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: const Color(0xFF38BDF8)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _Tag(text: status),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  final String label;
  final String value;
  final String subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _secondaryTextColor(context))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subValue,
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteStat extends StatelessWidget {
  const _QuoteStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor(context))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _primaryTextColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ChartTabs extends StatelessWidget {
  const _ChartTabs();

  @override
  Widget build(BuildContext context) {
    const tabs = ['分时', '日K', '周K', '月K'];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Column(
              children: [
                Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tab == '分时'
                        ? _primaryTextColor(context)
                        : _secondaryTextColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: tab == '分时'
                        ? const Color(0xFF38BDF8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KLinePreview extends StatelessWidget {
  const _KLinePreview({required this.position});

  final StockPosition position;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: CustomPaint(
        painter: _KLinePreviewPainter(
          color: position.dailyProfit >= 0
              ? const Color(0xFFF05252)
              : const Color(0xFF22C55E),
          gridColor: _borderColor(context),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            '模拟分时',
            style: TextStyle(
              color: _profitColor(position.dailyProfit),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _KLinePreviewPainter extends CustomPainter {
  const _KLinePreviewPainter({required this.color, required this.gridColor});

  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.55),
      Offset(size.width * 0.08, size.height * 0.32),
      Offset(size.width * 0.16, size.height * 0.60),
      Offset(size.width * 0.28, size.height * 0.70),
      Offset(size.width * 0.42, size.height * 0.62),
      Offset(size.width * 0.56, size.height * 0.78),
      Offset(size.width * 0.70, size.height * 0.66),
      Offset(size.width * 0.84, size.height * 0.72),
      Offset(size.width, size.height * 0.64),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _KLinePreviewPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.gridColor != gridColor;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ReadOnlyEmptyState extends StatelessWidget {
  const _ReadOnlyEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PositionInput extends StatelessWidget {
  const _PositionInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _softCardColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return '必填';
        if (keyboardType != null && double.tryParse(text) == null) {
          return '请输入数字';
        }
        return null;
      },
    );
  }
}

class _StrategyInput extends StatelessWidget {
  const _StrategyInput({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _softCardColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        if (double.tryParse(text) == null) return '请输入数字';
        return null;
      },
    );
  }
}

class StockPosition {
  const StockPosition({
    required this.name,
    required this.code,
    required this.quantity,
    required this.costPrice,
    required this.currentPrice,
    required this.previousClose,
    required this.changeRate,
    required this.signal,
  });

  final String name;
  final String code;
  final double quantity;
  final double costPrice;
  final double currentPrice;
  final double previousClose;
  final double changeRate;
  final String signal;

  MarketFilter get market {
    final upperCode = code.toUpperCase();
    if (upperCode.startsWith('US.')) return MarketFilter.us;
    return MarketFilter.hk;
  }

  double get costValue => quantity * costPrice;
  double get marketValue => quantity * currentPrice;
  double get profit => marketValue - costValue;
  double get dailyProfit => (currentPrice - previousClose) * quantity;
  double get dailyProfitRate => previousClose == 0
      ? 0
      : (currentPrice - previousClose) / previousClose * 100;
  double get profitRate => costValue == 0 ? 0 : profit / costValue * 100;
  bool get isUp => profit >= 0;
  String get price => _formatHkd(currentPrice, showSign: false, decimals: 2);
  String get shortPrice =>
      '${_currencySymbol(code)}${currentPrice.toStringAsFixed(2)}';
  String get change => _formatPercent(changeRate);
  String get pnl => _formatHkd(profit);
}

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
}

class StrategySettings {
  const StrategySettings({
    required this.takeProfitPercent,
    required this.stopLossPercent,
    required this.dailySurgePercent,
    required this.dailyDropPercent,
  });

  static const defaults = StrategySettings(
    takeProfitPercent: 5,
    stopLossPercent: -5,
    dailySurgePercent: 5,
    dailyDropPercent: -5,
  );

  final double takeProfitPercent;
  final double stopLossPercent;
  final double dailySurgePercent;
  final double dailyDropPercent;
}

enum MarketFilter { hk, us }

enum DisplayMode { dark, light }

String _formatHkd(double value, {bool showSign = true, int decimals = 0}) {
  final sign = showSign
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  return '${sign}HK\$ ${value.abs().toStringAsFixed(decimals)}';
}

String _formatCompactHkd(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  final amount = value.abs();
  if (amount >= 10000) return '$sign${(amount / 10000).toStringAsFixed(1)}万';
  return '$sign${amount.toStringAsFixed(0)}';
}

String _currencySymbol(String stockCode) {
  final code = stockCode.toUpperCase();
  if (code.startsWith('SH.') ||
      code.startsWith('SZ.') ||
      code.startsWith('CN.')) {
    return '¥';
  }
  return r'$';
}

bool _isDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color _pageBackgroundColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF071018) : const Color(0xFFF7FAFC);
}

Color _cardColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF101A24) : const Color(0xFFEAF6FF);
}

Color _softCardColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF162230) : const Color(0xFFDCEFFF);
}

Color _borderColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF243242) : const Color(0xFFBBDCF2);
}

Color _primaryTextColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFFEAF2F8) : const Color(0xFF111827);
}

Color _secondaryTextColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF8EA0B5) : const Color(0xFF5F6F82);
}

Color _mutedIconColor(BuildContext context) {
  return _isDark(context) ? const Color(0xFF66768A) : const Color(0xFF7890A8);
}

String _formatPercent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFFF05252) : const Color(0xFF22C55E);
}

double _dailyProfitRate(List<StockPosition> positions) {
  final previousMarketValue = positions.fold<double>(
    0,
    (sum, position) => sum + position.previousClose * position.quantity,
  );
  final dailyProfit = positions.fold<double>(
    0,
    (sum, position) => sum + position.dailyProfit,
  );
  return previousMarketValue == 0 ? 0 : dailyProfit / previousMarketValue * 100;
}

String _settingText(double value) => _formatNumberInput(value);

double _readSetting(TextEditingController controller, double fallback) {
  final text = controller.text.trim();
  if (text.isEmpty) return fallback;
  return double.tryParse(text) ?? fallback;
}

List<TradeSignal> _buildSignals(
  List<StockPosition> positions,
  StrategySettings settings,
) {
  final signals = <TradeSignal>[];
  for (final position in positions) {
    if (position.profitRate >= settings.takeProfitPercent) {
      signals.add(
        TradeSignal(
          type: '止盈观察',
          stock: '${position.name} ${position.code}',
          time: '持有收益 ${_formatPercent(position.profitRate)}',
          level: '高',
          color: const Color(0xFFF05252),
        ),
      );
    }
    if (position.profitRate <= settings.stopLossPercent) {
      signals.add(
        TradeSignal(
          type: '止损观察',
          stock: '${position.name} ${position.code}',
          time: '持有收益 ${_formatPercent(position.profitRate)}',
          level: '高',
          color: const Color(0xFF22C55E),
        ),
      );
    }
    if (position.dailyProfitRate >= settings.dailySurgePercent) {
      signals.add(
        TradeSignal(
          type: '上涨异动',
          stock: '${position.name} ${position.code}',
          time: '当日 ${_formatPercent(position.dailyProfitRate)}',
          level: '中',
          color: const Color(0xFFF59E0B),
        ),
      );
    }
    if (position.dailyProfitRate <= settings.dailyDropPercent) {
      signals.add(
        TradeSignal(
          type: '下跌异动',
          stock: '${position.name} ${position.code}',
          time: '当日 ${_formatPercent(position.dailyProfitRate)}',
          level: '中',
          color: const Color(0xFF38BDF8),
        ),
      );
    }
  }
  return signals;
}

String _formatNumberInput(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

const _samplePositions = [
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
