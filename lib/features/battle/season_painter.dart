import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/rules/season_rules.dart';

/// 계절 입자 (묶음 14 A4, 그림 없이 코드로): 봄 꽃잎 · 여름 반딧불 · 가을 낙엽 · 겨울 눈송이가
/// 가끔 흩날린다. [t] 0~1 이 흐름(같은 값이면 멈춘 그림). [few] 면 입자를 줄인다(동작 줄이기).
class SeasonPainter extends CustomPainter {
  SeasonPainter({required this.season, this.t = 0, this.few = false, this.seed = 7});

  final Season season;
  final double t;
  final bool few;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final rng = math.Random(seed);
    final p = Paint()..isAntiAlias = true;
    final n = switch (season) {
          Season.spring => 10,
          Season.summer => 9,
          Season.autumn => 9,
          Season.winter => 16,
        } ~/
        (few ? 2 : 1);
    for (var i = 0; i < n; i++) {
      final x0 = rng.nextDouble() * w;
      final ph = rng.nextDouble();
      final sp = 0.5 + rng.nextDouble() * 0.6;
      final v = (t * sp + ph) % 1.0;
      final size0 = 0.7 + rng.nextDouble() * 0.6;
      switch (season) {
        case Season.spring:
          // 분홍 꽃잎이 비스듬히 내려온다
          final o = Offset(x0 + v * w * 0.25 + math.sin(v * 9 + i) * 12, v * h);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(v * 6 + i);
          p.color = const Color(0xFFF7B6CF).withValues(alpha: 0.85 * _edge(v));
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 9 * size0, height: 5 * size0), p);
          canvas.restore();
        case Season.summer:
          // 반딧불: 제자리에서 둥실, 깜빡
          final y0 = h * (0.3 + rng.nextDouble() * 0.6);
          final a = (math.sin(v * math.pi * 2) * 0.5 + 0.5) * 0.8;
          final o = Offset(x0 + math.sin(v * 6.28 + i) * 10, y0 + math.cos(v * 6.28 + i) * 8);
          canvas.drawCircle(o, 5, p..color = Color.fromRGBO(220, 255, 140, a * 0.25));
          canvas.drawCircle(o, 1.8, p..color = Color.fromRGBO(240, 255, 170, a));
        case Season.autumn:
          // 주황·갈색 낙엽이 흔들리며 떨어진다
          final o = Offset(x0 + math.sin(v * 7 + i) * 18, v * h);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(math.sin(v * 5 + i) * 1.2);
          p.color = (i.isEven ? const Color(0xFFE8893A) : const Color(0xFFB8642E))
              .withValues(alpha: 0.85 * _edge(v));
          final leaf = Path()
            ..moveTo(0, -6 * size0)
            ..quadraticBezierTo(5 * size0, 0, 0, 6 * size0)
            ..quadraticBezierTo(-5 * size0, 0, 0, -6 * size0);
          canvas.drawPath(leaf, p);
          canvas.restore();
        case Season.winter:
          // 눈송이가 천천히 내려온다
          final o = Offset(x0 + math.sin(v * 8 + i) * 6, v * h);
          p.color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * _edge(v));
          canvas.drawCircle(o, 1.6 + (i % 3) * 0.7, p);
      }
    }
  }

  /// 위아래 끝에서 서서히 나타나고 사라진다
  static double _edge(double v) => (math.min(v, 1 - v) * 8).clamp(0.0, 1.0);

  @override
  bool shouldRepaint(SeasonPainter old) =>
      old.t != t || old.season != season || old.few != few;
}
