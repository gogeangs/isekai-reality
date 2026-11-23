// 개발용 시뮬레이션 (flutter test test/tool/sky_sim.dart). CI 대상 아님: 파일 이름이 _test 가 아니다.
import 'dart:math' as math;
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  for (final lv in [17, 25, 35]) {
    for (final isle in Isle.values) {
      for (final smart in [true, false]) {
        var wins = 0, turns = 0, pots = 0, hpLeft = 0.0;
        const n = 400;
        for (var k = 0; k < n; k++) {
          final rng = math.Random(k);
          final t = SkyTurn(
            isle: isle, level: lv,
            heroMaxHp: BattleRules.expectedMaxHp(lv), heroHp: BattleRules.expectedMaxHp(lv),
            heroAttack: BattleRules.expectedAttack(lv), crit: 0.1, evade: 0.05,
            mp: 60, mpMax: 100,
            skills: const [AshTurnSkill(key: 'a', name: '내려베기', mp: 20, attack: true), AshTurnSkill(key: 'w', name: '철벽', mp: 20, attack: false)],
            hasPet: true, potions: const [BattlePotion(key: 'p', name: '물약', count: 5, hpRatio: 0.4)], rng: rng);
          while (!t.isOver && t.turn < 60) {
            SkyCmd c;
            if (!smart) {
              c = t.can(SkyCmd.petSkill) ? SkyCmd.petSkill : t.can(SkyCmd.skill1) ? SkyCmd.skill1 : SkyCmd.strike;
            } else if (t.hp < t.heroMaxHp * 0.35 && t.can(SkyCmd.potion)) {
              c = SkyCmd.potion;
            } else if (t.intent == SkyIntent.bolt || t.intent == SkyIntent.whirl || t.intent == SkyIntent.wash) {
              c = t.can(SkyCmd.skill2) && t.intent == SkyIntent.whirl ? SkyCmd.skill2 : SkyCmd.guard;
            } else if (t.frost > 0) {
              c = SkyCmd.strike;
            } else if (t.can(SkyCmd.petSkill)) {
              c = SkyCmd.petSkill;
            } else if (t.can(SkyCmd.skill1)) {
              c = SkyCmd.skill1;
            } else {
              c = SkyCmd.strike;
            }
            t.act(c);
          }
          if (t.won) { wins++; turns += t.turn; hpLeft += t.hp / t.heroMaxHp; }
          pots += t.potionsUsed.values.fold(0, (a, b) => a + b);
        }
        // ignore: avoid_print
        print('lv$lv ${isle.name.padRight(7)} ${smart ? 'smart' : 'dumb '} win ${(wins * 100 / n).round()}% turns ${wins == 0 ? '-' : (turns / wins).toStringAsFixed(1)} pots ${(pots / n).toStringAsFixed(1)} hp ${wins == 0 ? '-' : (hpLeft / wins * 100).round()}%');
      }
    }
  }
}
