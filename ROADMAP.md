# 记账 App 纯本地版开发清单

目标：打磨纯本地记账体验，达到可上架安卓商店的程度。数据存储：SQLite（sqflite），不做账号系统和云同步。

## 功能任务

### 1. 编辑账目
- [x] 明细列表点击某条账目，打开编辑弹层（复用记一笔界面，预填数据）
- [x] `TransactionStore` 增加 `update()`，`DatabaseHelper` 增加对应 UPDATE 语句
- [x] 验收：修改金额/分类/备注/日期后保存，列表和统计同步更新，杀进程重开数据正确

### 2. 按月浏览与统计
- [x] 明细页顶部加月份切换器（‹ 2026-11 ›），左右切月
- [x] 明细列表只显示当月账目，显示当月收入/支出小计
- [x] 统计页同样跟随月份切换
- [x] 验收：切到无数据的月份显示空状态；新建其他月份的账目后切换可见

### 3. 导出 CSV 备份
- [x] 「我的」页「导出数据」落地：导出全部账目为 CSV（日期,类型,分类,金额,备注）
- [x] 保存到手机 Download 目录（MainActivity 内 MethodChannel `jizhang/download` 走 MediaStore，无插件、免权限）
- [x] 验收：导出后文件可在文件管理器打开，Excel 打开不乱码（UTF-8 BOM）✅ 真机已验证 /sdcard/Download/jizhang_*.csv

### 4. 自定义分类管理
- [x] 「我的」页「分类管理」落地：查看/新增/删除自定义分类（支出、收入分开）
- [x] 分类存入数据库新表 `categories`，记一笔弹层从库中读取
- [x] 内置默认分类首次启动时写入；删除分类前检查是否被账目使用
- [x] 验收：新增分类后立即可在记一笔中选用；重启后仍在 ✅ 真机已验证（v1→v2 迁移播种、删除保护、新增-选用-重启持久化全链路）

### 5. 上架准备
- [x] 应用图标（替换默认 Flutter 图标）✅ AI 生成品牌图标 + 自适应图标（anydpi-v26）
- [x] 启动页（splash）✅ 品牌绿背景 + 居中图标
- [x] 确认应用名、包名（当前 com.jizhang.app）✅ 应用名「记账」
- [x] 生成 release 签名密钥，配置 `key.properties` ✅ android/app/jizhang-keystore.jks（已 gitignore）
- [x] `flutter build apk --release` 出包并真机安装验证 ✅ app-release.apk 48.7MB
- [x] 验收：release 包安装后功能正常，图标/名称正确 ✅ 桌面图标、记账写库均验证通过

## 环境备忘（每次开发前）

- Flutter SDK：`D:\dev\flutter`（不在 PATH，用全路径调用）
- 终端需先设镜像变量，否则构建会卡死：
  ```powershell
  $env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
  $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
  $env:PUB_CACHE='D:\dev\pub-cache'   # 必须！默认缓存路径含中文（用户目录），会炸 Kotlin/CMake 插件构建
  ```
- 真机调试：手机需开 USB 调试 + USB 安装；安装时留意屏幕弹窗要点「允许」
- 检查依赖：`D:\dev\flutter\bin\flutter.bat analyze`、`flutter.bat test`
- 查看数据库：`adb exec-out run-as com.jizhang.app cat databases/jizhang.db`（二进制安全方式拉取后用 sqlite 工具读）

## 已完成

- [x] 项目初始化（Flutter 3.47.9，Android only）
- [x] 记一笔（金额/分类/备注/日期，支出/收入切换）
- [x] 明细列表（按日期倒序、左滑删除）
- [x] 统计页（本月收支、分类占比）
- [x] sqflite 本地持久化（`transactions` 表）
