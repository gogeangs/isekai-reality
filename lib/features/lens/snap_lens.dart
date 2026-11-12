import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camerakit_flutter/camerakit_flutter.dart';
import 'package:camerakit_flutter/lens_model.dart';

import '../../core/rules/lens_rules.dart';

/// #60 Snap Camera Kit 시험 렌즈 (묶음 13 A2): 엘프 1개로 품질·속도·용량을 본다.
///
/// - 앱 ID·API 토큰은 빌드할 때 저장소 비밀 값에서 넣는다 (코드에 두지 않는다).
/// - 렌즈가 있는 종족만 렌즈로, 나머지·렌즈를 못 열었을 때·인터넷이 없을 때는 지금 장식.
/// - Snap 카메라는 전체 화면으로 열리고, 찍은 사진 파일을 돌려준다.
class SnapLens implements CameraKitFlutterEvents {
  SnapLens._();

  static final SnapLens instance = SnapLens._();

  /// 빌드에 Snap 앱 ID 가 들어갔는지
  static const bool _on = String.fromEnvironment('SNAP_ON') == '1';
  static const String groupId = String.fromEnvironment('SNAP_LENS_GROUP_ID');

  /// 엘프 렌즈 id (저장소 변수 SNAP_ELF_LENS_ID). 없으면 그룹 안 렌즈를 모두 보여 준다(시험용).
  static const String elfLensId = String.fromEnvironment('SNAP_ELF_LENS_ID');

  /// 시험 빌드인지 (시험용 Staging 토큰으로 만든 빌드). 렌즈 여는 시간을 화면에 보여 준다
  static const bool testBuild = String.fromEnvironment('SNAP_STAGE') != 'production';

  /// 렌즈가 있는 종족 (결과가 좋으면 하나씩 늘린다)
  static const Set<Race> races = {Race.elf};

  /// 테스트에서 끈다
  static bool enabled = _on && groupId != '';

  /// 이 종족을 렌즈로 볼 수 있는지
  static bool supports(List<Race> found) =>
      enabled && found.any(races.contains);

  CameraKitFlutterImpl? _kit;
  Completer<Uint8List?>? _waiting;

  /// 렌즈 카메라를 열고, 사진을 찍으면 그 바이트 (닫거나 실패하면 null).
  /// 걸린 시간은 [lastOpenMs] 에 남긴다 (속도 확인용).
  Future<Uint8List?> shoot() async {
    if (!enabled) return null;
    _kit ??= CameraKitFlutterImpl(cameraKitFlutterEvents: this);
    _waiting?.complete(null);
    final w = Completer<Uint8List?>();
    _waiting = w;
    final started = DateTime.now();
    try {
      if (elfLensId.isNotEmpty) {
        await _kit!.openCameraKitWithSingleLens(
            lensId: elfLensId, groupId: groupId, isHideCloseButton: false);
      } else {
        await _kit!.openCameraKit(groupIds: [groupId], isHideCloseButton: false);
      }
      lastOpenMs = DateTime.now().difference(started).inMilliseconds;
    } catch (_) {
      if (!w.isCompleted) w.complete(null);
    }
    // 카메라를 닫기만 하면 결과가 오지 않는다: 3분 뒤에는 포기
    final out = await w.future
        .timeout(const Duration(minutes: 3), onTimeout: () => null);
    lastTotalMs = DateTime.now().difference(started).inMilliseconds;
    return out;
  }

  /// 버튼을 누른 뒤 Snap 카메라 화면이 열리기까지 (ms)
  int? lastOpenMs;

  /// 버튼을 누른 뒤 사진을 받기까지 (ms, 렌즈를 처음 받는 시간·고르는 시간 포함)
  int? lastTotalMs;

  /// 시험 빌드에서 보여 줄 한 줄
  String? get timingLine {
    final open = lastOpenMs, total = lastTotalMs;
    if (open == null) return null;
    String s(int ms) => (ms / 1000).toStringAsFixed(1);
    return '[시험] 렌즈 열기 ${s(open)}초'
        '${total == null ? '' : ' · 사진까지 ${s(total)}초'}';
  }

  @override
  void onCameraKitResult(Map<dynamic, dynamic> result) {
    final w = _waiting;
    _waiting = null;
    if (w == null || w.isCompleted) return;
    final path = result['path'] as String?;
    final type = '${result['type'] ?? ''}';
    if (path == null || type.contains('video')) {
      w.complete(null); // 이번 시험은 사진만
      return;
    }
    File(path).readAsBytes().then(w.complete, onError: (_) => w.complete(null));
  }

  @override
  void receivedLenses(List<Lens> lensList) {}
}
