/// 资产账户类型
enum AccountType { cash, wechat, alipay, bank, card, other }

/// 内置默认账户
const defaultAccounts = <String, AccountType>{
  '现金': AccountType.cash,
  '微信': AccountType.wechat,
  '支付宝': AccountType.alipay,
  '银行卡': AccountType.bank,
};

/// 一个资产账户
class Account {
  Account({
    this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
  });

  final int? id;
  final String name;
  final AccountType type;
  final double initialBalance;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type.name,
        'initial_balance': initialBalance,
      };

  factory Account.fromMap(Map<String, Object?> map) => Account(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: _typeFromString(map['type'] as String),
        initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0,
      );

  static AccountType _typeFromString(String s) {
    switch (s) {
      case 'wechat':
        return AccountType.wechat;
      case 'alipay':
        return AccountType.alipay;
      case 'bank':
        return AccountType.bank;
      case 'card':
        return AccountType.card;
      case 'other':
        return AccountType.other;
      default:
        return AccountType.cash;
    }
  }

  Account withId(int newId) => Account(
        id: newId,
        name: name,
        type: type,
        initialBalance: initialBalance,
      );
}
