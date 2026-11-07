import 'package:flutter/material.dart';

import '../models/account.dart';
import '../store/transaction_store.dart';

/// 账户类型对应的图标
IconData accountTypeIcon(AccountType type) {
  switch (type) {
    case AccountType.cash:
      return Icons.payments_outlined;
    case AccountType.wechat:
      return Icons.chat_outlined;
    case AccountType.alipay:
      return Icons.qr_code_2_outlined;
    case AccountType.bank:
      return Icons.account_balance_outlined;
    case AccountType.card:
      return Icons.credit_card_outlined;
    case AccountType.other:
      return Icons.wallet_outlined;
  }
}

const _accountTypeLabels = <AccountType, String>{
  AccountType.cash: '现金',
  AccountType.wechat: '微信',
  AccountType.alipay: '支付宝',
  AccountType.bank: '银行卡',
  AccountType.card: '信用卡',
  AccountType.other: '其他',
};

/// 账户管理页：查看账户余额、新增/编辑/删除账户、设置初始余额。
class AccountManagePage extends StatelessWidget {
  const AccountManagePage({super.key, required this.store});

  final TransactionStore store;

  Future<void> _showEditSheet(BuildContext context, [Account? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final balanceController = TextEditingController(
        text: existing == null ? '' : existing.initialBalance.toStringAsFixed(2));
    var type = existing?.type ?? AccountType.cash;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? '新增账户' : '编辑账户',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                ),
                items: AccountType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_accountTypeLabels[t]!),
                        ))
                    .toList(),
                onChanged: (v) => setSheetState(() => type = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '初始余额',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final balance =
                      double.tryParse(balanceController.text.trim()) ?? 0;
                  if (existing == null) {
                    await store.addAccount(Account(
                      name: name,
                      type: type,
                      initialBalance: balance,
                    ));
                  } else {
                    await store.updateAccount(Account(
                      id: existing.id,
                      name: name,
                      type: type,
                      initialBalance: balance,
                    ));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除「${account.name}」吗？若有账目使用该账户则无法删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final success = await store.deleteAccount(account);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该账户下还有账目，无法删除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = store.accounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditSheet(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (accounts.isEmpty) {
            return const Center(child: Text('还没有账户，点击右上角添加'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index == accounts.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.savings_outlined),
                      title: const Text('资产总计'),
                      trailing: Text(
                        '¥${store.totalAssets.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              }
              final a = accounts[index];
              final balance = store.balanceOf(a.name);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(accountTypeIcon(a.type)),
                  ),
                  title: Text(a.name),
                  subtitle: Text(_accountTypeLabels[a.type]!),
                  trailing: Text(
                    '¥${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance < 0 ? Colors.red : null,
                    ),
                  ),
                  onTap: () => _showEditSheet(context, a),
                  onLongPress: () => _deleteAccount(context, a),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
