import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/rules/lens_rules.dart';
import 'race_filter_engine.dart';

/// 종족 장식 그림 (assets/images/filter_<종족>.png). 그림이 없으면 도형으로 그린다.
///
/// 그림 규칙: 1024×1024 투명 PNG. 얼굴은 가운데 (가로 30~70%, 세로 35~75%) 빈 자리,
/// 얼굴 가운데가 그림의 (50%, 55%) 에 온다. 그림 폭은 얼굴 폭의 2.4배로 붙인다.
class StickerArt {
  StickerArt._(this.images);

  final Map<Race, ui.Image> images;

  static StickerArt? _cache;

  static const double widthPerFace = 2.4;
  static const double anchorY = 0.55;

  static Future<StickerArt> load() async {
    if (_cache != null) return _cache!;
    final out = <Race, ui.Image>{};
    for (final r in Race.values) {
      try {
        final data = await rootBundle.load(LensRules.info(r).asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        out[r] = (await codec.getNextFrame()).image;
      } catch (_) {
        // 그림이 아직 없다 → 도형으로 그린다
      }
    }
    return _cache = StickerArt._(out);
  }

  static final StickerArt none = StickerArt._(const {});
}

/// 얼굴들에 종족 장식을 그린다. [faces] 는 [size] 안의 실제 좌표.
void paintRaceStickers(
  Canvas canvas,
  List<({Rect box, double roll})> faces,
  List<Race> races,
  StickerArt art, {
  bool labels = true,
}) {
  final sorted = [...faces]
    ..sort((a, b) => a.box.center.dx.compareTo(b.box.center.dx));
  for (var i = 0; i < sorted.length && i < races.length; i++) {
    paintRaceSticker(canvas, sorted[i].box, sorted[i].roll, races[i], art,
        label: labels);
  }
}

/// 비율 좌표 얼굴을 [size] 에 맞춰 그린다 (미리보기 위 덧그림)
class RaceStickerPainter extends CustomPainter {
  RaceStickerPainter(this.faces, this.races, this.art);

  final List<FaceSpot> faces;
  final List<Race> races;
  final StickerArt art;

  @override
  void paint(Canvas canvas, Size size) {
    paintRaceStickers(
      canvas,
      [
        for (final f in faces)
          (
            box: Rect.fromLTRB(f.box.left * size.width, f.box.top * size.height,
                f.box.right * size.width, f.box.bottom * size.height),
            roll: f.roll,
          ),
      ],
      races,
      art,
    );
  }

  @override
  bool shouldRepaint(RaceStickerPainter old) =>
      old.faces != faces || old.races != races || old.art != art;
}

/// 얼굴 하나에 종족 장식
void paintRaceSticker(
    Canvas canvas, Rect face, double roll, Race race, StickerArt art,
    {bool label = true}) {
  final u = face.width;
  if (u < 8) return;
  final c = face.center;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(roll.clamp(-35.0, 35.0) * math.pi / 180);
  canvas.translate(-c.dx, -c.dy);
  final img = art.images[race];
  if (img != null) {
    final w = u * StickerArt.widthPerFace;
    final dst = Rect.fromLTWH(c.dx - w / 2, c.dy - w * StickerArt.anchorY, w, w);
    canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium);
  } else {
    _drawShapes(canvas, face, race);
  }
  if (label) _drawLabel(canvas, face, race);
  canvas.restore();
}

Paint _fill(int color, [double alpha = 1]) => Paint()
  ..color = Color(color).withValues(alpha: alpha)
  ..isAntiAlias = true;

Paint _stroke(int color, double w, [double alpha = 1]) => Paint()
  ..color = Color(color).withValues(alpha: alpha)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

Path _star(Offset c, double r, [int points = 5]) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final rr = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / points;
    final o = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

void _sparkles(Canvas canvas, Rect f, int color, int n, double spread) {
  final u = f.width;
  final rng = math.Random(n * 31 + color);
  for (var i = 0; i < n; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = u * (0.6 + rng.nextDouble() * spread);
    final o = f.center + Offset(math.cos(a) * d, math.sin(a) * d * 0.9);
    canvas.drawPath(
        _star(o, u * (0.025 + rng.nextDouble() * 0.03), 4), _fill(color, 0.9));
  }
}

