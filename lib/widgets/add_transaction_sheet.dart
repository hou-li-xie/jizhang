import 'package:flutter/material.dart';

import '../models/template.dart';
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
  late String _account;
  DateTime _date = DateTime.now();
  List<String> _tags = [];
  String _currency = 'CNY';

  /// 支持的货币
  static const currencies = ['CNY', 'USD', 'EUR', 'JPY', 'HKD'];

  bool get _isEditing => widget.initial != null;

  List<String> get _categories {
    final base =
        widget.store.categoriesFor(_type).map((c) => c.name).toList();
    // 编辑时若原分类已被删除，仍保留展示
    if (!base.contains(_category)) return [...base, _category];
    return base;
  }

  List<String> get _accountNames =>
      widget.store.accounts.map((a) => a.name).toList();

  /// 当前分类下的历史备注（去重，按最近使用倒序）
  List<String> get _recentNotes {
    final seen = <String>{};
    final result = <String>[];
    for (final t in widget.store.transactions) {
      if (t.type != _type || t.category != _category) continue;
      final n = t.note.trim();
      if (n.isNotEmpty && seen.add(n)) result.add(n);
    }
    return result;
  }

  /// 最近使用的分类（同类型），用于默认选中
  String get _recentCategory {
    for (final t in widget.store.transactions) {
      if (t.type == _type &&
          widget.store.categoriesFor(_type).any((c) => c.name == t.category)) {
        return t.category;
      }
    }
    return widget.store.categoriesFor(_type).first.name;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _type = t.type;
      _category = t.category;
      _account = t.account;
      _date = t.date;
      _tags = List.from(t.tags);
      _currency = t.currency;
      _amountController.text = t.amount.toStringAsFixed(2);
      _noteController.text = t.note;
    } else {
      _category = _recentCategory;
      _account = widget.store.accounts.isNotEmpty
          ? widget.store.accounts.first.name
          : '';
    }
    // 若 _account 不在账户列表中（编辑时原账户被删），回退到第一个
    if (_account.isNotEmpty && !_accountNames.contains(_account)) {
      _account = _accountNames.isNotEmpty ? _accountNames.first : '';
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
        account: _account,
        tags: _tags,
        currency: _currency,
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

  /// 应用模板到当前表单
  void _applyTemplate(Template t) {
    setState(() {
      _type = t.type;
      _category =
          _categories.contains(t.category) ? t.category : _categories.first;
      _account = t.account;
      if (!_accountNames.contains(_account) && _accountNames.isNotEmpty) {
        _account = _accountNames.first;
      }
      _amountController.text = t.amount.toStringAsFixed(2);
      _noteController.text = t.note;
    });
  }

  Future<void> _saveAsTemplate() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await widget.store.addTemplate(Template(
      type: _type,
      amount: amount,
      category: _category,
      note: _noteController.text.trim(),
      account: _account,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已存为常用'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _confirmDeleteTemplate(Template t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除常用项'),
        content: Text('删除「${t.category} ¥${t.amount.toStringAsFixed(0)}」？'),
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
      await widget.store.deleteTemplate(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          // 常用模板
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final ts = widget.store.templates
                  .where((t) => t.type == _type)
                  .toList();
              if (ts.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final t = ts[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _applyTemplate(t),
                        onLongPress: () => _confirmDeleteTemplate(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${t.category} ¥${t.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
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
          if (_accountNames.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _account.isEmpty ? null : _account,
              decoration: const InputDecoration(
                labelText: '账户',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final name in _accountNames)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (v) => setState(() => _account = v ?? ''),
            ),
          if (_accountNames.isNotEmpty) const SizedBox(height: 12),
          // 币种
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: '币种',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final c in currencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'CNY'),
          ),
          const SizedBox(height: 12),
          // 标签
          _TagsInput(
            tags: _tags,
            onChanged: (tags) => setState(() => _tags = tags),
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable.empty();
              final q = textEditingValue.text.toLowerCase();
              return _recentNotes
                  .where((n) => n.toLowerCase().contains(q))
                  .toList();
            },
            onSelected: (option) {
              _noteController.text = option;
              _noteController.selection = TextSelection.fromPosition(
                TextPosition(offset: option.length),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              // 用 _noteController 保持与外部同步
              return TextField(
                controller: _noteController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          title: Text(opt),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAsTemplate,
                  icon: const Icon(Icons.bookmark_border, size: 18),
                  label: const Text('存为常用'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 标签输入组件：输入回车添加标签，点击 × 移除
class _TagsInput extends StatefulWidget {
  const _TagsInput({required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
    _controller.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('标签', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                onDeleted: () => _removeTag(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '添加',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
