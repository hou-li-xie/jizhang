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
    this.account = '',
    this.tags = const [],
    this.currency = 'CNY',
  });

  /// 数据库自增主键；未入库时为 null
  final int? id;
  final TransactionType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  /// 所属账户名（空字符串表示未指定）
  final String account;

  /// 标签列表
  final List<String> tags;

  /// 货币代码，默认 CNY
  final String currency;

  bool get isExpense => type == TransactionType.expense;

  /// 序列化为数据库行；id 为 null 时省略，交给 SQLite 自增
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'account': account,
        'tags': tags.join(','),
        'currency': currency,
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
        account: map['account'] as String? ?? '',
        tags: (map['tags'] as String? ?? '')
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        currency: map['currency'] as String? ?? 'CNY',
      );

  /// 入库后回写 id 得到新实例
  Transaction withId(int newId) => Transaction(
        id: newId,
        type: type,
        amount: amount,
        category: category,
        note: note,
        date: date,
        account: account,
        tags: tags,
        currency: currency,
      );
}