void _drawShapes(Canvas canvas, Rect f, Race race) {
  final u = f.width;
  final l = f.left, r = f.right, t = f.top, b = f.bottom, cx = f.center.dx;
  final cy = f.center.dy;
  switch (race) {
    case Race.elf:
      // 뾰족한 귀 + 잎사귀 관
      for (final s in [-1.0, 1.0]) {
        final x0 = s < 0 ? l + 0.04 * u : r - 0.04 * u;
        final ear = Path()
          ..moveTo(x0, cy - 0.12 * u)
          ..quadraticBezierTo(x0 + s * 0.22 * u, cy - 0.3 * u,
              x0 + s * 0.42 * u, cy - 0.5 * u)
          ..quadraticBezierTo(
              x0 + s * 0.2 * u, cy - 0.05 * u, x0 + s * 0.02 * u, cy + 0.12 * u)
          ..close();
        canvas.drawPath(ear, _fill(0xFFF3CDA9));
        canvas.drawPath(ear, _stroke(0xFFB98563, u * 0.012));
        canvas.drawCircle(Offset(x0 + s * 0.08 * u, cy + 0.08 * u), u * 0.025,
            _fill(0xFFFFD45E));
      }
      final band = Rect.fromCenter(
          center: Offset(cx, t + 0.08 * u), width: u * 1.0, height: u * 0.5);
      canvas.drawArc(band, math.pi * 1.1, math.pi * 0.8, false,
          _stroke(0xFFC9A44B, u * 0.025));
      for (var i = 0; i < 7; i++) {
        final a = math.pi * (1.12 + i * 0.76 / 6);
        final o = band.center +
            Offset(math.cos(a) * band.width / 2, math.sin(a) * band.height / 2);
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(a + math.pi / 2);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: u * 0.07, height: u * 0.15),
            _fill(i == 3 ? 0xFFFFE27A : 0xFF6CC47A));
        canvas.restore();
      }
    case Race.dwarf:
      // 땋은 수염 + 콧수염 + 투구 띠
      final beard = Path()
        ..moveTo(l + 0.02 * u, cy + 0.02 * u)
        ..quadraticBezierTo(l - 0.02 * u, b + 0.3 * u, cx, b + 0.62 * u)
        ..quadraticBezierTo(r + 0.02 * u, b + 0.3 * u, r - 0.02 * u, cy + 0.02 * u)
        ..quadraticBezierTo(r - 0.15 * u, b - 0.02 * u, cx + 0.16 * u, b - 0.1 * u)
        ..quadraticBezierTo(cx, b + 0.02 * u, cx - 0.16 * u, b - 0.1 * u)
        ..quadraticBezierTo(l + 0.15 * u, b - 0.02 * u, l + 0.02 * u, cy + 0.02 * u)
        ..close();
      canvas.drawPath(beard, _fill(0xFF9A5B2C));
      canvas.drawPath(beard, _stroke(0xFF5E3417, u * 0.012));
      for (final s in [-0.12, 0.0, 0.12]) {
        canvas.drawLine(Offset(cx + s * u, b + 0.05 * u),
            Offset(cx + s * u * 0.6, b + 0.45 * u), _stroke(0xFF6E3D1B, u * 0.012));
      }
      canvas.drawCircle(Offset(cx, b + 0.55 * u), u * 0.045, _fill(0xFFC9A44B));
      final mustache = Path()
        ..moveTo(cx, cy + 0.2 * u)
        ..quadraticBezierTo(cx - 0.18 * u, cy + 0.14 * u, cx - 0.3 * u, cy + 0.3 * u)
        ..quadraticBezierTo(cx - 0.15 * u, cy + 0.26 * u, cx, cy + 0.26 * u)
        ..quadraticBezierTo(cx + 0.15 * u, cy + 0.26 * u, cx + 0.3 * u, cy + 0.3 * u)
        ..quadraticBezierTo(cx + 0.18 * u, cy + 0.14 * u, cx, cy + 0.2 * u)
        ..close();
      canvas.drawPath(mustache, _fill(0xFF7A4520));
      final helm = Rect.fromLTRB(l - 0.05 * u, t - 0.32 * u, r + 0.05 * u, t + 0.12 * u);
      canvas.drawArc(helm, math.pi, math.pi, true, _fill(0xFF8C95A3));
      canvas.drawRect(Rect.fromLTRB(l - 0.07 * u, t - 0.12 * u + 0.1 * u,
          r + 0.07 * u, t + 0.04 * u), _fill(0xFFC9A44B));
    case Race.fairy:
      // 날개 + 꽃 관 + 반짝이
      for (final s in [-1.0, 1.0]) {
        for (final (dy, w, h, col) in [
          (-0.15, 0.55, 0.75, 0xFFF3A6E0),
          (0.3, 0.4, 0.5, 0xFF9EE6F0),
        ]) {
          canvas.save();
          final o = Offset(cx + s * (0.72 * u), cy + dy * u);
          canvas.translate(o.dx, o.dy);
          canvas.rotate(s * (dy < 0 ? -0.5 : 0.6));
          final rect = Rect.fromCenter(center: Offset.zero, width: w * u, height: h * u);
          canvas.drawOval(rect, _fill(col, 0.45));
          canvas.drawOval(rect, _stroke(0xFFFFFFFF, u * 0.01, 0.8));
          canvas.restore();
        }
      }
      for (var i = 0; i < 5; i++) {
        final x = l + 0.1 * u + i * 0.2 * u;
        final y = t - 0.02 * u - math.sin(i / 4 * math.pi) * 0.1 * u;
        final col = [0xFFFF9EC7, 0xFFFFE27A, 0xFFB79CFF, 0xFFFFE27A, 0xFFFF9EC7][i];
        for (var k = 0; k < 5; k++) {
          final a = k * math.pi * 2 / 5;
          canvas.drawCircle(Offset(x + math.cos(a) * 0.035 * u, y + math.sin(a) * 0.035 * u),
              u * 0.03, _fill(col));
        }
        canvas.drawCircle(Offset(x, y), u * 0.022, _fill(0xFFFFF6C2));
      }
      _sparkles(canvas, f, 0xFFFFF6C2, 10, 0.4);
    case Race.dragonkin:
      // 굽은 뿔 + 볼의 비늘
      for (final s in [-1.0, 1.0]) {
        final x0 = cx + s * 0.28 * u;
        final horn = Path()
          ..moveTo(x0 - s * 0.08 * u, t + 0.08 * u)
          ..quadraticBezierTo(x0 + s * 0.05 * u, t - 0.35 * u,
              x0 + s * 0.38 * u, t - 0.5 * u)
          ..quadraticBezierTo(x0 + s * 0.12 * u, t - 0.25 * u,
              x0 + s * 0.12 * u, t + 0.06 * u)
          ..close();
        canvas.drawPath(horn, _fill(0xFF5B2A3A));
        canvas.drawPath(horn, _stroke(0xFFE8B04B, u * 0.014));
        for (var k = 0; k < 3; k++) {
          final o = Offset(cx + s * (0.36 + (k % 2) * 0.06) * u, cy + (0.02 + k * 0.08) * u);
          canvas.drawArc(Rect.fromCenter(center: o, width: 0.08 * u, height: 0.07 * u),
              0, math.pi, false, _stroke(0xFFE05A47, u * 0.012, 0.85));
        }
      }
      _sparkles(canvas, f, 0xFFFF9A4A, 6, 0.3);
    case Race.catfolk:
    case Race.foxfolk:
      final fox = race == Race.foxfolk;
      final furCol = fox ? 0xFFF08A3C : 0xFF3B3346;
      final innerCol = fox ? 0xFFFFF1DE : 0xFFF7A8C0;
      for (final s in [-1.0, 1.0]) {
        final base = cx + s * 0.3 * u;
        final tip = Offset(base + s * (fox ? 0.12 : 0.08) * u, t - (fox ? 0.52 : 0.4) * u);
        final ear = Path()
          ..moveTo(base - 0.2 * u, t + 0.06 * u)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base + 0.2 * u, t + 0.06 * u)
          ..close();
        canvas.drawPath(ear, _fill(furCol));
        final inner = Path()
          ..moveTo(base - 0.11 * u, t + 0.02 * u)
          ..lineTo(tip.dx + (base - tip.dx) * 0.25, tip.dy + 0.12 * u)
          ..lineTo(base + 0.11 * u, t + 0.02 * u)
          ..close();
        canvas.drawPath(inner, _fill(innerCol));
        if (fox) {
          canvas.drawCircle(tip + Offset(0, 0.04 * u), 0.05 * u, _fill(0xFFFFFFFF));
          for (final k in [0.0, 0.07]) {
            canvas.drawLine(Offset(cx + s * 0.22 * u, cy + (0.12 + k) * u),
                Offset(cx + s * 0.38 * u, cy + (0.08 + k) * u), _stroke(0xFFD9442B, u * 0.02));
          }
        } else {
          for (final k in [-0.05, 0.03, 0.11]) {
            canvas.drawLine(Offset(cx + s * 0.16 * u, cy + 0.2 * u + k * u * 0.3),
                Offset(cx + s * 0.5 * u, cy + 0.12 * u + k * u),
                _stroke(0xFFFFFFFF, u * 0.008, 0.9));
          }
        }
      }
      final nose = Path()
        ..moveTo(cx - 0.05 * u, cy + 0.12 * u)
        ..lineTo(cx + 0.05 * u, cy + 0.12 * u)
        ..lineTo(cx, cy + 0.18 * u)
        ..close();
      canvas.drawPath(nose, _fill(fox ? 0xFF3B2A22 : 0xFFF7A8C0));
    case Race.mermaid:
      // 조개 관 + 진주 + 지느러미 귀 + 물방울
      final shellC = Offset(cx, t - 0.08 * u);
      final shell = Path()..moveTo(shellC.dx, shellC.dy + 0.12 * u);
      for (var k = 0; k <= 6; k++) {
        final a = math.pi + k * math.pi / 6;
        shell.lineTo(shellC.dx + math.cos(a) * 0.22 * u, shellC.dy + math.sin(a) * 0.22 * u);
      }
      shell.close();
      canvas.drawPath(shell, _fill(0xFFFFC9D9));
      for (var k = 1; k < 6; k++) {
        final a = math.pi + k * math.pi / 6;
        canvas.drawLine(shellC + Offset(0, 0.12 * u),
            shellC + Offset(math.cos(a) * 0.2 * u, math.sin(a) * 0.2 * u),
            _stroke(0xFFE58FAE, u * 0.01));
      }
      for (var k = 0; k <= 10; k++) {
        final a = math.pi * (1.08 + k * 0.84 / 10);
        canvas.drawCircle(
            Offset(cx + math.cos(a) * 0.52 * u, t + 0.12 * u + math.sin(a) * 0.2 * u),
            u * 0.025, _fill(0xFFFFFBF0));
      }
      for (final s in [-1.0, 1.0]) {
        final x0 = s < 0 ? l + 0.02 * u : r - 0.02 * u;
        final fin = Path()
          ..moveTo(x0, cy - 0.1 * u)
          ..lineTo(x0 + s * 0.3 * u, cy - 0.3 * u)
          ..lineTo(x0 + s * 0.24 * u, cy - 0.05 * u)
          ..lineTo(x0 + s * 0.3 * u, cy + 0.15 * u)
          ..lineTo(x0, cy + 0.1 * u)
          ..close();
        canvas.drawPath(fin, _fill(0xFF5CC8E0, 0.85));
        canvas.drawPath(fin, _stroke(0xFFE6FBFF, u * 0.008));
      }
      final rng = math.Random(7);
      for (var k = 0; k < 7; k++) {
        final o = Offset(r + (0.1 + rng.nextDouble() * 0.4) * u,
            cy - (rng.nextDouble() * 0.9) * u);
        canvas.drawCircle(o, u * (0.02 + rng.nextDouble() * 0.04),
            _stroke(0xFFBFF4FF, u * 0.008, 0.9));
      }
    case Race.starChild:
      // 별 관 + 반짝이 + 볼의 별
      for (var k = 0; k < 5; k++) {
        final a = math.pi * (1.15 + k * 0.7 / 4);
        final o = Offset(cx + math.cos(a) * 0.5 * u, t + 0.1 * u + math.sin(a) * 0.32 * u);
        final rr = (k == 2 ? 0.13 : 0.08) * u;
        canvas.drawPath(_star(o, rr * 1.3), _fill(0xFFFFE27A, 0.35));
        canvas.drawPath(_star(o, rr), _fill(0xFFFFE27A));
        canvas.drawPath(_star(o, rr), _stroke(0xFFFFFFFF, u * 0.008));
      }
      canvas.drawPath(_star(Offset(cx + 0.26 * u, cy + 0.12 * u), 0.05 * u), _fill(0xFFFFF6C2));
      _sparkles(canvas, f, 0xFFFFF6C2, 14, 0.5);
  }
}

void _drawLabel(Canvas canvas, Rect f, Race race) {
  final info = LensRules.info(race);
  final u = f.width;
  final tp = TextPainter(
    text: TextSpan(
      text: info.name,
      style: TextStyle(
        fontFamily: 'Title',
        fontWeight: FontWeight.w700,
        fontSize: (u * 0.16).clamp(12.0, 64.0),
        color: const Color(0xFFFFF3C4),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final top = f.top - u * 0.62 - tp.height;
  final box = Rect.fromCenter(
    center: Offset(f.center.dx, top + tp.height / 2),
    width: tp.width + u * 0.16,
    height: tp.height + u * 0.06,
  );
  final rr = RRect.fromRectAndRadius(box, Radius.circular(box.height / 2));
  canvas.drawRRect(rr, _fill(0xFF14163A, 0.78));
  canvas.drawRRect(rr, _stroke(info.color, (u * 0.012).clamp(1.0, 4.0)));
  tp.paint(canvas, Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2));
}
