import 'transaction.dart';

/// 内置默认分类，首次启动/升级到 v2 时写入数据库
const defaultExpenseCategories = ['餐饮', '交通', '购物', '居住', '娱乐', '医疗', '其他'];
const defaultIncomeCategories = ['工资', '兼职', '理财', '红包', '其他'];

/// 一个账目分类，支出与收入分开管理
class Category {
  Category({this.id, required this.name, required this.type});

  /// 数据库自增主键；未入库时为 null
  final int? id;
  final String name;
  final TransactionType type;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type.name,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] == 'expense'
            ? TransactionType.expense
            : TransactionType.income,
      );

  /// 入库后回写 id 得到新实例
  Category withId(int newId) => Category(id: newId, name: name, type: type);
}
