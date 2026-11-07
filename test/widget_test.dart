import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang/main.dart';
import 'package:jizhang/models/transaction.dart';
import 'package:jizhang/pages/stats_page.dart';
import 'package:jizhang/store/transaction_store.dart';
import 'package:jizhang/utils/csv_export.dart';
import 'package:jizhang/widgets/charts.dart';

void main() {
  testWidgets('应用启动后显示记账首页与底部导航', (WidgetTester tester) async {
    // 测试环境使用纯内存仓库，避免依赖原生 SQLite
    await tester.pumpWidget(JizhangApp(store: TransactionStore.memory()));
    // 跳过启动页（1.5s 停留 + 淡入）
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('记账'), findsOneWidget);
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('这个月还没有账目'), findsOneWidget);
  });

  testWidgets('明细页按月份过滤账目，可左右切换月份', (WidgetTester tester) async {
    final store = TransactionStore.memory();
    await store.add(Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 12,
      category: '餐饮',
      note: '本月',
      date: DateTime.now(),
    ));
    await store.add(Transaction(
      id: 2,
      type: TransactionType.expense,
      amount: 99,
      category: '购物',
      note: '上月',
      date: DateTime(DateTime.now().year, DateTime.now().month - 1, 15),
    ));
    await tester.pumpWidget(JizhangApp(store: store));
    // 跳过启动页（1.5s 停留 + 淡入）
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 默认当前月：只看到本月账目
    expect(find.text('餐饮 · 本月'), findsOneWidget);
    expect(find.text('购物 · 上月'), findsNothing);
    expect(find.text('支出 ¥12.00'), findsOneWidget);

    // 切到上月：只看到上月账目
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    expect(find.text('购物 · 上月'), findsOneWidget);
    expect(find.text('餐饮 · 本月'), findsNothing);
    expect(find.text('支出 ¥99.00'), findsOneWidget);

    // 切回当前月后右箭头禁用（不看未来）
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    final rightButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ).first,
    );
    expect(rightButton.onPressed, isNull);
  });

  test('仓库 update 能修改账目并更新合计', () async {
    final store = TransactionStore.memory();
    final t = Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 12,
      category: '餐饮',
      date: DateTime(2026, 11, 6),
    );
    await store.add(t);
    expect(store.totalExpense, 12);

    await store.update(Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 35.5,
      category: '交通',
      date: DateTime(2026, 11, 6),
      note: '打车',
    ));
    expect(store.totalExpense, 35.5);
    expect(store.transactions.single.category, '交通');
    expect(store.transactions.single.note, '打车');
  });

  testWidgets('点击账目打开编辑弹层，保存后列表更新', (WidgetTester tester) async {
    final store = TransactionStore.memory();
    await store.add(Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 12,
      category: '餐饮',
      date: DateTime(2026, 11, 6),
    ));
    await tester.pumpWidget(JizhangApp(store: store));
    // 跳过启动页（1.5s 停留 + 淡入）
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 点击账目，弹层应预填原数据
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '12.00'), findsOneWidget);

    // 修改金额并保存
    await tester.enterText(find.widgetWithText(TextField, '12.00'), '35.5');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('-¥35.50'), findsOneWidget);
    expect(store.totalExpense, 35.5);
  });

  test('CSV 导出包含表头、转义和正确格式', () {
    final csv = buildCsv([
      Transaction(
        type: TransactionType.expense,
        amount: 12.5,
        category: '餐饮',
        note: '午餐, 加辣',
        date: DateTime(2026, 11, 6),
      ),
      Transaction(
        type: TransactionType.income,
        amount: 1000,
        category: '工资',
        date: DateTime(2026, 11, 1),
      ),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines[0], '日期,类型,分类,金额,备注');
    expect(lines[1], '2026-11-06,支出,餐饮,12.50,"午餐, 加辣"');
    expect(lines[2], '2026-11-01,收入,工资,1000.00,');
  });

  test('分类管理：默认分类就绪，可增删，被引用时禁止删除', () async {
    final store = TransactionStore.memory();

    // 内置默认分类（支出/收入分开）
    expect(store.categoriesFor(TransactionType.expense).map((c) => c.name),
        containsAll(['餐饮', '交通', '其他']));
    expect(store.categoriesFor(TransactionType.income).map((c) => c.name),
        containsAll(['工资', '其他']));

    // 新增自定义分类，重复/空白名称被忽略
    await store.addCategory('宠物', TransactionType.expense);
    await store.addCategory('宠物', TransactionType.expense);
    await store.addCategory('  ', TransactionType.expense);
    final expenseNames =
        store.categoriesFor(TransactionType.expense).map((c) => c.name);
    expect(expenseNames.where((n) => n == '宠物').length, 1);
    // 收入分类不受支出新增影响
    expect(store.categoriesFor(TransactionType.income).map((c) => c.name),
        isNot(contains('宠物')));

    // 未被引用的分类可删除
    final pet = store
        .categoriesFor(TransactionType.expense)
        .firstWhere((c) => c.name == '宠物');
    expect(await store.deleteCategory(pet), isTrue);
    expect(store.categoriesFor(TransactionType.expense).map((c) => c.name),
        isNot(contains('宠物')));

    // 被账目引用的分类禁止删除
    await store.add(Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 15,
      category: '餐饮',
      date: DateTime(2026, 11, 6),
    ));
    final food = store
        .categoriesFor(TransactionType.expense)
        .firstWhere((c) => c.name == '餐饮');
    expect(await store.categoryUsageCount(food), 1);
    expect(await store.deleteCategory(food), isFalse);
    expect(store.categoriesFor(TransactionType.expense).map((c) => c.name),
        contains('餐饮'));
  });

  testWidgets('分类管理页新增分类后，记一笔弹层可选用', (WidgetTester tester) async {
    final store = TransactionStore.memory();
    await tester.pumpWidget(JizhangApp(store: store));
    // 跳过启动页（1.5s 停留 + 淡入）
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 「我的」页进入分类管理
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类管理'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);

    // 新增支出分类「宠物」
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '宠物');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('宠物'), findsOneWidget);

    // 回到明细页打开记一笔，新分类出现在选项中
    // 返回明细页（中文本地化后 tooltip 不是 Back，直接点返回按钮）
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('明细'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '宠物'), findsOneWidget);
  });

  testWidgets('统计页展示近 6 个月折线图与分类占比饼图', (WidgetTester tester) async {
    final store = TransactionStore.memory();
    final now = DateTime.now();
    // 当月：餐饮 30 + 交通 20；上月：餐饮 80
    await store.add(Transaction(
      id: 1,
      type: TransactionType.expense,
      amount: 30,
      category: '餐饮',
      date: now,
    ));
    await store.add(Transaction(
      id: 2,
      type: TransactionType.expense,
      amount: 20,
      category: '交通',
      date: now,
    ));
    await store.add(Transaction(
      id: 3,
      type: TransactionType.expense,
      amount: 80,
      category: '餐饮',
      date: DateTime(now.year, now.month - 1, 10),
    ));
    // 4 个月前：购物 200（只在近 6 个月窗口内）
    await store.add(Transaction(
      id: 4,
      type: TransactionType.expense,
      amount: 200,
      category: '购物',
      date: DateTime(now.year, now.month - 4, 5),
    ));

    await tester.pumpWidget(JizhangApp(store: store));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    expect(find.byType(TrendChart), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget);
    expect(find.text('近 6 个月'), findsOneWidget);
    // 近 6 个月合计 = 30 + 20 + 80 + 200
    expect(find.text('合计 ¥330.00'), findsOneWidget);

    // 切换为近 3 个月，4 个月前那笔不再计入
    await tester.ensureVisible(find.text('近 6 个月'));
    await tester.tap(find.text('近 6 个月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近 3 个月'));
    await tester.pumpAndSettle();
    expect(find.text('合计 ¥130.00'), findsOneWidget);

    // 分类多选：近 3 个月窗口内只有餐饮、交通，默认全选
    expect(find.widgetWithText(FilterChip, '餐饮'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '交通'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '购物'), findsNothing);

    // 取消「交通」后合计只算餐饮 110
    await tester.ensureVisible(find.widgetWithText(FilterChip, '交通'));
    await tester.tap(find.widgetWithText(FilterChip, '交通'));
    await tester.pumpAndSettle();
    expect(find.text('合计 ¥110.00'), findsOneWidget);

    // 点击折线末点（11 月餐饮 30，maxY=100 → y≈127）弹出气泡
    await tester.ensureVisible(find.byType(TrendChart));
    await tester.pumpAndSettle();
    final chartRect = tester.getRect(find.byType(TrendChart));
    Finder bubbleText(String text) => find.descendant(
          of: find.byType(TrendChart),
          matching: find.text(text),
        );

    await tester.tapAt(Offset(chartRect.right - 8, chartRect.top + 127));
    await tester.pumpAndSettle();
    expect(bubbleText('11月'), findsOneWidget);
    expect(bubbleText('¥30.00'), findsOneWidget);

    // 点第一个数据点（9 月餐饮 0，y≈176）气泡切到 ¥0.00
    await tester.tapAt(Offset(chartRect.left + 44, chartRect.top + 176));
    await tester.pumpAndSettle();
    expect(bubbleText('¥30.00'), findsNothing);
    expect(bubbleText('¥0.00'), findsOneWidget);

    // 点图表上方空白处收起气泡
    await tester.tapAt(Offset(chartRect.left + 200, chartRect.top + 20));
    await tester.pumpAndSettle();
    expect(bubbleText('¥0.00'), findsNothing);

    // 切换到柱状图
    await tester.ensureVisible(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TrendChart>(find.byType(TrendChart)).style,
      TrendChartStyle.bar,
    );

    // 切回折线图
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TrendChart>(find.byType(TrendChart)).style,
      TrendChartStyle.line,
    );

    // 饼图在页面下方，先滚动到可见
    await tester.scrollUntilVisible(
      find.byType(CategoryPieChart),
      200,
      scrollable: find
          .descendant(
            of: find.byType(StatsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(CategoryPieChart), findsOneWidget);
    // 当月餐饮占比 30/50 = 60%
    expect(find.text('60%'), findsOneWidget);
  });
}
