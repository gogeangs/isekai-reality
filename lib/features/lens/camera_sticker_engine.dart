import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/rules/lens_rules.dart';
import 'race_filter_engine.dart';
import 'race_stickers.dart';

/// 1차 필터 엔진: 카메라 + Google ML Kit 얼굴 인식(휴대폰 안에서) + 2D 종족 장식.
/// 사진은 휴대폰 밖으로 보내지 않고, 찍은 원본 파일은 바로 지운다.
class CameraStickerEngine implements RaceFilterEngine {
  CameraStickerEngine();

  final _faces = ValueNotifier<List<FaceSpot>>(const []);
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: true,
      minFaceSize: 0.12,
    ),
  );
  List<CameraDescription> _cameras = const [];
  CameraController? _ctrl;
  int _index = 0;
  bool _busy = false;
  bool _disposed = false;
  StickerArt _art = StickerArt.none;

  @override
  ValueListenable<List<FaceSpot>> get faces => _faces;

  CameraDescription get _camera => _cameras[_index];

  bool get _front => _camera.lensDirection == CameraLensDirection.front;

  @override
  Future<String?> start() async {
    _art = await StickerArt.load();
    try {
      _cameras = await availableCameras();
    } on CameraException {
      return '카메라를 찾지 못했어요.';
    }
    if (_cameras.isEmpty) return '카메라를 찾지 못했어요.';
    // 셀카로 시작한다
    final front =
        _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    _index = front < 0 ? 0 : front;
    return _open();
  }

  Future<String?> _open() async {
    final old = _ctrl;
    _ctrl = null;
    if (old != null) {
      try {
        if (old.value.isStreamingImages) await old.stopImageStream();
      } catch (_) {}
      await old.dispose();
    }
    final ctrl = CameraController(
      _camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await ctrl.initialize();
    } on CameraException catch (e) {
      await ctrl.dispose();
      return e.code.contains('Denied') || e.code.contains('denied')
          ? '카메라 권한이 꺼져 있어요. 휴대폰 설정에서 카메라를 허용해 주세요.'
          : '카메라를 켜지 못했어요. (${e.code})';
    }
    if (_disposed) {
      await ctrl.dispose();
      return null;
    }
    _ctrl = ctrl;
    _faces.value = const [];
    await _startStream();
    return null;
  }

  Future<void> _startStream() async {
    final ctrl = _ctrl;
    if (ctrl == null || ctrl.value.isStreamingImages) return;
    await ctrl.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isStreamingImages) return;
    await ctrl.stopImageStream();
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _toInput(CameraImage image) {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    final sensor = _camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _orientations[ctrl.value.deviceOrientation] ?? 0;
      comp = _front ? (sensor + comp) % 360 : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final input = _toInput(image);
      if (input == null) return;
      final found = await _detector.processImage(input);
      if (_disposed) return;
      final meta = input.metadata!;
      _faces.value = [
        for (final f in found.take(LensRules.maxFaces))
          _spot(f, meta.size, meta.rotation),
      ];
    } catch (_) {
      // 한 장 실패는 넘긴다
    } finally {
      _busy = false;
    }
  }

  /// ML Kit 좌표 → 미리보기 비율 좌표 (세로 화면, 앞 카메라는 거울)
  FaceSpot _spot(Face f, Size image, InputImageRotation rotation) {
    final turned = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final w = turned && !Platform.isIOS ? image.height : image.width;
    final h = turned && !Platform.isIOS ? image.width : image.height;
    var box = Rect.fromLTRB(f.boundingBox.left / w, f.boundingBox.top / h,
        f.boundingBox.right / w, f.boundingBox.bottom / h);
    final mirror = _front;
    if (mirror) box = Rect.fromLTRB(1 - box.right, box.top, 1 - box.left, box.bottom);
    final z = f.headEulerAngleZ ?? 0;
    return FaceSpot(box, roll: mirror ? z : -z, id: f.trackingId);
  }

  @override
  double get aspectRatio {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return 3 / 4;
    // 카메라 비율은 가로 기준이라 세로 화면에서는 뒤집는다
    return 1 / ctrl.value.aspectRatio;
  }

  @override
  Widget preview(List<Race>? races) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return Stack(fit: StackFit.expand, children: [
      CameraPreview(ctrl),
      if (races != null)
        ValueListenableBuilder<List<FaceSpot>>(
          valueListenable: _faces,
          builder: (_, faces, __) => CustomPaint(
              painter: RaceStickerPainter(faces, races, _art)),
        ),
    ]);
  }

  @override
  bool get canSwitchCamera => _cameras.length > 1;

  @override
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    final want = _front ? CameraLensDirection.back : CameraLensDirection.front;
    final i = _cameras.indexWhere((c) => c.lensDirection == want);
    _index = i < 0 ? (_index + 1) % _cameras.length : i;
    await _open();
  }

  @override
  Future<ui.Image?> capture(List<Race> races) async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return null;
    final live = _faces.value;
    await _stopStream();
    XFile? file;
    try {
      file = await ctrl.takePicture();
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final photo = (await codec.getNextFrame()).image;
      List<Face> found = const [];
      try {
        found = await _detector.processImage(InputImage.fromFilePath(file.path));
      } catch (_) {}
      final w = photo.width.toDouble(), h = photo.height.toDouble();
      final mirror = _front;
      var spots = <({Rect box, double roll})>[
        for (final f in found.take(LensRules.maxFaces))
          (
            box: mirror
                ? Rect.fromLTRB(w - f.boundingBox.right, f.boundingBox.top,
                    w - f.boundingBox.left, f.boundingBox.bottom)
                : f.boundingBox,
            roll: mirror ? (f.headEulerAngleZ ?? 0) : -(f.headEulerAngleZ ?? 0),
          ),
      ];
      // 사진에서 얼굴을 못 찾으면 미리보기에서 본 자리로 그린다
      if (spots.isEmpty) {
        spots = [
          for (final f in live)
            (
              box: Rect.fromLTRB(f.box.left * w, f.box.top * h, f.box.right * w,
                  f.box.bottom * h),
              roll: f.roll,
            ),
        ];
      }
      // 크기를 줄여 그린다 (긴 쪽 1600)
      final scale = math.min(1.0, 1600 / math.max(w, h));
      final ow = (w * scale).round(), oh = (h * scale).round();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.scale(scale);
      if (mirror) {
        canvas.save();
        canvas.translate(w, 0);
        canvas.scale(-1, 1);
        canvas.drawImage(photo, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
        canvas.restore();
      } else {
        canvas.drawImage(photo, Offset.zero, Paint());
      }
      paintRaceStickers(canvas, spots, races, _art);
      final out = await rec.endRecording().toImage(ow, oh);
      photo.dispose();
      return out;
    } catch (_) {
      return null;
    } finally {
      // 찍은 원본은 바로 지운다 (게임은 사진을 남기지 않는다)
      if (file != null) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
      if (!_disposed) {
        try {
          await _startStream();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> pause() async {
    final ctrl = _ctrl;
    _ctrl = null;
    if (ctrl == null) return;
    try {
      if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
    } catch (_) {}
    await ctrl.dispose();
  }

  @override
  Future<void> resume() async {
    if (_disposed || _ctrl != null || _cameras.isEmpty) return;
    await _open();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final ctrl = _ctrl;
    _ctrl = null;
    if (ctrl != null) {
      try {
        if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
      } catch (_) {}
      await ctrl.dispose();
    }
    await _detector.close();
    _faces.dispose();
  }
}
