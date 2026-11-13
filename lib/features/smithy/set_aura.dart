import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rules/rules.dart' show BossGearRules, BossSet;

/// 보스 장비 6부위를 다 입었을 때 각성자 둘레 세트 무늬·반짝임 (묶음 19 6-3, #82).
/// 전신 그림 대신, 세트마다 다른 무늬가 천천히 돈다.
///
/// - 문지기: 돌 룬 네모가 둘레를 돈다
/// - 불꽃: 불씨가 아래에서 위로 오른다
/// - 서리: 눈꽃 반짝임이 내려온다
/// - 숲: 나뭇잎이 둘레를 감돈다
/// - 밤: 초승달 하나와 별이 깜박인다
/// - 하늘: 작은 번개 불꽃이 튄다
class SetAuraPattern extends StatefulWidget {
  const SetAuraPattern({super.key, required this.set});

  final BossSet set;

  /// 세트 빛 색으로 세트를 찾는다 (빛 색은 세트마다 다르다)
  static BossSet? ofAura(Color? aura) {
    if (aura == null) return null;
    for (final s in BossGearRules.sets) {
      if (s.aura == aura.toARGB32()) return s.id;
    }
    return null;
  }

  @override
  State<SetAuraPattern> createState() => _SetAuraPatternState();
}

class _SetAuraPatternState extends State<SetAuraPattern>
    with SingleTickerProviderStateMixin {
  // 끝없이 돌지 않게 (시험·배터리): 6초 × 40번
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat(count: 40);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = Color(BossGearRules.info(widget.set).aura);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) => CustomPaint(
            key: Key('setAura_${widget.set.name}'),
            painter: _SetPainter(widget.set, color, still ? 0.25 : _a.value),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SetPainter extends CustomPainter {
  _SetPainter(this.set, this.color, this.t);

  final BossSet set;
  final Color color;
  final double t;

  static const _n = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.55);
    final rx = size.width * 0.42, ry = size.height * 0.42;
    final rnd = math.Random(set.index * 31 + 7);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
    switch (set) {
      case BossSet.warden:
        // 돌 룬: 둘레를 천천히 도는 네모 8개
        for (var i = 0; i < 8; i++) {
          final a = (i / 8 + t * 0.5) * math.pi * 2;
          final p = c + Offset(math.cos(a) * rx, math.sin(a) * ry * 0.55);
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(a + t * math.pi * 2);
          canvas.drawRect(
              const Rect.fromLTWH(-4, -4, 8, 8),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..color = color.withValues(alpha: 0.9)
                ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2));
          canvas.restore();
        }
      case BossSet.flame:
        // 불씨: 아래에서 위로
        for (var i = 0; i < _n + 4; i++) {
          final x0 = rnd.nextDouble();
          final phase = (t * 2 + rnd.nextDouble()) % 1;
          final x = c.dx + (x0 - 0.5) * rx * 1.6 +
              math.sin((phase + x0) * math.pi * 4) * 6;
          final y = size.height * (0.95 - phase * 0.85);
          canvas.drawCircle(Offset(x, y), 2.4 * (1 - phase) + 0.8,
              glow..color = color.withValues(alpha: 0.9 * (1 - phase)));
        }
      case BossSet.frost:
        // 눈꽃: 위에서 천천히 내려오며 반짝
        for (var i = 0; i < _n; i++) {
          final x0 = rnd.nextDouble();
          final phase = (t + rnd.nextDouble()) % 1;
          final p = Offset(c.dx + (x0 - 0.5) * rx * 2,
              size.height * (0.08 + phase * 0.85));
          _flake(canvas, p, 4 + 2 * math.sin(phase * math.pi), phase * 3,
              color.withValues(alpha: 0.95 * math.sin(phase * math.pi)));
        }
      case BossSet.grove:
        // 나뭇잎: 둘레를 감돈다
        for (var i = 0; i < 7; i++) {
          final a = (i / 7 + t) * math.pi * 2;
          final p = c +
              Offset(math.cos(a) * rx,
                  math.sin(a) * ry * 0.7 + math.sin(a * 2 + t * 6) * 6);
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(a + math.pi / 4);
          canvas.drawOval(const Rect.fromLTWH(-6, -2.6, 12, 5.2),
              Paint()..color = color.withValues(alpha: 0.85));
          canvas.restore();
        }
      case BossSet.night:
        // 초승달 + 깜박이는 별
        final moon = Offset(c.dx + rx * 0.7, size.height * 0.16);
        canvas.drawPath(
            Path.combine(
                PathOperation.difference,
                Path()..addOval(Rect.fromCircle(center: moon, radius: 9)),
                Path()
                  ..addOval(Rect.fromCircle(
                      center: moon + const Offset(4, -3), radius: 8))),
            glow..color = color.withValues(alpha: 0.9));
        for (var i = 0; i < _n; i++) {
          final p = Offset(c.dx + (rnd.nextDouble() - 0.5) * rx * 2.1,
              size.height * (0.08 + rnd.nextDouble() * 0.8));
          final tw = 0.5 + 0.5 * math.sin((t * 4 + rnd.nextDouble()) * math.pi * 2);
          _star(canvas, p, 2 + 3 * tw, color.withValues(alpha: 0.3 + 0.7 * tw));
        }
      case BossSet.storm:
        // 번개 불꽃: 둘레 여기저기에서 짧게 튄다
        for (var i = 0; i < 6; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final on = ((t * 6 + i / 6) % 1) < 0.35;
          if (!on) continue;
          final p = c + Offset(math.cos(a) * rx, math.sin(a) * ry * 0.8);
          final path = Path()..moveTo(p.dx, p.dy - 9);
          path
            ..lineTo(p.dx - 3, p.dy - 1)
            ..lineTo(p.dx + 2, p.dy)
            ..lineTo(p.dx - 2, p.dy + 9);
          canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round
                ..color = color
                ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5));
        }
    }
    // 모든 세트: 발밑에 세트 빛 고리
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx, size.height * 0.97),
            width: rx * 1.8,
            height: 14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.5 + 0.3 * math.sin(t * math.pi * 6))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _flake(Canvas canvas, Offset p, double r, double rot, Color col) {
    final paint = Paint()
      ..color = col
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final a = rot + k * math.pi / 3;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(p - d, p + d, paint);
    }
  }

  void _star(Canvas canvas, Offset p, double r, Color col) {
    final paint = Paint()..color = col;
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SetPainter old) =>
      old.t != t || old.set != set || old.color != color;
}
