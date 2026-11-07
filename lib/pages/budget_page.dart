import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';

/// 预算设置页：按月设置总预算与各分类预算。
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store, required this.month});

  final TransactionStore store;
  final DateTime month;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late DateTime _month;
  final TextEditingController _totalController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.month.year, widget.month.month);
    _loadBudgets();
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadBudgets() {
    final total = widget.store.totalBudgetFor(_month);
    _totalController.text = total == null ? '' : total.toStringAsFixed(0);
    for (final c in widget.store.categoriesFor(TransactionType.expense)) {
      final budget = widget.store.categoryBudgetFor(_month, c.name);
      _categoryControllers[c.name] = TextEditingController(
        text: budget == null ? '' : budget.toStringAsFixed(0),
      );
    }
  }

  double? _parseAmount(String text) {
    final v = double.tryParse(text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _saveTotal() async {
    await widget.store.setTotalBudget(_month, _parseAmount(_totalController.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('总预算已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _saveCategory(String category) async {
    final ctrl = _categoryControllers[category];
    if (ctrl == null) return;
    await widget.store.setCategoryBudget(
        _month, category, _parseAmount(ctrl.text));
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12),
      helpText: '选择月份',
    );
    if (picked == null) return;
    setState(() {
      _month = DateTime(picked.year, picked.month);
      _loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories =
        widget.store.categoriesFor(TransactionType.expense);
    return Scaffold(
      appBar: AppBar(title: const Text('预算设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text('${_month.year} 年 ${_month.month} 月'),
              trailing: TextButton(
                onPressed: _pickMonth,
                child: const Text('切换月份'),
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
                  Text('月度总预算',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            prefixText: '¥ ',
                            hintText: '未设置',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saveTotal,
                        child: const Text('保存'),
                      ),
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
                  Text('分类预算',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('为各支出分类单独设预算，留空表示不限制',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  for (final c in expenseCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(c.name),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _categoryControllers[c.name],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                prefixText: '¥ ',
                                hintText: '不限',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _saveCategory(c.name),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _saveCategory(c.name),
                            child: const Text('保存'),
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
