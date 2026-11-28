// 개발용: 묶음 86 #422 던전 클리어율 (flutter test test/tool/dungeon_sim.dart). CI 대상 아님.
import 'dart:math' as math;
import 'package:isekai_reality/core/rules/rules.dart';
import 'level_sim.dart' as ls;

void main() {
  // ignore: avoid_print
  print('Lv | 가 고르게·장비없음 | 나 새 기준 | 다 대표');
  for (var lv = 10; lv <= 17; lv++) {
    final row = <String>[];
    for (final k in ['A', 'B', 'C']) {
      final p = ls.profile(k, lv);
      var clears = 0;
      for (var s = 0; s < 200; s++) {
        final b = Battle.forPlayer(level: lv, stats: p.stats, gear: p.gear, rng: math.Random(s),
            floors: BattleRules.dungeonFloors(level: lv, atGate: false, rng: math.Random(s))).runToEnd();
        if (b.phase == BattlePhase.cleared) clears++;
      }
      row.add('${(clears / 2).round()}%');
    }
    // ignore: avoid_print
    print('Lv.$lv | ${row.join(' | ')}');
  }
}
