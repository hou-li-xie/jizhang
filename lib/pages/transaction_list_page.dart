import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/month_switcher.dart';

/// “明细”页：当月账目列表，左滑删除，点击编辑，顶部切换月份；支持搜索全部历史。
class TransactionListPage extends StatefulWidget {
  const TransactionListPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
  });

  final TransactionStore store;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// 多选模式下选中的账目 id 集合
  final Set<int> _selectedIds = {};

  bool get _isSearching => _query.trim().isNotEmpty;
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(Transaction t) {
    setState(() {
      if (t.id != null) {
        if (_selectedIds.contains(t.id)) {
          _selectedIds.remove(t.id);
        } else {
          _selectedIds.add(t.id!);
        }
      }
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除选中的 ${_selectedIds.length} 条账目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final toDelete = widget.store.transactions
        .where((t) => t.id != null && _selectedIds.contains(t.id))
        .toList();
    for (final t in toDelete) {
      await widget.store.remove(t);
    }
    setState(() => _selectedIds.clear());
  }

  void _selectAll() {
    final ids = _visibleTransactions
        .where((t) => t.id != null)
        .map((t) => t.id!)
        .toSet();
    setState(() {
      if (_selectedIds.containsAll(ids) && _selectedIds.length == ids.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  List<Transaction> get _visibleTransactions {
    final all = widget.store.transactions;
    if (_isSearching) {
      final q = _query.trim().toLowerCase();
      return all.where((t) {
        if (t.category.toLowerCase().contains(q)) return true;
        if (t.note.toLowerCase().contains(q)) return true;
        if (t.amount.toStringAsFixed(2).contains(q)) return true;
        if (t.amount.toStringAsFixed(0).contains(q)) return true;
        return false;
      }).toList();
    }
    return all
        .where(
          (t) =>
              t.date.year == widget.month.year &&
              t.date.month == widget.month.month,
        )
        .toList();
  }

  Future<void> _edit(Transaction t) async {
    final updated = await showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          AddTransactionSheet(store: widget.store, initial: t),
    );
    if (updated != null) {
      await widget.store.update(updated);
    }
  }

  Future<void> _confirmDelete(Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账目'),
        content: Text('确定删除「${t.category} ¥${t.amount.toStringAsFixed(2)}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.remove(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _visibleTransactions;
    final expense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final income = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索分类、备注或金额',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (!_isSearching)
          MonthSwitcher(month: widget.month, onChanged: widget.onMonthChanged),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSearching
                    ? '搜索结果 ${transactions.length} 条'
                    : '支出 ¥${expense.toStringAsFixed(2)}',
              ),
              Text(_isSearching ? '' : '收入 ¥${income.toStringAsFixed(2)}'),
            ],
          ),
        ),
        if (_isSelecting)
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
                Text('已选 ${_selectedIds.length} 项'),
                const Spacer(),
                TextButton(onPressed: _selectAll, child: const Text('全选')),
                TextButton(
                  onPressed: _batchDelete,
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          )
        else ...[
          const Divider(height: 8),
        ],
        Expanded(
          child: transactions.isEmpty
              ? Center(child: Text(_isSearching ? '没有匹配的账目' : '这个月还没有账目'))
              : SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      final selected =
                          t.id != null && _selectedIds.contains(t.id);
                      return Slidable(
                        key: ValueKey(t.id),
                        enabled: !_isSelecting,
                        groupTag: 'transactions',
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: 0.44,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _edit(t),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              icon: Icons.edit_outlined,
                              label: '编辑',
                            ),
                            SlidableAction(
                              onPressed: (_) => _confirmDelete(t),
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_outline,
                              label: '删除',
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: _isSelecting
                              ? () => _toggleSelection(t)
                              : null,
                          onLongPress: () => _toggleSelection(t),
                          leading: _isSelecting
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (_) => _toggleSelection(t),
                                )
                              : CircleAvatar(
                                  child: Text(t.category.characters.first),
                                ),
                          title: Text(
                            t.note.isEmpty
                                ? t.category
                                : '${t.category} · ${t.note}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.account.isEmpty
                                    ? '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}'
                                    : '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')} · ${t.account}',
                              ),
                              if (t.tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Wrap(
                                    spacing: 4,
                                    children: [
                                      for (final tag in t.tags)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            '${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: t.isExpense
                                  ? Colors.redAccent
                                  : Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
