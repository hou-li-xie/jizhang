/// 账目类型：支出 / 收入
enum TransactionType { expense, income }

/// 一条账目记录
class Transaction {
  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });

  /// 数据库自增主键；未入库时为 null
  final int? id;
  final TransactionType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  bool get isExpense => type == TransactionType.expense;

  /// 序列化为数据库行；id 为 null 时省略，交给 SQLite 自增
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.millisecondsSinceEpoch,
      };

  factory Transaction.fromMap(Map<String, Object?> map) => Transaction(
        id: map['id'] as int?,
        type: map['type'] == 'expense'
            ? TransactionType.expense
            : TransactionType.income,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        note: map['note'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      );

  /// 入库后回写 id 得到新实例
  Transaction withId(int newId) => Transaction(
        id: newId,
        type: type,
        amount: amount,
        category: category,
        note: note,
        date: date,
      );
}
