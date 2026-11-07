import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../models/transaction.dart';
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
  }

  final bool _inMemory;
  DatabaseHelper? _db;
  final List<Transaction> _transactions = [];
  final List<Category> _categories = [];

  /// 打开数据库并加载全部账目与分类，应用启动时调用一次。
  Future<void> init() async {
    if (_inMemory) return;
    _db = await DatabaseHelper.open();
    _transactions
      ..clear()
      ..addAll(await _db!.loadAll());
    _categories
      ..clear()
      ..addAll(await _db!.loadCategories());
    notifyListeners();
  }

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
  }

  Future<void> remove(Transaction transaction) async {
    _transactions.remove(transaction);
    final id = transaction.id;
    if (!_inMemory && id != null) {
      await _db!.delete(id);
    }
    notifyListeners();
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
}
