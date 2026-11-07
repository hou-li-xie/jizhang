import 'package:flutter/material.dart';

import '../models/recurring.dart';
import '../models/transaction.dart';
import '../store/transaction_store.dart';

/// 重复记账管理页：查看、新增、编辑、删除周期性账目。
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key, required this.store});

  final TransactionStore store;

  Future<void> _showEditSheet(BuildContext context,
      [Recurring? existing]) async {
    final amountCtrl = TextEditingController(
        text: existing == null ? '' : existing.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var type = existing?.type ?? TransactionType.expense;
    var frequency = existing?.frequency ?? RecurringFrequency.monthly;
    String category = existing?.category ??
        store.categoriesFor(type).first.name;
    String account = existing?.account ??
        (store.accounts.isNotEmpty ? store.accounts.first.name : '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? '新增重复记账' : '编辑重复记账',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                      value: TransactionType.expense, label: Text('支出')),
                  ButtonSegment(
                      value: TransactionType.income, label: Text('收入')),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (sel) => setSheetState(() {
                  type = sel.first;
                  final cats = store.categoriesFor(type);
                  category = cats.first.name;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                    labelText: '分类', border: OutlineInputBorder()),
                items: store
                    .categoriesFor(type)
                    .map((c) => DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (v) => setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: frequency,
                decoration: const InputDecoration(
                    labelText: '频率', border: OutlineInputBorder()),
                items: RecurringFrequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(recurringFrequencyLabels[f]!),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => frequency = v ?? frequency),
              ),
              if (store.accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: account,
                  decoration: const InputDecoration(
                      labelText: '账户', border: OutlineInputBorder()),
                  items: store.accounts
                      .map((a) => DropdownMenuItem(
                            value: a.name,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: (v) => setSheetState(() => account = v ?? account),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: '备注（可选）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) return;
                  final r = Recurring(
                    id: existing?.id,
                    type: type,
                    amount: amount,
                    category: category,
                    frequency: frequency,
                    note: noteCtrl.text.trim(),
                    account: account,
                    nextRun: existing?.nextRun ?? DateTime.now(),
                  );
                  if (existing == null) {
                    await store.addRecurring(r);
                  } else {
                    await store.updateRecurring(r);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Recurring r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除重复记账'),
        content: Text('确定删除「${r.category} ¥${r.amount.toStringAsFixed(2)}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteRecurring(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重复记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditSheet(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.recurring;
          if (list.isEmpty) {
            return const Center(child: Text('还没有重复记账，点击右上角添加'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              final next = r.nextRun;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      r.type == TransactionType.expense
                          ? Icons.remove
                          : Icons.add,
                    ),
                  ),
                  title: Text('${r.category} ¥${r.amount.toStringAsFixed(2)}'),
                  subtitle: Text(
                      '${recurringFrequencyLabels[r.frequency]} · 下次 ${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}'
                      '${r.note.isNotEmpty ? ' · ${r.note}' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, r),
                  ),
                  onTap: () => _showEditSheet(context, r),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
