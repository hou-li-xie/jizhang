import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/month_switcher.dart';

/// “明细”页：当月账目列表，左滑删除，点击编辑，顶部切换月份。
class TransactionListPage extends StatelessWidget {
  const TransactionListPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
  });

  final TransactionStore store;

  /// 当前浏览的月份（只用 year/month）
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  Future<void> _edit(BuildContext context, Transaction t) async {
    final updated = await showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionSheet(store: store, initial: t),
    );
    if (updated != null) {
      await store.update(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = store.transactions
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();
    final monthExpense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final monthIncome = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      children: [
        MonthSwitcher(month: month, onChanged: onMonthChanged),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('支出 ¥${monthExpense.toStringAsFixed(2)}'),
              Text('收入 ¥${monthIncome.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const Divider(height: 8),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('这个月还没有账目'))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return Dismissible(
                      key: ObjectKey(t),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => store.remove(t),
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete_outline),
                      ),
                      child: ListTile(
                        onTap: () => _edit(context, t),
                        leading: CircleAvatar(
                          child: Text(t.category.characters.first),
                        ),
                        title: Text(t.note.isEmpty
                            ? t.category
                            : '${t.category} · ${t.note}'),
                        subtitle: Text(
                          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: Text(
                          '${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                t.isExpense ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
