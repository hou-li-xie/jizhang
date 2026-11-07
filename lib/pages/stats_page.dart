import 'package:flutter/material.dart';

import '../store/transaction_store.dart';
import '../widgets/charts.dart';
import '../widgets/month_switcher.dart';

/// “统计”页：选中月份收支概览 + 支出趋势折线图 + 分类占比饼图。
/// 趋势图默认看近 6 个月，支持快捷/自定义时间范围，并可按分类多选对比。
class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
  });

  final TransactionStore store;

  /// 当前统计的月份（只用 year/month）
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  /// 快捷范围：近 N 个月（跟随选中月份）；为 null 时使用自定义范围
  int? _presetMonths = 6;

  /// 自定义起止范围（按整月聚合）
  DateTimeRange? _customRange;

  /// 用户手动选择的对比分类；为 null 时默认取金额前三的分类
  Set<String>? _selectedCategories;

  /// 趋势图展示形态：折线 / 柱状
  TrendChartStyle _chartStyle = TrendChartStyle.line;

  /// 趋势窗口的起止月份（均归一化到每月 1 号）
  ({DateTime start, DateTime end}) get _trendSpan {
    final custom = _customRange;
    if (custom != null) {
      return (
        start: DateTime(custom.start.year, custom.start.month),
        end: DateTime(custom.end.year, custom.end.month),
      );
    }
    final months = _presetMonths ?? 6;
    final end = DateTime(widget.month.year, widget.month.month);
    return (start: DateTime(end.year, end.month - months + 1), end: end);
  }

  String get _rangeLabel {
    final custom = _customRange;
    if (custom != null) {
      String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
      return '${fmt(custom.start)} ~ ${fmt(custom.end)}';
    }
    return '近 ${_presetMonths ?? 6} 个月';
  }

  /// 趋势窗口内出现过支出的分类，按金额倒序
  List<String> _availableCategories() {
    final span = _trendSpan;
    final totals = <String, double>{};
    for (final t in widget.store.transactions) {
      if (!t.isExpense) continue;
      final month = DateTime(t.date.year, t.date.month);
      if (month.isBefore(span.start) || month.isAfter(span.end)) continue;
      totals.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  void _toggleCategory(String name) {
    final available = _availableCategories();
    final current = _selectedCategories ?? available.take(3).toSet();
    final next = Set<String>.of(current);
    if (!next.remove(name)) next.add(name);
    setState(() => _selectedCategories = next);
  }

  Future<void> _pickRange() async {
    final isPreset = _customRange == null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('趋势时间范围'),
            ),
            for (final n in [3, 6, 12])
              ListTile(
                title: Text('近 $n 个月'),
                trailing: isPreset && _presetMonths == n
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, '$n'),
              ),
            ListTile(
              title: const Text('自定义范围…'),
              trailing: isPreset ? null : const Icon(Icons.check),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'custom') {
      await _pickCustomRange();
      return;
    }
    setState(() {
      _presetMonths = int.parse(choice);
      _customRange = null;
      _selectedCategories = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final span = _trendSpan;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDateRange: DateTimeRange(
        start: DateTime(span.start.year, span.start.month, 1),
        end: DateTime(
          span.end.year,
          span.end.month,
          DateUtils.getDaysInMonth(span.end.year, span.end.month),
        ),
      ),
      helpText: '选择趋势时间范围',
      saveText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _presetMonths = null;
      _selectedCategories = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final monthTransactions = widget.store.transactions
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();

    final monthExpense = monthTransactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final monthIncome = monthTransactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final categoryTotals = <String, double>{};
    for (final t in monthTransactions.where((t) => t.isExpense)) {
      categoryTotals.update(t.category, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // —— 趋势数据 ——
    final span = _trendSpan;
    final spansYears = span.start.year != span.end.year;
    final monthCount = (span.end.year - span.start.year) * 12 +
        span.end.month -
        span.start.month +
        1;

    final labels = <String>[];
    for (var i = 0; i < monthCount; i++) {
      final m = DateTime(span.start.year, span.start.month + i);
      labels.add(spansYears ? '${m.year % 100}/${m.month}' : '${m.month}月');
    }

    // 范围内的支出，按分类汇总以决定可选分类与配色顺序
    final rangeExpenses = <({String category, int monthIndex, double amount})>[];
    for (final t in widget.store.transactions) {
      if (!t.isExpense) continue;
      final monthIndex =
          (t.date.year - span.start.year) * 12 + t.date.month - span.start.month;
      if (monthIndex < 0 || monthIndex >= monthCount) continue;
      rangeExpenses.add((
        category: t.category,
        monthIndex: monthIndex,
        amount: t.amount,
      ));
    }

    final rangeTotals = <String, double>{};
    for (final e in rangeExpenses) {
      rangeTotals.update(e.category, (v) => v + e.amount,
          ifAbsent: () => e.amount);
    }
    final categoryEntries = rangeTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryNames = categoryEntries.map((e) => e.key).toList();

    final selected = _selectedCategories == null
        ? categoryNames.take(3).toSet()
        : categoryNames.where(_selectedCategories!.contains).toSet();

    final series = <TrendSeries>[];
    var trendTotal = 0.0;
    for (var i = 0; i < categoryNames.length; i++) {
      final name = categoryNames[i];
      if (!selected.contains(name)) continue;
      final values = List<double>.filled(monthCount, 0);
      for (final e in rangeExpenses) {
        if (e.category == name) values[e.monthIndex] += e.amount;
      }
      trendTotal += values.fold(0.0, (a, b) => a + b);
      series.add(TrendSeries(
        label: name,
        color: chartPalette[i % chartPalette.length],
        values: values,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MonthSwitcher(month: month, onChanged: widget.onMonthChanged),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('${month.month} 月概览',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(label: '支出', value: monthExpense),
                    _SummaryItem(label: '收入', value: monthIncome),
                    _SummaryItem(
                        label: '结余', value: monthIncome - monthExpense),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('支出趋势',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    _ChartStyleToggle(
                      value: _chartStyle,
                      onChanged: (style) =>
                          setState(() => _chartStyle = style),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('合计 ¥${trendTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    TextButton(
                      onPressed: _pickRange,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_rangeLabel,
                              style: Theme.of(context).textTheme.bodySmall),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                if (categoryNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < categoryNames.length; i++)
                        _CategoryChip(
                          name: categoryNames[i],
                          color: chartPalette[i % chartPalette.length],
                          selected: selected.contains(categoryNames[i]),
                          onTap: () => _toggleCategory(categoryNames[i]),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (series.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('请选择要对比的类别')),
                  )
                else
                  TrendChart(
                    labels: labels,
                    series: series,
                    style: _chartStyle,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支出分类占比',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (sortedCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('这个月还没有支出记录')),
                  )
                else ...[
                  Center(
                    child: CategoryPieChart(
                      entries: sortedCategories,
                      total: monthExpense,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < sortedCategories.length; i++)
                    _LegendRow(
                      color: chartPalette[i % chartPalette.length],
                      entry: sortedCategories[i],
                      total: monthExpense,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 折线 / 柱状图切换器
class _ChartStyleToggle extends StatelessWidget {
  const _ChartStyleToggle({required this.value, required this.onChanged});

  final TrendChartStyle value;
  final ValueChanged<TrendChartStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(context, Icons.show_chart, TrendChartStyle.line, '折线图'),
          const SizedBox(width: 2),
          _item(context, Icons.bar_chart, TrendChartStyle.bar, '柱状图'),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    TrendChartStyle style,
    String label,
  ) {
    final selected = value == style;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => onChanged(style),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF8A94A0),
          ),
        ),
      ),
    );
  }
}

/// 分类对比选择标签：选中时用该分类的折线颜色填充
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(name),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? color : const Color(0xFFD5DBE1)),
      labelStyle: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: selected ? Colors.white : const Color(0xFF5A6472),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}

/// 饼图图例：色点 + 分类名 + 占比 + 金额
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.entry,
    required this.total,
  });

  final Color color;
  final MapEntry<String, double> entry;
  final double total;

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0.0 : entry.value / total * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.key,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text('${percent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          Text('¥${entry.value.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
