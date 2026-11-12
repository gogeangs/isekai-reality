import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/rules/lens_rules.dart';
import 'race_filter_engine.dart';
import 'race_stickers.dart';

/// 카메라 없이 보는 예시 엔진 (테스트·화면 미리보기용). 그린 인물 두 명이 보인다.
class DemoFilterEngine implements RaceFilterEngine {
  DemoFilterEngine({this.faceCount = 2});

  final int faceCount;
  final _faces = ValueNotifier<List<FaceSpot>>(const []);
  StickerArt _art = StickerArt.none;

  static const _spots = [
    FaceSpot(Rect.fromLTWH(0.16, 0.42, 0.26, 0.2), roll: -6, id: 1),
    FaceSpot(Rect.fromLTWH(0.56, 0.38, 0.28, 0.21), roll: 4, id: 2),
    FaceSpot(Rect.fromLTWH(0.38, 0.7, 0.2, 0.15), id: 3),
  ];

  @override
  Future<String?> start() async {
    _art = await StickerArt.load();
    _faces.value = _spots.take(faceCount).toList();
    return null;
  }

  @override
  ValueListenable<List<FaceSpot>> get faces => _faces;

  @override
  double get aspectRatio => 3 / 4;

  @override
  Widget preview(List<Race>? races) => ValueListenableBuilder<List<FaceSpot>>(
        valueListenable: _faces,
        builder: (_, faces, __) => CustomPaint(
          painter: _DemoPainter(faces, races, _art),
          child: const SizedBox.expand(),
        ),
      );

  @override
  bool get canSwitchCamera => false;

  @override
  Future<void> switchCamera() async {}

  @override
  Future<ui.Image?> capture(List<Race> races) async {
    const size = Size(900, 1200);
    final rec = ui.PictureRecorder();
    _DemoPainter(_faces.value, races, _art).paint(Canvas(rec), size);
    return rec
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async => _faces.dispose();
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.faces, this.races, this.art);

  final List<FaceSpot> faces;
  final List<Race>? races;
  final StickerArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        bg,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8FB6D9), Color(0xFFE9D3B0), Color(0xFF9C8A6E)],
          ).createShader(bg));
    // 그린 인물 (얼굴·어깨)
    for (final f in faces) {
      final box = Rect.fromLTRB(f.box.left * size.width, f.box.top * size.height,
          f.box.right * size.width, f.box.bottom * size.height);
      final body = Rect.fromCenter(
          center: Offset(box.center.dx, box.bottom + box.height * 0.95),
          width: box.width * 2.1,
          height: box.height * 1.5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(box.width * 0.6)),
          Paint()..color = const Color(0xFF4F5D8C));
      canvas.drawOval(box.inflate(box.width * 0.04),
          Paint()..color = const Color(0xFF3A2A22));
      canvas.drawOval(box, Paint()..color = const Color(0xFFF2CDB0));
      final eye = Paint()..color = const Color(0xFF3A2A22);
      for (final s in [-1.0, 1.0]) {
        canvas.drawCircle(
            box.center + Offset(s * box.width * 0.18, -box.height * 0.04),
            box.width * 0.04,
            eye);
      }
      canvas.drawArc(
          Rect.fromCenter(
              center: box.center + Offset(0, box.height * 0.18),
              width: box.width * 0.3,
              height: box.height * 0.12),
          0.2,
          2.7,
          false,
          Paint()
            ..color = const Color(0xFFB0584A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = box.width * 0.025);
    }
    if (races != null) {
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
        races!,
        art,
      );
    }
  }

  @override
  bool shouldRepaint(_DemoPainter old) =>
      old.faces != faces || old.races != races;
}
