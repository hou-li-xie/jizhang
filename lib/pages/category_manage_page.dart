import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../store/transaction_store.dart';

/// 分类管理页：查看/新增/删除分类，支出与收入分开展示。
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key, required this.store});

  final TransactionStore store;

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  TransactionType _type = TransactionType.expense;

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.isEmpty) return;
    final exists =
        widget.store.categoriesFor(_type).any((c) => c.name == name);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分类已存在')),
      );
      return;
    }
    await widget.store.addCategory(name, _type);
  }

  Future<void> _deleteCategory(Category category) async {
    final count = await widget.store.categoryUsageCount(category);
    if (!mounted) return;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('该分类已被 $count 条账目使用，不能删除')),
      );
      return;
    }
    await widget.store.deleteCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('支出'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('收入'),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final category in widget.store.categoriesFor(_type))
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(category.name.characters.first),
                      ),
                      title: Text(category.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteCategory(category),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
