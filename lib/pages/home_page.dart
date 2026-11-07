import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';
import '../utils/csv_export.dart';
import '../widgets/add_transaction_sheet.dart';
import 'category_manage_page.dart';
import 'stats_page.dart';
import 'transaction_list_page.dart';

/// 主框架：底部导航（明细 / 统计 / 我的）+ “记一笔”入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final TransactionStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  /// 明细/统计页共享的浏览月份（归一化到每月 1 号）
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(DateTime month) {
    setState(() => _month = DateTime(month.year, month.month));
  }

  Future<void> _openAddSheet() async {
    final transaction = await showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionSheet(store: widget.store),
    );
    if (transaction != null) {
      widget.store.add(transaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => IndexedStack(
          index: _currentIndex,
          children: [
            TransactionListPage(
              store: widget.store,
              month: _month,
              onMonthChanged: _changeMonth,
            ),
            StatsPage(
              store: widget.store,
              month: _month,
              onMonthChanged: _changeMonth,
            ),
            _ProfilePage(store: widget.store),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddSheet,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '明细',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// “我的”页：分类管理、数据导出等功能入口。
class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.store});

  final TransactionStore store;

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.transactions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('还没有账目可导出')));
      return;
    }
    try {
      final path = await exportTransactionsToCsv(store.transactions);
      messenger.showSnackBar(SnackBar(content: Text('已导出：$path')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('分类管理'),
          subtitle: const Text('自定义收支分类'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryManagePage(store: store),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('导出数据'),
          subtitle: const Text('导出全部账目为 CSV'),
          onTap: () => _export(context),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('关于'),
          subtitle: Text('记账 v1.0.0'),
        ),
      ],
    );
  }
}
