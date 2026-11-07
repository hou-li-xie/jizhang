# 记账 (jizhang)

一款简洁的个人记账 Android 应用，使用 Flutter / Dart 开发。

## 功能

- **明细**：账目列表（支出 / 收入、分类、备注、日期），左滑删除
- **记一笔**：首页右下角按钮，弹出表单记录金额、分类、备注、日期
- **统计**：本月收支概览与支出分类占比
- **我的**：分类管理、导出数据等（规划中）

## 项目结构

```
lib/
  main.dart                        # 应用入口与主题
  models/transaction.dart          # 账目数据模型
  store/transaction_store.dart     # 内存账目仓库（后续可替换为数据库）
  pages/
    home_page.dart                 # 主框架：底部导航
    transaction_list_page.dart     # 明细页
    stats_page.dart                # 统计页
  widgets/
    add_transaction_sheet.dart     # “记一笔”弹层
```

## 运行

```bash
flutter pub get
flutter run
```

## 测试

```bash
flutter test
```
