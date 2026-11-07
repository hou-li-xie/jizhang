import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/transaction.dart';

const _channel = MethodChannel('jizhang/download');

/// 解析一行 CSV（处理引号转义），返回字段列表。
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        fields.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
  }
  fields.add(buf.toString());
  return fields;
}

/// 从 CSV 文本解析账目列表。格式：日期,类型,分类,金额,备注
List<Transaction> parseCsvTransactions(String csvText) {
  final lines = csvText
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];
  // 跳过表头
  final start = lines.first.contains('日期') || lines.first.contains('类型')
      ? 1
      : 0;
  final result = <Transaction>[];
  for (var i = start; i < lines.length; i++) {
    final fields = _parseCsvLine(lines[i]);
    if (fields.length < 4) continue;
    final dateStr = fields[0].trim();
    final typeStr = fields[1].trim();
    final category = fields[2].trim();
    final amount = double.tryParse(fields[3].trim());
    final note = fields.length > 4 ? fields[4].trim() : '';
    final account = fields.length > 5 ? fields[5].trim() : '';
    final tagsStr = fields.length > 6 ? fields[6].trim() : '';
    final currency = fields.length > 7 ? fields[7].trim() : 'CNY';
    if (category.isEmpty || amount == null) continue;
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final type = typeStr == '收入' || typeStr.toLowerCase() == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    result.add(
      Transaction(
        type: type,
        amount: amount,
        category: category,
        date: date,
        note: note,
        account: account,
        tags: tagsStr.split('|').where((s) => s.trim().isNotEmpty).toList(),
        currency: currency.isEmpty ? 'CNY' : currency,
      ),
    );
  }
  return result;
}

/// 选择 CSV 文件并解析为账目列表
Future<List<Transaction>> pickAndImportCsv() async {
  final bytes = await _channel.invokeMethod<Uint8List>('pickFile');
  if (bytes == null) return [];
  // 去掉 UTF-8 BOM
  var text = utf8.decode(bytes);
  if (text.isEmpty) return [];
  if (text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return parseCsvTransactions(text);
}

/// 当前数据库文件路径
Future<String> get dbPath async {
  final dir = await getDatabasesPath();
  return p.join(dir, 'jizhang.db');
}

/// 备份数据库到系统 Download 目录
Future<String> backupDatabase() async {
  final path = await dbPath;
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('数据库文件不存在');
  }
  final bytes = await file.readAsBytes();
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final name =
      'jizhang_backup_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}.db';
  final result = await _channel.invokeMethod<String>('saveFile', {
    'name': name,
    'bytes': bytes,
    'mime': 'application/octet-stream',
  });
  return result ?? name;
}

/// 选择 .db 文件并恢复（返回 true 表示成功，需要调用方重启应用或重新加载数据）
Future<bool> pickAndRestoreDatabase() async {
  final bytes = await _channel.invokeMethod<Uint8List>('pickFile');
  if (bytes == null) return false;
  if (bytes.length < 100 ||
      String.fromCharCodes(bytes.sublist(0, 15)) != 'SQLite format 3') {
    throw StateError('所选文件不是有效的数据库备份');
  }
  final path = await dbPath;
  await File(path).writeAsBytes(bytes);
  return true;
}

/// 推送本月收支数据到桌面小组件
Future<void> updateHomeWidget(double expense, double income) async {
  try {
    await _channel.invokeMethod<void>('updateWidget', {
      'expense': expense,
      'income': income,
    });
  } catch (_) {
    // 忽略：非 Android 或通道未就绪
  }
}
