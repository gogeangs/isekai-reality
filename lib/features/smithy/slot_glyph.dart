import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';

/// 장비 칸 아이콘 (11-11 #98): 게임풍 모양 (검·가죽 장갑·반지·투구·가슴 갑옷·부츠).
/// 그림(slot_<부위>.png)이 들어오면 그것을 쓰고, 없으면 선으로 그린다.
/// 색·밝기는 부르는 쪽이 정한다 (빈 칸은 예전과 같은 흐린 색).
class SlotGlyph extends StatelessWidget {
  const SlotGlyph(this.slot, {super.key, required this.color, this.size = 24});

  final EquipSlot slot;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/slot_${slot.name}.webp',
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) =>
            CustomPaint(size: Size.square(size), painter: SlotGlyphPainter(slot, color)),
      ),
    );
  }
}

class SlotGlyphPainter extends CustomPainter {
  SlotGlyphPainter(this.slot, this.color);

  final EquipSlot slot;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // 24 칸 기준으로 그린다
    canvas.save();
    canvas.scale(s);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    switch (slot) {
      case EquipSlot.weapon:
        _sword(canvas, fill, line);
      case EquipSlot.hands:
        _glove(canvas, fill, line);
      case EquipSlot.accessory:
        _ring(canvas, fill, line);
      case EquipSlot.head:
        _helmet(canvas, fill, line);
      case EquipSlot.body:
        _chest(canvas, fill, line);
      case EquipSlot.feet:
        _boot(canvas, fill, line);
    }
    canvas.restore();
  }

  // 검: 비스듬한 칼날 + 가드 + 손잡이
  void _sword(Canvas c, Paint fill, Paint line) {
    c.save();
    c.translate(12, 12);
    c.rotate(-math.pi / 4);
    final blade = Path()
      ..moveTo(0, -11)
      ..lineTo(2.2, -8)
      ..lineTo(2.2, 4)
      ..lineTo(-2.2, 4)
      ..lineTo(-2.2, -8)
      ..close();
    c.drawPath(blade, fill);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 4, 12, 2.4),
            const Radius.circular(1.2)),
        fill);
    c.drawRect(const Rect.fromLTWH(-1.2, 6.4, 2.4, 4), fill);
    c.drawCircle(const Offset(0, 11.6), 1.8, fill);
    c.restore();
  }

  // 가죽 장갑: 손바닥 + 네 손가락 + 엄지 + 커프스
  void _glove(Canvas c, Paint fill, Paint line) {
    final p = Path()
      ..moveTo(6.5, 13)
      ..lineTo(6.5, 6.5)
      ..quadraticBezierTo(6.5, 5, 8, 5)
      ..quadraticBezierTo(9.5, 5, 9.5, 6.5)
      ..lineTo(9.5, 4)
      ..quadraticBezierTo(9.5, 2.6, 11, 2.6)
      ..quadraticBezierTo(12.5, 2.6, 12.5, 4)
      ..lineTo(12.5, 4.6)
      ..quadraticBezierTo(12.5, 3.3, 14, 3.3)
      ..quadraticBezierTo(15.5, 3.3, 15.5, 4.8)
      ..lineTo(15.5, 6.5)
      ..quadraticBezierTo(15.5, 5.3, 16.8, 5.3)
      ..quadraticBezierTo(18.2, 5.3, 18.2, 6.8)
      ..lineTo(18.2, 13.5)
      ..quadraticBezierTo(18.2, 17, 15, 18)
      ..lineTo(9, 18)
      ..quadraticBezierTo(7, 17, 5.5, 14.5)
      ..lineTo(3.5, 11)
      ..quadraticBezierTo(3, 9.6, 4.2, 9.2)
      ..quadraticBezierTo(5.4, 8.9, 6.5, 10.5)
      ..close();
    c.drawPath(p, fill);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(8, 18.6, 9.6, 3.6),
            const Radius.circular(1)),
        fill);
  }

  // 반지: 고리 + 위에 보석
  void _ring(Canvas c, Paint fill, Paint line) {
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..isAntiAlias = true;
    c.drawCircle(const Offset(12, 14.5), 6.2, ring);
    final gem = Path()
      ..moveTo(12, 2.5)
      ..lineTo(16, 5.8)
      ..lineTo(12, 9.5)
      ..lineTo(8, 5.8)
      ..close();
    c.drawPath(gem, fill);
  }

  // 투구: 둥근 머리 + 가운데 볏 + 눈구멍
  void _helmet(Canvas c, Paint fill, Paint line) {
    final p = Path()
      ..moveTo(4, 19)
      ..lineTo(4, 12)
      ..quadraticBezierTo(4, 4, 12, 4)
      ..quadraticBezierTo(20, 4, 20, 12)
      ..lineTo(20, 19)
      ..lineTo(15, 19)
      ..lineTo(15, 13)
      ..lineTo(9, 13)
      ..lineTo(9, 19)
      ..close();
    c.drawPath(p, fill);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(11, 1.2, 2, 6),
            const Radius.circular(1)),
        fill);
    c.drawRect(const Rect.fromLTWH(11.2, 13, 1.6, 5.5), fill);
  }

  // 가슴 갑옷: 어깨받이 + 몸통 + 가운데 줄
  void _chest(Canvas c, Paint fill, Paint line) {
    final p = Path()
      ..moveTo(8, 3)
      ..quadraticBezierTo(12, 6, 16, 3)
      ..lineTo(21, 5.5)
      ..lineTo(19.5, 10)
      ..lineTo(17.5, 9.5)
      ..lineTo(17.5, 19)
      ..quadraticBezierTo(12, 22, 6.5, 19)
      ..lineTo(6.5, 9.5)
      ..lineTo(4.5, 10)
      ..lineTo(3, 5.5)
      ..close();
    final cut = Paint()
      ..color = const Color(0xFF000000)
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    c.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    c.drawPath(p, fill);
    c.drawLine(const Offset(12, 7.5), const Offset(12, 19.5), cut);
    c.drawLine(const Offset(8.5, 12), const Offset(15.5, 12), cut);
    c.restore();
  }

  // 부츠: 목 + 발등 + 굽
  void _boot(Canvas c, Paint fill, Paint line) {
    final p = Path()
      ..moveTo(7, 2.5)
      ..lineTo(14, 2.5)
      ..lineTo(14, 12)
      ..quadraticBezierTo(14.5, 13.5, 17, 14.2)
      ..quadraticBezierTo(21, 15.2, 21, 18)
      ..lineTo(21, 19.5)
      ..lineTo(5.5, 19.5)
      ..lineTo(6.5, 12)
      ..close();
    c.drawPath(p, fill);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(5, 20.3, 16.5, 2.2),
            const Radius.circular(1)),
        fill);
    c.drawRect(const Rect.fromLTWH(6, 2, 9, 2.4), fill);
  }

  @override
  bool shouldRepaint(SlotGlyphPainter old) =>
      old.slot != slot || old.color != color;
}
