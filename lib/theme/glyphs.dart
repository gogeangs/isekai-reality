import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 금색 게임 아이콘 (묶음 16 #120). 글자 기호(▶ ⚠ ✦ ✓ ● ○ ✚) 대신 쓴다.
enum Glyph { play, fast, warn, sparkle, check, plus, dot, ring, ad, lock }

class GameGlyph extends StatelessWidget {
  const GameGlyph(this.glyph, {super.key, this.size = 16, this.dim = false});

  final Glyph glyph;
  final double size;

  /// 꺼진 모습 (어둡게)
  final bool dim;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GlyphPainter(glyph, dim)),
      );
}

/// 채운 점 ● / 빈 점 ○ 줄 (남은 횟수 등)
class GlyphDots extends StatelessWidget {
  const GlyphDots(
      {super.key,
      required this.filled,
      required this.total,
      this.size = 12,
      this.blank = 0});

  final int filled;
  final int total;

  /// 아직 쓰지 않은 칸 (흐린 작은 점)
  final int blank;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total + blank; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.12),
              child: GameGlyph(
                  i < filled ? Glyph.dot : Glyph.ring,
                  size: size,
                  dim: i >= total),
            ),
        ],
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.dim);

  final Glyph glyph;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dim
            ? [AppColors.textMuted, AppColors.textMuted]
            : const [AppColors.goldBright, AppColors.gold],
      ).createShader(rect);
    final edge = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06
      ..color = AppColors.goldInk.withValues(alpha: dim ? 0.3 : 0.55);
    final line = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.16
      ..shader = fill.shader;

    Path tri(double x0, double w) => Path()
      ..moveTo(x0, s * 0.18)
      ..lineTo(x0 + w, s * 0.5)
      ..lineTo(x0, s * 0.82)
      ..close();

    switch (glyph) {
      case Glyph.play:
        final p = tri(s * 0.24, s * 0.58);
        canvas
          ..drawPath(p, fill)
          ..drawPath(p, edge);
      case Glyph.fast:
        for (final x in [s * 0.08, s * 0.48]) {
          final p = tri(x, s * 0.44);
          canvas
            ..drawPath(p, fill)
            ..drawPath(p, edge);
        }
      case Glyph.ad:
        // 둥근 판 위 재생 삼각형
        final r = RRect.fromRectAndRadius(
            rect.deflate(s * 0.04), Radius.circular(s * 0.24));
        canvas
          ..drawRRect(r, fill)
          ..drawRRect(r, edge);
        final p = Path()
          ..moveTo(s * 0.38, s * 0.28)
          ..lineTo(s * 0.74, s * 0.5)
          ..lineTo(s * 0.38, s * 0.72)
          ..close();
        canvas.drawPath(p, Paint()..color = AppColors.goldInk);
      case Glyph.warn:
        final p = Path()
          ..moveTo(s * 0.5, s * 0.06)
          ..lineTo(s * 0.96, s * 0.9)
          ..lineTo(s * 0.04, s * 0.9)
          ..close();
        canvas
          ..drawPath(p, fill)
          ..drawPath(p, edge);
        final ink = Paint()
          ..color = AppColors.goldInk
          ..strokeWidth = s * 0.12
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(Offset(s * 0.5, s * 0.36), Offset(s * 0.5, s * 0.6), ink)
          ..drawCircle(Offset(s * 0.5, s * 0.76), s * 0.06,
              Paint()..color = AppColors.goldInk);
      case Glyph.sparkle:
        final c = Offset(s / 2, s / 2);
        final p = Path();
        for (var i = 0; i < 8; i++) {
          final a = -math.pi / 2 + i * math.pi / 4;
          final r = i.isEven ? s * 0.48 : s * 0.13;
          final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
        canvas
          ..drawPath(p, fill)
          ..drawPath(p, edge);
      case Glyph.check:
        final p = Path()
          ..moveTo(s * 0.16, s * 0.52)
          ..lineTo(s * 0.42, s * 0.76)
          ..lineTo(s * 0.86, s * 0.24);
        canvas.drawPath(p, line);
      case Glyph.plus:
        canvas
          ..drawLine(Offset(s * 0.5, s * 0.16), Offset(s * 0.5, s * 0.84), line)
          ..drawLine(
              Offset(s * 0.16, s * 0.5), Offset(s * 0.84, s * 0.5), line);
      case Glyph.dot:
        canvas
          ..drawCircle(Offset(s / 2, s / 2), s * 0.4, fill)
          ..drawCircle(Offset(s / 2, s / 2), s * 0.4, edge);
      case Glyph.ring:
        canvas.drawCircle(
            Offset(s / 2, s / 2),
            s * 0.34,
            Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.12
              ..shader = fill.shader);
      case Glyph.lock:
        final body = RRect.fromRectAndRadius(
            Rect.fromLTRB(s * 0.18, s * 0.44, s * 0.82, s * 0.92),
            Radius.circular(s * 0.1));
        canvas
          ..drawArc(Rect.fromLTRB(s * 0.3, s * 0.1, s * 0.7, s * 0.62),
              math.pi, math.pi, false, line..strokeWidth = s * 0.12)
          ..drawRRect(body, fill)
          ..drawRRect(body, edge);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.dim != dim;
}
