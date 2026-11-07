import 'transaction.dart';

/// 记账模板：高频交易的快捷记录，一键填充记一笔表单。
class Template {
  Template({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    this.account = '',
  });

  final int? id;
  final TransactionType type;
  final double amount;
  final String category;
  final String note;
  final String account;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'account': account,
      };

  factory Template.fromMap(Map<String, Object?> map) => Template(
        id: map['id'] as int?,
        type: map['type'] == 'expense'
            ? TransactionType.expense
            : TransactionType.income,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        note: map['note'] as String? ?? '',
        account: map['account'] as String? ?? '',
      );

  Template withId(int newId) => Template(
        id: newId,
        type: type,
        amount: amount,
        category: category,
        note: note,
        account: account,
      );
}
