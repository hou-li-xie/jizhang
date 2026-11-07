import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/home_page.dart';
import 'store/transaction_store.dart';

/// 品牌绿，与 Android 启动页背景一致
const brandGreen = Color(0xFF0DBE64);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TransactionStore();
  await store.init();
  runApp(JizhangApp(store: store));
}

class JizhangApp extends StatelessWidget {
  const JizhangApp({
    super.key,
    required this.store,
    this.splashDuration = const Duration(milliseconds: 1500),
  });

  final TransactionStore store;

  /// 启动页停留时长（测试中可传 Duration.zero）
  final Duration splashDuration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账',
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F9E6E)),
        useMaterial3: true,
      ),
      home: SplashGate(
        duration: splashDuration,
        child: HomePage(store: store),
      ),
    );
  }
}

/// 启动页闸门：先展示品牌页 [duration]，随后淡入主界面。
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    required this.duration,
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _done
          ? widget.child
          : const _SplashScreen(key: ValueKey('splash')),
    );
  }
}

/// 启动页视觉：品牌绿背景 + 白色账本图标 + 应用名
class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC61F),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '¥',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '记账',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
