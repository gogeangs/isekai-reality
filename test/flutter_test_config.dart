// 묶음 69 #279: 시험은 예전 고정 공성전 일정(11-28 첫 공성전)으로 — 앱은 서버가 알려 준 일정(운영자 스위치)을 따름
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isekai_reality/core/rules/rules.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ErbardRules.schedule = ErbardRules.legacySchedule;
  ErbardRules.keepSchedule = true;
  // 묶음 80 #370: IMG_LOG=<파일> 이면 그림마다 화면에 그려진 가장 큰 크기(물리 픽셀)를 적는다 (그림 줄이기 기준)
  final log = Platform.environment['IMG_LOG'];
  if (log != null && log.isNotEmpty) {
    final most = <String, (double, double)>{};
    void hook(ImageSizeInfo info) {
      final k = info.source ?? '';
      if (!k.contains('assets/images/')) return;
      final o = most[k] ?? (0, 0);
      most[k] = (math.max(o.$1, info.displaySize.width), math.max(o.$2, info.displaySize.height));
    }

    setUp(() => debugOnPaintImage = hook);
    tearDownAll(() {
      final f = File(log).openSync(mode: FileMode.append);
      for (final e in most.entries) {
        f.writeStringSync('${e.key}\t${e.value.$1.round()}\t${e.value.$2.round()}\n');
      }
      f.closeSync();
    });
  }
  await testMain();
}
