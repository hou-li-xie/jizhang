import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/transaction.dart';

const _channel = MethodChannel('jizhang/download');

/// 生成 CSV 文本，表头：日期,类型,分类,金额,备注。
String buildCsv(List<Transaction> transactions) {
  final buffer = StringBuffer('日期,类型,分类,金额,备注\n');
  for (final t in transactions) {
    final date =
        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
    buffer.writeln([
      date,
      t.isExpense ? '支出' : '收入',
      _cell(t.category),
      t.amount.toStringAsFixed(2),
      _cell(t.note),
    ].join(','));
  }
  return buffer.toString();
}

/// 单元格含逗号/引号/换行时按 CSV 规范加引号转义。
String _cell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// 导出全部账目为 CSV 到系统 Download 目录（带 UTF-8 BOM，Excel 打开不乱码）。
/// 返回文件相对路径（如 Download/jizhang_xxx.csv）。
Future<String> exportTransactionsToCsv(List<Transaction> transactions) async {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final name = 'jizhang_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';
  final bytes = Uint8List.fromList(
    [0xEF, 0xBB, 0xBF, ...utf8.encode(buildCsv(transactions))],
  );
  final path = await _channel.invokeMethod<String>(
    'saveCsv',
    {'name': name, 'bytes': bytes},
  );
  return path ?? name;
}
