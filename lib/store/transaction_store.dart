import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../utils/data_io.dart';
import 'database_helper.dart';

/// 账目仓库：SQLite 持久化 + 内存缓存，数据变更时通知 UI。
/// 对外接口与原内存版保持一致（add/remove 变为异步）。
class TransactionStore extends ChangeNotifier {
  TransactionStore() : _inMemory = false;

  /// 纯内存模式，供单元测试使用（不触碰数据库）。
  TransactionStore.memory() : _inMemory = true {
    _categories
      ..addAll(defaultExpenseCategories
          .map((name) => Category(name: name, type: TransactionType.expense)))
      ..addAll(defaultIncomeCategories
          .map((name) => Category(name: name, type: TransactionType.income)));
    _accounts.addAll(defaultAccounts.entries
        .map((e) => Account(name: e.key, type: e.value)));
  }

  final bool _inMemory;
  DatabaseHelper? _db;
  final List<Transaction> _transactions = [];
  final List<Category> _categories = [];
  final List<Budget> _budgets = [];
  final List<Account> _accounts = [];
  final List<Template> _templates = [];
  final List<Recurring> _recurring = [];

  /// 启动时自动生成的到期账目条数（供 UI 提示）
  int _generatedCount = 0;
  int get generatedCount => _generatedCount;

  /// 打开数据库并加载全部账目、分类、预算与账户，应用启动时调用一次。
  Future<void> init() async {
    if (_inMemory) return;
    _db = await DatabaseHelper.open();
    _transactions
      ..clear()
      ..addAll(await _db!.loadAll());
    _categories
      ..clear()
      ..addAll(await _db!.loadCategories());
    _budgets
      ..clear()
      ..addAll(await _db!.loadBudgets());
    _accounts
      ..clear()
      ..addAll(await _db!.loadAccounts());
    _templates
      ..clear()
      ..addAll(await _db!.loadTemplates());
    _recurring
      ..clear()
      ..addAll(await _db!.loadRecurring());
    await _processRecurring();
    notifyListeners();
    unawaited(_syncWidget());
  }

  /// 处理到期的重复记账：为 nextRun <= 今天的记录生成账目并推进日期
  Future<void> _processRecurring() async {
    if (_inMemory) return;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    _generatedCount = 0;
    for (var i = 0; i < _recurring.length; i++) {
      var r = _recurring[i];
      while (!r.nextRun.isAfter(todayStart)) {
        final t = Transaction(
          type: r.type,
          amount: r.amount,
          category: r.category,
          note: r.note,
          date: DateTime(r.nextRun.year, r.nextRun.month, r.nextRun.day),
          account: r.account,
        );
        final id = await _db!.insert(t);
        _transactions.add(t.withId(id));
        _generatedCount++;
        r = r.withNextRun(r.advance(r.nextRun));
        _recurring[i] = r;
        await _db!.updateRecurring(r);
      }
    }
  }

  /// 关闭并重新打开数据库（用于恢复备份后重新加载全部数据）
  Future<void> reload() async {
    if (_inMemory) return;
    await _db?.close();
    _db = null;
    await init();
  }

  /// 全部记账模板
  List<Template> get templates => List.unmodifiable(_templates);

  /// 全部账户（按创建顺序）
  List<Account> get accounts => List.unmodifiable(_accounts);

  /// 计算某账户当前余额 = 初始余额 + 收入 - 支出
  double balanceOf(String accountName) {
    final account = _accounts.cast<Account?>().firstWhere(
          (a) => a?.name == accountName,
          orElse: () => null,
        );
    var balance = account?.initialBalance ?? 0.0;
    for (final t in _transactions) {
      if (t.account != accountName) continue;
      balance += t.isExpense ? -t.amount : t.amount;
    }
    return balance;
  }

  /// 全部账户余额汇总
  double get totalAssets =>
      _accounts.fold(0.0, (sum, a) => sum + balanceOf(a.name));

