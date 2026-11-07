import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../store/transaction_store.dart';
import '../utils/csv_export.dart';
import '../utils/data_io.dart';
import '../widgets/add_transaction_sheet.dart';
import 'account_manage_page.dart';
import 'budget_page.dart';
import 'category_manage_page.dart';
import 'recurring_page.dart';
import 'annual_report_page.dart';
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

  @override
  void initState() {
    super.initState();
    final count = widget.store.generatedCount;
    if (count > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已自动生成 $count 条重复记账')),
          );
        }
      });
    }
  }

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
      appBar: AppBar(title: const Text('轻账')),
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
            _ProfilePage(store: widget.store, month: _month),
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

/// “我的”页：分类管理、预算设置、数据导出等功能入口。
class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.store, required this.month});

  final TransactionStore store;
  final DateTime month;

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

  Future<void> _importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imported = await pickAndImportCsv();
      if (imported.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('未导入数据')));
        return;
      }
      for (final t in imported) {
        await store.add(t);
      }
      messenger.showSnackBar(
          SnackBar(content: Text('已导入 ${imported.length} 条账目')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _backup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await backupDatabase();
      messenger.showSnackBar(SnackBar(content: Text('已备份到：$path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('备份失败：$e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: const Text('恢复将覆盖当前所有数据，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final restored = await pickAndRestoreDatabase();
      if (restored) {
        await store.reload();
        messenger.showSnackBar(const SnackBar(content: Text('恢复成功')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  Future<void> _showThemePicker(BuildContext context) async {
    final current = store.themeMode;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('外观'),
        children: [
          _themeOption(ctx, 'system', '跟随系统', current),
          _themeOption(ctx, 'light', '浅色', current),
          _themeOption(ctx, 'dark', '深色', current),
        ],
      ),
    );
    if (picked != null) {
      await store.setThemeMode(picked);
    }
  }

  SimpleDialogOption _themeOption(
      BuildContext ctx, String value, String label, String current) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Icon(
            current == value ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
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
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('账户管理'),
          subtitle: const Text('现金/微信/支付宝等账户与余额'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccountManagePage(store: store),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.savings_outlined),
          title: const Text('预算设置'),
          subtitle: const Text('按月设置总预算与分类预算'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetPage(store: store, month: month),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.repeat_outlined),
          title: const Text('重复记账'),
          subtitle: const Text('周期性收支自动生成'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecurringPage(store: store),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.assessment_outlined),
          title: const Text('年度报告'),
          subtitle: const Text('全年收支趋势与消费排行'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnnualReportPage(store: store),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('导出数据'),
          subtitle: const Text('导出全部账目为 CSV'),
          onTap: () => _export(context),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('导入 CSV'),
          subtitle: const Text('从 CSV 文件导入账目'),
          onTap: () => _importCsv(context),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('备份数据库'),
          subtitle: const Text('导出完整数据库文件到 Download'),
          onTap: () => _backup(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('恢复备份'),
          subtitle: const Text('从数据库文件恢复（覆盖当前数据）'),
          onTap: () => _restore(context),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('外观'),
          subtitle: Text(_themeLabel(store.themeMode)),
          onTap: () => _showThemePicker(context),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('关于'),
          subtitle: Text('轻账 v1.0.0'),
        ),
      ],
    );
  }

  String _themeLabel(String mode) {
    switch (mode) {
      case 'dark':
        return '深色';
      case 'light':
        return '浅色';
      default:
        return '跟随系统';
    }
  }
}
