import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/category.dart';
import '../models/transaction.dart';

/// SQLite 数据库助手：建表与账目/分类 CRUD。
class DatabaseHelper {
  DatabaseHelper._(this._db);

  final Database _db;

  static const String table = 'transactions';
  static const String categoryTable = 'categories';

  /// 打开数据库，首次运行自动建表并写入默认分类。
  static Future<DatabaseHelper> open() async {
    final dbDir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbDir, 'jizhang.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date INTEGER NOT NULL
          )
        ''');
        await _createCategoryTable(db);
        await _seedDefaultCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategoryTable(db);
          await _seedDefaultCategories(db);
        }
      },
    );
    return DatabaseHelper._(db);
  }

  static Future<void> _createCategoryTable(Database db) => db.execute('''
        CREATE TABLE $categoryTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL
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
}
