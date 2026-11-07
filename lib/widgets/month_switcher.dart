import 'package:flutter/material.dart';

/// 月份切换器：‹ 2026-11 ›，到达当前月份后右箭头禁用（不看未来）。
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  /// 当前选中月份（只用 year/month）
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(
          '${month.year}-${month.month.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isCurrentMonth
              ? null
              : () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}
