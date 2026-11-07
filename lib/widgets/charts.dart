import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 图表统一配色（按顺序循环使用）
const chartPalette = <Color>[
  Color(0xFF2F9E6E),
  Color(0xFFF2B84B),
  Color(0xFF6C93E8),
  Color(0xFFEF7C5B),
  Color(0xFF9B7EDE),
  Color(0xFF4FB6C9),
  Color(0xFF4EC49A),
  Color(0xFFB0B8C1),
];

/// 环形饼图：展示各分类占比，圆心显示合计金额。
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({
    super.key,
    required this.entries,
    required this.total,
    this.size = 160,
    this.centerLabel = '总支出',
  });

  /// 已按金额倒序排好的分类数据
  final List<MapEntry<String, double>> entries;
  final double total;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _PiePainter(entries: entries, total: total),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                '¥${total.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.entries, required this.total});

  final List<MapEntry<String, double>> entries;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (total <= 0) {
      paint.color = const Color(0xFFE3E7EB);
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }

    // 从 12 点方向顺时针绘制
    var start = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * 2 * math.pi;
      if (sweep <= 0) continue;
      paint.color = chartPalette[i % chartPalette.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
}

/// 折线图的一条数据系列（一个分类在各时间点上的金额）
class TrendSeries {
  const TrendSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

/// 趋势图展示形态
enum TrendChartStyle { line, bar }

/// 折线图内边距，绘制与命中测试共用
const double _padLeft = 44;
const double _padRight = 8;
const double _padTop = 12;
const double _padBottom = 24;

/// 把最大值放大到刻度上限，让顶点不贴边
double _niceMax(double value) {
  if (value <= 0) return 100;
  final exponent = (math.log(value) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final normalized = value / base;
  final step = normalized <= 1
      ? 1.0
      : normalized <= 2
          ? 2.0
          : normalized <= 5
              ? 5.0
              : 10.0;
  return step * base;
}

/// 命中的数据点：第几条系列、第几个时间点
class _ChartHit {
  const _ChartHit(this.seriesIndex, this.pointIndex);

  final int seriesIndex;
  final int pointIndex;

  @override
  bool operator ==(Object other) =>
      other is _ChartHit &&
      other.seriesIndex == seriesIndex &&
      other.pointIndex == pointIndex;

  @override
  int get hashCode => Object.hash(seriesIndex, pointIndex);
}

/// 趋势图：支持折线 / 柱状两种形态切换，带 Y 轴金额刻度、网格线与生长动画。
/// 点击数据点或柱子会弹出「月份 + 分类 + 金额」气泡。
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.labels,
    required this.series,
    this.style = TrendChartStyle.line,
    this.height = 200,
  });

  /// X 轴标签（与各系列的 values 一一对应）
  final List<String> labels;
  final List<TrendSeries> series;
  final TrendChartStyle style;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart>
    with SingleTickerProviderStateMixin {
  _ChartHit? _selected;

  /// 折线 / 柱状切换的过渡进度（0 = 旧形态，1 = 新形态）
  late final AnimationController _transition;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) {
      _selected = null;
      _transition.forward(from: 0);
    }
    // 数据变化后旧索引可能失效，直接清除选中
    if (oldWidget.series.length != widget.series.length ||
        oldWidget.labels.length != widget.labels.length ||
        !oldWidget.series
            .every((s) => widget.series.any((w) => w.label == s.label))) {
      _selected = null;
    }
  }

  double get _maxY {
    final maxRaw = widget.series.fold<double>(
      0.0,
      (m, s) => math.max(
        m,
        s.values.fold<double>(0.0, (a, b) => math.max(a, b)),
      ),
    );
    return _niceMax(maxRaw * 1.15);
  }

  Offset _pointAt(int seriesIndex, int pointIndex, Size size) {
    final values = widget.series[seriesIndex].values;
    final chartWidth = size.width - _padLeft - _padRight;
    final chartHeight = size.height - _padTop - _padBottom;
    final x = _padLeft +
        (values.length == 1
            ? chartWidth / 2
            : chartWidth * pointIndex / (values.length - 1));
    final y = _padTop +
        chartHeight * (1 - (_maxY == 0 ? 0 : values[pointIndex] / _maxY));
    return Offset(x, y);
  }

  /// 单个柱子的矩形（不含动画进度）
  Rect _barRect(int seriesIndex, int pointIndex, Size size) {
    final chartWidth = size.width - _padLeft - _padRight;
    final chartHeight = size.height - _padTop - _padBottom;
    final count = widget.labels.length;
    if (count == 0) return Rect.zero;
    final seriesCount = widget.series.length;
    const innerGap = 3.0;
    final groupWidth = chartWidth / count;
    final barWidth = (((groupWidth * 0.66) - innerGap * (seriesCount - 1)) /
            seriesCount)
        .clamp(2.0, 26.0)
        .toDouble();
    final totalWidth =
        barWidth * seriesCount + innerGap * (seriesCount - 1);
    final groupLeft =
        _padLeft + (groupWidth - totalWidth) / 2 + groupWidth * pointIndex;
    final value = widget.series[seriesIndex].values[pointIndex];
    final height =
        (_maxY == 0 ? 0.0 : value / _maxY) * chartHeight;
    final left = groupLeft + seriesIndex * (barWidth + innerGap);
    return Rect.fromLTWH(
      left,
      _padTop + chartHeight - height,
      barWidth,
      height,
    );
  }

  _ChartHit? _hitTest(Offset local, Size size) {
    if (widget.style == TrendChartStyle.bar) {
      final chartBottom = size.height - _padBottom;
      for (var si = 0; si < widget.series.length; si++) {
        for (var pi = 0; pi < widget.labels.length; pi++) {
          final rect = _barRect(si, pi, size);
          // 柱子太矮时把命中区延伸到底部，方便点中
          final hitArea = Rect.fromLTRB(
            rect.left - 2,
            rect.top,
            rect.right + 2,
            chartBottom,
          );
          if (hitArea.contains(local)) return _ChartHit(si, pi);
        }
      }
      return null;
    }

    const threshold = 22.0;
    var best = threshold;
    _ChartHit? hit;
    for (var si = 0; si < widget.series.length; si++) {
      final values = widget.series[si].values;
      for (var pi = 0; pi < values.length; pi++) {
        final distance = (_pointAt(si, pi, size) - local).distance;
        if (distance < best) {
          best = distance;
          hit = _ChartHit(si, pi);
        }
      }
    }
    return hit;
  }

  void _handleTap(Offset local, Size size) {
    final hit = _hitTest(local, size);
    setState(() {
      _selected = (hit != null && hit == _selected) ? null : hit;
    });
  }

  /// 气泡锚点：折线用数据点，柱状用柱顶中点
  Offset _anchorAt(int seriesIndex, int pointIndex, Size size) {
    if (widget.style == TrendChartStyle.bar) {
      final rect = _barRect(seriesIndex, pointIndex, size);
      return Offset(rect.center.dx, rect.top);
    }
    return _pointAt(seriesIndex, pointIndex, size);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _handleTap(details.localPosition, size),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _transition,
                    builder: (context, _) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) => CustomPaint(
                        painter: _TrendPainter(
                          labels: widget.labels,
                          series: widget.series,
                          style: widget.style,
                          progress: progress,
                          transition: _transition.value,
                          selected: _selected,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_selected != null) _buildBubble(size),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubble(Size size) {
    final hit = _selected!;
    final series = widget.series[hit.seriesIndex];
    final value = series.values[hit.pointIndex];
    final anchor = _anchorAt(hit.seriesIndex, hit.pointIndex, size);

    const bubbleWidth = 150.0;
    final left = (anchor.dx - bubbleWidth / 2)
        .clamp(4.0, math.max(4.0, size.width - bubbleWidth - 4))
        .toDouble();
    var top = anchor.dy - 58;
    if (top < 0) top = anchor.dy + 16;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: bubbleWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF21F2933),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.labels[hit.pointIndex],
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: series.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      series.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¥${value.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.labels,
    required this.series,
    required this.style,
    required this.progress,
    required this.transition,
    this.selected,
  });

  final List<String> labels;
  final List<TrendSeries> series;
  final TrendChartStyle style;
  final double progress;
  final double transition;
  final _ChartHit? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - _padLeft - _padRight;
    final chartHeight = size.height - _padTop - _padBottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxRaw = series.fold<double>(
      0.0,
      (m, s) => math.max(
        m,
        s.values.fold<double>(0.0, (a, b) => math.max(a, b)),
      ),
    );
    final maxY = _niceMax(maxRaw * 1.15);

    // 网格线与 Y 轴刻度（顶部 / 中部 / 底部）
    final gridPaint = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 1;
    const tickStyle = TextStyle(fontSize: 10, color: Color(0x8A000000));
    for (var i = 0; i <= 2; i++) {
      final y = _padTop + chartHeight * i / 2;
      canvas.drawLine(
        Offset(_padLeft, y),
        Offset(size.width - _padRight, y),
        gridPaint,
      );
      _paintText(
        canvas,
        _formatTick(maxY * (1 - i / 2)),
        Offset(_padLeft - 6, y),
        tickStyle,
        alignRight: true,
      );
    }

    if (labels.isEmpty) return;

    // X 轴标签，过多时抽稀
    final interval = math.max(1, (labels.length / 6).ceil());
    const axisStyle = TextStyle(fontSize: 10, color: Color(0x8A000000));
    for (var i = 0; i < labels.length; i++) {
      if (i % interval != 0) continue;
      _paintText(
        canvas,
        labels[i],
        Offset(
          _xAt(i, labels.length, chartWidth),
          size.height - _padBottom / 2,
        ),
        axisStyle,
        centerX: true,
      );
    }

    final t = Curves.easeInOutCubic.transform(transition);

    void drawShape(TrendChartStyle target, double opacity, double grow) {
      if (opacity <= 0.01) return;
      // 整层透明度，用于新旧形态交叉淡化
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
      if (target == TrendChartStyle.bar) {
        _paintBars(canvas, size, chartWidth, chartHeight, maxY, grow);
      } else {
        _paintLines(canvas, chartWidth, chartHeight, maxY);
      }
      canvas.restore();
    }

    if (transition >= 0.999) {
      drawShape(style, 1, 1);
    } else {
      // 切换中：旧形态淡出收缩，新形态淡入生长
      final other = style == TrendChartStyle.bar
          ? TrendChartStyle.line
          : TrendChartStyle.bar;
      drawShape(other, 1 - t, 1 - t);
      drawShape(style, t, t);
    }
  }

  void _paintBars(
    Canvas canvas,
    Size size,
    double chartWidth,
    double chartHeight,
    double maxY,
    double grow,
  ) {
    final chartBottom = _padTop + chartHeight;
    for (var pi = 0; pi < labels.length; pi++) {
      for (var si = 0; si < series.length; si++) {
        final value = series[si].values[pi];
        final height =
            (maxY == 0 ? 0.0 : value * progress * grow / maxY) * chartHeight;
        if (height <= 0.3) continue;
        final rect = _barRectAt(si, pi, size, chartWidth, chartHeight, maxY);
        final bar = Rect.fromLTWH(
          rect.left,
          chartBottom - height,
          rect.width,
          height,
        );
        final rrect = RRect.fromRectAndCorners(
          bar,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        final isSelected = selected != null &&
            selected!.seriesIndex == si &&
            selected!.pointIndex == pi;
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = isSelected
                ? series[si].color
                : series[si].color.withValues(alpha: 0.82),
        );
        if (isSelected) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  Rect _barRectAt(
    int seriesIndex,
    int pointIndex,
    Size size,
    double chartWidth,
    double chartHeight,
    double maxY,
  ) {
    final count = labels.length;
    final seriesCount = series.length;
    const innerGap = 3.0;
    final groupWidth = chartWidth / count;
    final barWidth = (((groupWidth * 0.66) - innerGap * (seriesCount - 1)) /
            seriesCount)
        .clamp(2.0, 26.0)
        .toDouble();
    final totalWidth = barWidth * seriesCount + innerGap * (seriesCount - 1);
    final groupLeft =
        _padLeft + (groupWidth - totalWidth) / 2 + groupWidth * pointIndex;
    final value = series[seriesIndex].values[pointIndex];
    final height = (maxY == 0 ? 0.0 : value / maxY) * chartHeight;
    final left = groupLeft + seriesIndex * (barWidth + innerGap);
    return Rect.fromLTWH(
      left,
      _padTop + chartHeight - height,
      barWidth,
      height,
    );
  }

  void _paintLines(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double maxY,
  ) {
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.values.isEmpty) continue;
      final points = <Offset>[
        for (var i = 0; i < s.values.length; i++)
          Offset(
            _xAt(i, s.values.length, chartWidth),
            _yAt(s.values[i] * progress, maxY, chartHeight),
          ),
      ];

      // 单系列时补一层渐变面积，增强层次感
      if (series.length == 1 && points.length > 1) {
        final fill = Path.from(_smoothPath(points))
          ..lineTo(points.last.dx, _padTop + chartHeight)
          ..lineTo(points.first.dx, _padTop + chartHeight)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.20),
                s.color.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromLTWH(_padLeft, _padTop, chartWidth, chartHeight),
            ),
        );
      }

      canvas.drawPath(
        _smoothPath(points),
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      // 数据点过多时省略，避免糊成一片
      if (points.length <= 12) {
        final dotFill = Paint()..color = Colors.white;
        final dotBorder = Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        for (var i = 0; i < points.length; i++) {
          final isSelected = selected != null &&
              selected!.seriesIndex == si &&
              selected!.pointIndex == i;
          final radius = isSelected ? 5.0 : 3.0;
          if (isSelected) {
            canvas.drawCircle(
              points[i],
              9,
              Paint()..color = s.color.withValues(alpha: 0.18),
            );
          }
          canvas.drawCircle(points[i], radius, dotFill);
          canvas.drawCircle(points[i], radius, dotBorder);
        }
      }
    }
  }

  double _xAt(int i, int count, double width) =>
      _padLeft + (count == 1 ? width / 2 : width * i / (count - 1));

  double _yAt(double value, double maxY, double height) =>
      _padTop + height * (1 - (maxY == 0 ? 0 : value / maxY));

  /// 用二次贝塞尔把折线笔直段变成平滑曲线
  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    for (var i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final next = points[i + 1];
      final mid = Offset((p.dx + next.dx) / 2, (p.dy + next.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  String _formatTick(double value) {
    if (value >= 10000) {
      final wan = value / 10000;
      return '${wan.toStringAsFixed(wan % 1 == 0 ? 0 : 1)}万';
    }
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(value.abs() < 10 ? 1 : 0);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    bool alignRight = false,
    bool centerX = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = position.dx;
    if (alignRight) dx -= tp.width;
    if (centerX) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, position.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
