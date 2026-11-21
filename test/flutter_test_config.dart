// 묶음 69 #279: 시험은 예전 고정 공성전 일정(11-28 첫 공성전)으로 — 앱은 서버가 알려 준 일정(운영자 스위치)을 따름
import 'dart:async';

import 'package:isekai_reality/core/rules/rules.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ErbardRules.schedule = ErbardRules.legacySchedule;
  ErbardRules.keepSchedule = true;
  await testMain();
}
