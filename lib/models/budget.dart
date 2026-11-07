/// 预算类型：月度总额 / 单分类月度
enum BudgetType { total, category }

/// 一条预算记录
class Budget {
  Budget({
    this.id,
    required this.type,
    required this.month,
    required this.amount,
    this.category,
  });

  final int? id;
  final BudgetType type;

  /// 'YYYY-MM' 格式的月份
  final String month;
  final double amount;

  /// 仅分类预算有值
  final String? category;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'month': month,
        'amount': amount,
        if (category != null) 'category': category,
      };

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        id: map['id'] as int?,
        type: map['type'] == 'category'
            ? BudgetType.category
            : BudgetType.total,
        month: map['month'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String?,
      );

  Budget withId(int newId) => Budget(
        id: newId,
        type: type,
        month: month,
        amount: amount,
        category: category,
      );
}
