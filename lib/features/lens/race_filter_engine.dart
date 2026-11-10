import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/rules/lens_rules.dart';

/// 화면에 보이는 얼굴 하나. [box] 는 미리보기 안의 비율 좌표 (0~1, 왼쪽 위 기준).
@immutable
class FaceSpot {
  const FaceSpot(this.box, {this.roll = 0, this.id});

  final Rect box;

  /// 고개 기울기 (도, 화면에서 시계 방향이 +)
  final double roll;

  /// 얼굴 추적 번호 (없으면 null)
  final int? id;
}

/// 얼굴 순서 (왼쪽부터): 종족은 이 순서로 붙는다
List<FaceSpot> facesLeftToRight(Iterable<FaceSpot> faces) =>
    [...faces]..sort((a, b) => a.box.center.dx.compareTo(b.box.center.dx));

/// 마법 돋보기의 필터 엔진 (11-11 #60).
///
/// 1차는 [CameraStickerEngine] (카메라 + Google ML Kit 얼굴 인식 + 2D 장식).
/// 2차에 얼굴에 입히는 3D 필터 SDK(예: DeepAR)로 바꿀 때는 이 틀만 새로 구현하면 되고,
/// 감정 연출·보상·사진 틀·저장·공유는 그대로 쓴다.
abstract class RaceFilterEngine {
  /// 카메라를 켠다. 못 켜면 사용자에게 보여 줄 이유를 돌려준다.
  Future<String?> start();

  /// 지금 보이는 얼굴들
  ValueListenable<List<FaceSpot>> get faces;

  /// 미리보기 (가로/세로 비율 [aspectRatio]). [races] 가 있으면 얼굴마다 종족 장식을 입힌다.
  Widget preview(List<Race>? races);

  /// 미리보기 가로 ÷ 세로
  double get aspectRatio;

  /// 앞·뒤 카메라를 바꿀 수 있는지
  bool get canSwitchCamera;

  Future<void> switchCamera();

  /// 지금 화면을 장식까지 입힌 사진으로 찍는다 (휴대폰 안에서만 만든다)
  Future<ui.Image?> capture(List<Race> races);

  Future<void> dispose();
}
