import 'transaction.dart';

/// 重复频率
enum RecurringFrequency { daily, weekly, monthly }

const recurringFrequencyLabels = <RecurringFrequency, String>{
  RecurringFrequency.daily: '每天',
  RecurringFrequency.weekly: '每周',
  RecurringFrequency.monthly: '每月',
};

/// 周期性账目模板，启动时自动生成到期账目。
class Recurring {
  Recurring({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextRun,
    this.note = '',
    this.account = '',
  });

  final int? id;
  final TransactionType type;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final DateTime nextRun;
  final String note;
  final String account;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'frequency': frequency.name,
        'note': note,
        'account': account,
        'next_run': nextRun.millisecondsSinceEpoch,
      };

  factory Recurring.fromMap(Map<String, Object?> map) => Recurring(
        id: map['id'] as int?,
        type: map['type'] == 'expense'
            ? TransactionType.expense
            : TransactionType.income,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        frequency: _freqFromString(map['frequency'] as String),
        note: map['note'] as String? ?? '',
        account: map['account'] as String? ?? '',
        nextRun:
            DateTime.fromMillisecondsSinceEpoch(map['next_run'] as int),
      );

  static RecurringFrequency _freqFromString(String s) {
    switch (s) {
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'monthly':
        return RecurringFrequency.monthly;
      default:
        return RecurringFrequency.daily;
    }
  }

  Recurring withId(int newId) => Recurring(
        id: newId,
        type: type,
        amount: amount,
        category: category,
        frequency: frequency,
        nextRun: nextRun,
        note: note,
        account: account,
      );

  Recurring withNextRun(DateTime next) => Recurring(
        id: id,
        type: type,
        amount: amount,
        category: category,
        frequency: frequency,
        nextRun: next,
        note: note,
        account: account,
      );

  /// 根据频率计算下一次执行日期
  DateTime advance(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }
}