  /// 按日期倒序排列的全部账目
  List<Transaction> get transactions {
    final list = List<Transaction>.of(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  double get totalExpense => _transactions
      .where((t) => t.isExpense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalIncome => _transactions
      .where((t) => !t.isExpense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  Future<void> add(Transaction transaction) async {
    if (_inMemory) {
      _transactions.add(transaction);
    } else {
      final id = await _db!.insert(transaction);
      _transactions.add(transaction.withId(id));
    }
    notifyListeners();
    unawaited(_syncWidget());
  }

  Future<void> update(Transaction transaction) async {
    final id = transaction.id;
    final index = id == null
        ? _transactions.indexOf(transaction)
        : _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions[index] = transaction;
    if (!_inMemory) {
      await _db!.update(transaction);
    }
    notifyListeners();
    unawaited(_syncWidget());
  }

  Future<void> remove(Transaction transaction) async {
    _transactions.remove(transaction);
    final id = transaction.id;
    if (!_inMemory && id != null) {
      await _db!.delete(id);
    }
    notifyListeners();
    unawaited(_syncWidget());
  }

  /// 推送本月收支到桌面小组件
  Future<void> _syncWidget() async {
    if (_inMemory) return;
    final now = DateTime.now();
    double expense = 0, income = 0;
    for (final t in _transactions) {
      if (t.date.year != now.year || t.date.month != now.month) continue;
      if (t.isExpense) {
        expense += t.amount;
      } else {
        income += t.amount;
      }
    }
    await updateHomeWidget(expense, income);
  }

  /// 指定类型（支出/收入）的全部分类，按创建顺序
  List<Category> categoriesFor(TransactionType type) =>
      List.unmodifiable(_categories.where((c) => c.type == type));

  /// 新增分类；名称为空或同名（同类型）已存在时忽略
  Future<void> addCategory(String name, TransactionType type) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exists =
        _categories.any((c) => c.type == type && c.name == trimmed);
    if (exists) return;
    final category = Category(name: trimmed, type: type);
    if (_inMemory) {
      _categories.add(category);
    } else {
      final id = await _db!.insertCategory(category);
      _categories.add(category.withId(id));
    }
    notifyListeners();
  }

  /// 引用该分类的账目条数
  Future<int> categoryUsageCount(Category category) async {
    if (_inMemory) {
      return _transactions
          .where(
              (t) => t.type == category.type && t.category == category.name)
          .length;
    }
    return _db!.countTransactionsInCategory(category);
  }

  /// 删除分类；仍被账目引用时拒绝删除并返回 false
  Future<bool> deleteCategory(Category category) async {
    if (await categoryUsageCount(category) > 0) return false;
    _categories.remove(category);
    final id = category.id;
    if (!_inMemory && id != null) {
      await _db!.deleteCategory(id);
    }
    notifyListeners();
    return true;
  }

  // —— 预算 ——

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// 某月的总预算；未设置返回 null
  double? totalBudgetFor(DateTime month) {
    final key = _monthKey(month);
    for (final b in _budgets) {
      if (b.type == BudgetType.total && b.month == key) return b.amount;
    }
    return null;
  }

  /// 某月某分类的预算；未设置返回 null
  double? categoryBudgetFor(DateTime month, String category) {
    final key = _monthKey(month);
    for (final b in _budgets) {
      if (b.type == BudgetType.category &&
          b.month == key &&
          b.category == category) {
        return b.amount;
      }
    }
    return null;
  }

  /// 某月全部分类预算
  List<Budget> categoryBudgetsFor(DateTime month) {
    final key = _monthKey(month);
    return _budgets
        .where((b) => b.type == BudgetType.category && b.month == key)
        .toList();
  }

  /// 设置/更新某月总预算；amount 为 0 或 null 时删除
  Future<void> setTotalBudget(DateTime month, double? amount) async {
    final key = _monthKey(month);
    final existing = _budgets.indexWhere(
        (b) => b.type == BudgetType.total && b.month == key);
    if (amount == null || amount <= 0) {
      if (existing != -1) {
        final b = _budgets.removeAt(existing);
        if (!_inMemory && b.id != null) await _db!.deleteBudget(b.id!);
      }
    } else if (existing != -1) {
      final old = _budgets[existing];
      _budgets[existing] = old.amount == amount ? old : Budget(
        id: old.id,
        type: BudgetType.total,
        month: key,
        amount: amount,
      );
      if (!_inMemory && old.id != null) {
        await _db!.updateBudget(_budgets[existing]);
      }
    } else {
      final budget = Budget(
        type: BudgetType.total,
        month: key,
        amount: amount,
      );
      if (_inMemory) {
        _budgets.add(budget);
      } else {
        final id = await _db!.insertBudget(budget);
        _budgets.add(budget.withId(id));
      }
    }
    notifyListeners();
  }

  /// 设置/更新某月某分类预算；amount 为 0 或 null 时删除
  Future<void> setCategoryBudget(
      DateTime month, String category, double? amount) async {
    final key = _monthKey(month);
    final existing = _budgets.indexWhere((b) =>
        b.type == BudgetType.category &&
        b.month == key &&
        b.category == category);
    if (amount == null || amount <= 0) {
      if (existing != -1) {
        final b = _budgets.removeAt(existing);
        if (!_inMemory && b.id != null) await _db!.deleteBudget(b.id!);
      }
    } else if (existing != -1) {
      final old = _budgets[existing];
      _budgets[existing] = Budget(
        id: old.id,
        type: BudgetType.category,
        month: key,
        amount: amount,
        category: category,
      );
      if (!_inMemory && old.id != null) {
        await _db!.updateBudget(_budgets[existing]);
      }
    } else {
      final budget = Budget(
        type: BudgetType.category,
        month: key,
        amount: amount,
        category: category,
      );
      if (_inMemory) {
        _budgets.add(budget);
      } else {
        final id = await _db!.insertBudget(budget);
        _budgets.add(budget.withId(id));
      }
    }
    notifyListeners();
  }

  // —— 账户 ——

  Future<void> addAccount(Account account) async {
    if (_accounts.any((a) => a.name == account.name)) return;
    if (_inMemory) {
      _accounts.add(account);
    } else {
      final id = await _db!.insertAccount(account);
      _accounts.add(account.withId(id));
    }
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index == -1) return;
    _accounts[index] = account;
    if (!_inMemory) {
      await _db!.updateAccount(account);
    }
    notifyListeners();
  }

  Future<bool> deleteAccount(Account account) async {
    // 检查是否被账目使用
    final inUse =
        _transactions.any((t) => t.account == account.name);
    if (inUse) return false;
    _accounts.remove(account);
    final id = account.id;
    if (!_inMemory && id != null) {
      await _db!.deleteAccount(id);
    }
    notifyListeners();
    return true;
  }

  // —— 模板 ——

  Future<void> addTemplate(Template template) async {
    if (_inMemory) {
      _templates.add(template);
    } else {
      final id = await _db!.insertTemplate(template);
      _templates.add(template.withId(id));
    }
    notifyListeners();
  }

  Future<void> deleteTemplate(Template template) async {
    _templates.remove(template);
    final id = template.id;
    if (!_inMemory && id != null) {
      await _db!.deleteTemplate(id);
    }
    notifyListeners();
  }

  // —— 设置 ——

  /// 主题模式：'system' / 'light' / 'dark'
  static const themeModeKey = 'theme_mode';

  String _themeMode = 'system';
  String get themeMode => _themeMode;

  Future<void> loadSettings() async {
    if (_inMemory) return;
    _themeMode = (await _db!.getSetting(themeModeKey)) ?? 'system';
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    if (!_inMemory) {
      await _db!.setSetting(themeModeKey, mode);
    }
    notifyListeners();
  }

  // —— 重复记账 ——

  List<Recurring> get recurring => List.unmodifiable(_recurring);

  Future<void> addRecurring(Recurring r) async {
    if (_inMemory) {
      _recurring.add(r);
    } else {
      final id = await _db!.insertRecurring(r);
      _recurring.add(r.withId(id));
    }
    notifyListeners();
  }

  Future<void> updateRecurring(Recurring r) async {
    final index = _recurring.indexWhere((x) => x.id == r.id);
    if (index == -1) return;
    _recurring[index] = r;
    if (!_inMemory) {
      await _db!.updateRecurring(r);
    }
    notifyListeners();
  }

  Future<void> deleteRecurring(Recurring r) async {
    _recurring.remove(r);
    final id = r.id;
    if (!_inMemory && id != null) {
      await _db!.deleteRecurring(id);
    }
    notifyListeners();
  }
}
