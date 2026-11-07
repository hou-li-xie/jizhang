import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/template.dart';
import '../models/transaction.dart';

/// SQLite 数据库助手：建表与账目/分类/预算/账户/模板 CRUD。
class DatabaseHelper {
  DatabaseHelper._(this._db);

  final Database _db;

  static const String table = 'transactions';
  static const String categoryTable = 'categories';
  static const String budgetTable = 'budgets';
  static const String accountTable = 'accounts';
  static const String templateTable = 'templates';
  static const String settingsTable = 'settings';
  static const String recurringTable = 'recurring';

  /// 打开数据库，首次运行自动建表并写入默认分类/账户。
  static Future<DatabaseHelper> open() async {
    final dbDir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbDir, 'jizhang.db'),
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date INTEGER NOT NULL,
            account TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '',
            currency TEXT NOT NULL DEFAULT 'CNY'
          )
        ''');
        await _createCategoryTable(db);
        await _createBudgetTable(db);
        await _createAccountTable(db);
        await _createTemplateTable(db);
        await _createSettingsTable(db);
        await _createRecurringTable(db);
        await _seedDefaultCategories(db);
        await _seedDefaultAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategoryTable(db);
          await _seedDefaultCategories(db);
        }
        if (oldVersion < 3) {
          await _createBudgetTable(db);
        }
        if (oldVersion < 4) {
          await _createAccountTable(db);
          await _seedDefaultAccounts(db);
          await db.execute(
              'ALTER TABLE $table ADD COLUMN account TEXT NOT NULL DEFAULT \'\'');
        }
        if (oldVersion < 5) {
          await _createTemplateTable(db);
        }
        if (oldVersion < 6) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 7) {
          await _createRecurringTable(db);
        }
        if (oldVersion < 8) {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN tags TEXT NOT NULL DEFAULT \'\'');
          await db.execute(
              'ALTER TABLE $table ADD COLUMN currency TEXT NOT NULL DEFAULT \'CNY\'');
        }
      },
    );
    return DatabaseHelper._(db);
  }

  static Future<void> _createSettingsTable(Database db) => db.execute('''
        CREATE TABLE $settingsTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

  static Future<void> _createRecurringTable(Database db) => db.execute('''
        CREATE TABLE $recurringTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          frequency TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          account TEXT NOT NULL DEFAULT '',
          next_run INTEGER NOT NULL
        )
      ''');

  static Future<void> _createTemplateTable(Database db) => db.execute('''
        CREATE TABLE $templateTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          account TEXT NOT NULL DEFAULT ''
        )
      ''');

  static Future<void> _createCategoryTable(Database db) => db.execute('''
        CREATE TABLE $categoryTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');

  static Future<void> _createBudgetTable(Database db) => db.execute('''
        CREATE TABLE $budgetTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          month TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT
        )
      ''');

  static Future<void> _createAccountTable(Database db) => db.execute('''
        CREATE TABLE $accountTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          initial_balance REAL NOT NULL DEFAULT 0
        )
      ''');

  static Future<void> _seedDefaultCategories(Database db) async {
    for (final name in defaultExpenseCategories) {
      await db.insert(categoryTable, {'name': name, 'type': 'expense'});
    }
    for (final name in defaultIncomeCategories) {
      await db.insert(categoryTable, {'name': name, 'type': 'income'});
    }
  }

  static Future<void> _seedDefaultAccounts(Database db) async {
    defaultAccounts.forEach((name, type) async {
      await db.insert(accountTable, {
        'name': name,
        'type': type.name,
        'initial_balance': 0,
      });
    });
  }

  Future<List<Transaction>> loadAll() async {
    final rows = await _db.query(table);
    return rows.map(Transaction.fromMap).toList();
  }

  Future<int> insert(Transaction t) => _db.insert(table, t.toMap());

  Future<void> update(Transaction t) =>
      _db.update(table, t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> delete(int id) =>
      _db.delete(table, where: 'id = ?', whereArgs: [id]);

  Future<List<Category>> loadCategories() async {
    final rows = await _db.query(categoryTable, orderBy: 'id');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) => _db.insert(categoryTable, c.toMap());

  Future<void> deleteCategory(int id) =>
      _db.delete(categoryTable, where: 'id = ?', whereArgs: [id]);

  /// 引用该分类（同名同类型）的账目条数
  Future<int> countTransactionsInCategory(Category c) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE category = ? AND type = ?',
      [c.name, c.type.name],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // —— 预算 ——

  Future<List<Budget>> loadBudgets() async {
    final rows = await _db.query(budgetTable, orderBy: 'id');
    return rows.map(Budget.fromMap).toList();
  }

  Future<int> insertBudget(Budget b) => _db.insert(budgetTable, b.toMap());

  Future<void> updateBudget(Budget b) =>
      _db.update(budgetTable, b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> deleteBudget(int id) =>
      _db.delete(budgetTable, where: 'id = ?', whereArgs: [id]);

  // —— 账户 ——

  Future<List<Account>> loadAccounts() async {
    final rows = await _db.query(accountTable, orderBy: 'id');
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account a) => _db.insert(accountTable, a.toMap());

  Future<void> updateAccount(Account a) =>
      _db.update(accountTable, a.toMap(), where: 'id = ?', whereArgs: [a.id]);

  Future<void> deleteAccount(int id) =>
      _db.delete(accountTable, where: 'id = ?', whereArgs: [id]);

  // —— 模板 ——

  Future<List<Template>> loadTemplates() async {
    final rows = await _db.query(templateTable, orderBy: 'id');
    return rows.map(Template.fromMap).toList();
  }

  Future<int> insertTemplate(Template t) =>
      _db.insert(templateTable, t.toMap());

  Future<void> deleteTemplate(int id) =>
      _db.delete(templateTable, where: 'id = ?', whereArgs: [id]);

  /// 关闭数据库连接
  Future<void> close() => _db.close();

  // —— 设置 ——

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      settingsTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeSetting(String key) async {
    await _db.delete(settingsTable, where: 'key = ?', whereArgs: [key]);
  }

  // —— 重复记账 ——

  Future<List<Recurring>> loadRecurring() async {
    final rows = await _db.query(recurringTable, orderBy: 'id');
    return rows.map(Recurring.fromMap).toList();
  }

  Future<int> insertRecurring(Recurring r) =>
      _db.insert(recurringTable, r.toMap());

  Future<void> updateRecurring(Recurring r) =>
      _db.update(recurringTable, r.toMap(),
          where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteRecurring(int id) =>
      _db.delete(recurringTable, where: 'id = ?', whereArgs: [id]);
}
