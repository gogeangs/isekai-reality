import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/rules/lens_rules.dart';

/// 감정 사진 틀 (11-11 #60): 1080×1440, 사진 창 + 아래에 종족 이름과 게임 로고.
///
/// 틀 그림(assets/images/lens_frame.png)이 있으면 그 위에 글자만 쓴다.
/// 틀 그림 규칙: 1080×1440 PNG, 사진 창 x 60~1020 · y 60~1200 은 투명,
/// 아래 띠(y 1200~1440) 가운데 520×150 은 글자를 쓰는 빈 판.
class PhotoFrame {
  PhotoFrame._();

  static const double width = 1080;
  static const double height = 1440;
  static const Rect window = Rect.fromLTRB(60, 60, 1020, 1200);
  static const String frameAsset = 'assets/images/lens_frame.webp';
  static const String logoAsset = 'assets/images/logo_small.webp';
  static const String gameName = '이세계가 현실이라면?';

  static Future<ui.Image?> _load(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// 감정한 종족 이름 (같은 종족은 한 번)
  static String raceLine(List<Race> races) =>
      [for (final r in {...races}) LensRules.info(r).name].join(' · ');

  /// 사진에 틀을 씌워 PNG 로 만든다
  static Future<Uint8List> compose(ui.Image photo, List<Race> races) async {
    final frame = await _load(frameAsset);
    final logo = await _load(logoAsset);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const all = Rect.fromLTWH(0, 0, width, height);
    canvas.drawRect(all, Paint()..color = const Color(0xFF14163A));

    // 사진: 창을 가득 채우게 (가운데 자르기)
    final pw = photo.width.toDouble(), ph = photo.height.toDouble();
    final scale = math.max(window.width / pw, window.height / ph);
    final src = Rect.fromCenter(
        center: Offset(pw / 2, ph / 2),
        width: window.width / scale,
        height: window.height / scale);
    canvas.drawImageRect(
        photo, src, window, Paint()..filterQuality = FilterQuality.high);

    if (frame != null) {
      canvas.drawImageRect(
          frame,
          Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
          all,
          Paint()..filterQuality = FilterQuality.high);
    } else {
      _paintFrame(canvas);
    }

    // 아래 띠: 감정 결과 · 종족 이름 · 로고
    _text(canvas, '마법 돋보기 감정 결과', const Offset(width / 2, 1236), 30,
        const Color(0xFFD9C38A), FontWeight.w700,
        title: true);
    _text(canvas, raceLine(races), const Offset(width / 2, 1300), 64,
        const Color(0xFFFFE9A8), FontWeight.w700,
        title: true, maxWidth: 940);
    const logoSize = 64.0;
    final name = _layout(gameName, 30, const Color(0xFFEDE3C8), FontWeight.w700,
        title: true);
    final rowW = (logo != null ? logoSize + 14 : 0) + name.width;
    var x = width / 2 - rowW / 2;
    const rowY = 1372.0;
    if (logo != null) {
      final dst = Rect.fromLTWH(x, rowY - logoSize / 2, logoSize, logoSize);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(dst, const Radius.circular(14)));
      canvas.drawImageRect(
          logo,
          Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
          dst,
          Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
      x += logoSize + 14;
    }
    name.paint(canvas, Offset(x, rowY - name.height / 2));

    final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  }

  static TextPainter _layout(String s, double size, Color color, FontWeight w,
          {bool title = false, double maxWidth = width}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: title ? 'Title' : null,
            fontSize: size,
            fontWeight: w,
            color: color,
            shadows: const [Shadow(color: Color(0x99C9A44B), blurRadius: 12)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  static void _text(Canvas canvas, String s, Offset center, double size,
      Color color, FontWeight w,
      {bool title = false, double maxWidth = width}) {
    final tp = _layout(s, size, color, w, title: title, maxWidth: maxWidth);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// 그림이 없을 때 그리는 금테
  static void _paintFrame(Canvas canvas) {
    const gold = Color(0xFFC9A44B);
    const bright = Color(0xFFFFE9A8);
    final outer = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 18, width - 36, height - 36),
        const Radius.circular(28));
    canvas.drawRRect(
        outer,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
    canvas.drawRRect(
        outer.deflate(14),
        Paint()
          ..color = gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawRect(
        window.inflate(4),
        Paint()
          ..color = bright
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    // 네 귀퉁이 마름모
    for (final c in [
      window.topLeft,
      window.topRight,
      window.bottomLeft,
      window.bottomRight,
    ]) {
      final p = Path()
        ..moveTo(c.dx, c.dy - 22)
        ..lineTo(c.dx + 22, c.dy)
        ..lineTo(c.dx, c.dy + 22)
        ..lineTo(c.dx - 22, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFF14163A));
      canvas.drawPath(
          p,
          Paint()
            ..color = bright
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      canvas.drawCircle(c, 6, Paint()..color = bright);
    }
    // 아래 띠 장식 선
    final line = Paint()
      ..color = gold.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(140, 1338), const Offset(940, 1338), line);
  }
}
