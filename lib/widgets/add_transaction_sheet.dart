import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';

/// “记一笔”底部弹层，关闭时通过 Navigator.pop 返回一条 [Transaction]。
/// 传入 [initial] 时进入编辑模式，预填数据并保留原 id。
/// 分类选项从 [store] 中读取（含用户自定义分类）。
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, this.initial, required this.store});

  final Transaction? initial;
  final TransactionStore store;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late String _category;
  DateTime _date = DateTime.now();

  bool get _isEditing => widget.initial != null;

  List<String> get _categories {
    final base =
        widget.store.categoriesFor(_type).map((c) => c.name).toList();
    // 编辑时若原分类已被删除，仍保留展示
    if (!base.contains(_category)) return [...base, _category];
    return base;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _type = t.type;
      _category = t.category;
      _date = t.date;
      _amountController.text = t.amount.toStringAsFixed(2);
      _noteController.text = t.note;
    } else {
      _category = widget.store.categoriesFor(_type).first.name;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的金额')),
      );
      return;
    }
    Navigator.pop(
      context,
      Transaction(
        id: widget.initial?.id,
        type: _type,
        amount: amount,
        category: _category,
        note: _noteController.text.trim(),
        date: _date,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('支出'),
                icon: Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('收入'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() {
                _type = selection.first;
                _category = _categories.first;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            autofocus: !_isEditing,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final category in _categories)
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
