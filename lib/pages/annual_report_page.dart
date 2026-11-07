import 'package:flutter/material.dart';

import '../store/transaction_store.dart';
import '../widgets/charts.dart';

/// 年度消费报告页：全年收支概览、月度趋势、分类排行、储蓄率。
class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key, required this.store});

  final TransactionStore store;

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final yearTxns = store.transactions
        .where((t) => t.date.year == _year)
        .toList();

    final expense =
        yearTxns.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final income =
        yearTxns.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final savings = income - expense;
    final savingsRate = income > 0 ? (savings / income * 100) : 0.0;

    // 月度支出趋势
    final monthlyExpense = List<double>.filled(12, 0);
    final monthlyIncome = List<double>.filled(12, 0);
    for (final t in yearTxns) {
      if (t.isExpense) {
        monthlyExpense[t.date.month - 1] += t.amount;
      } else {
        monthlyIncome[t.date.month - 1] += t.amount;
      }
    }
    final labels = List.generate(12, (i) => '${i + 1}月');

    // 分类排行
    final categoryTotals = <String, double>{};
    for (final t in yearTxns.where((t) => t.isExpense)) {
      categoryTotals.update(t.category, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Text('$_year 年度报告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      body: yearTxns.isEmpty
          ? const Center(child: Text('这一年还没有账目'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('$_year 年收支总览',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat('总收入', income, Colors.green),
                            _Stat('总支出', expense, Colors.redAccent),
                            _Stat('结余', savings,
                                savings >= 0 ? Colors.green : Colors.red),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '储蓄率 ${savingsRate.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                        Text('月度支出趋势',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: TrendChart(
                            labels: labels,
                            series: [
                              TrendSeries(
                                label: '支出',
                                color: Colors.redAccent,
                                values: monthlyExpense,
                              ),
                              TrendSeries(
                                label: '收入',
                                color: Colors.green,
                                values: monthlyIncome,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (sortedCategories.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('年度消费排行',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (var i = 0;
                              i < sortedCategories.length && i < 10;
                              i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 24,
                                      child: Text('${i + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      child: Text(sortedCategories[i].key)),
                                  Text(
                                      '¥${sortedCategories[i].value.toStringAsFixed(0)}'),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${(sortedCategories[i].value / expense * 100).toStringAsFixed(0)}%',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '¥${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
