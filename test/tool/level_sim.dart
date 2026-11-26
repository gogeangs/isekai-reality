// 개발용: 묶음 85 #408 레벨별 난이도 표 (flutter test test/tool/level_sim.dart). CI 대상 아님.
import 'dart:math' as math;
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';

/// (가) 고르게 · 장비 없음 (나) 몰아주기 · 보통 장비 (다) 대표 계정 비슷하게 (Lv.21 힘 102 · 무기 +16.8%)
({Stats stats, GearBonus gear}) profile(String k, int lv) {
  final pts = math.max(0, lv - 1) * 5;
  switch (k) {
    case 'A':
      return (stats: BattleRules.expectedStats(lv), gear: GearBonus.none);
    case 'B':
      final ramp = BattleRules.gearRamp(lv);
      final enh = (3 * ramp).round();
      final items = [
        for (final b in [EquipBase.woodAxe, EquipBase.cap, EquipBase.boarArmor, EquipBase.gloves, EquipBase.boots, EquipBase.wardenCharm])
          if (ramp >= 0.3) EquipItem(uid: b.name, base: b, grade: ramp >= 0.8 ? EquipGrade.blue : EquipGrade.green, enhance: enh),
      ];
      return (stats: BattleRules.baselineStats(lv), gear: EquipmentRules.bonusOf(items));
    default:
      // 힘에 거의 다 (포인트 92/100 비율) · 무기 파랑+6 정도(+16.8%) · 나머지 보통
      final str = StatRules.start + (pts * 0.92).round();
      final rest = StatRules.start + ((pts - (pts * 0.92).round()) ~/ 4);
      final items = [
        const EquipItem(uid: 'w', base: EquipBase.woodAxe, grade: EquipGrade.blue, enhance: 3),
        for (final b in [EquipBase.cap, EquipBase.boarArmor, EquipBase.gloves, EquipBase.boots, EquipBase.wardenCharm])
          EquipItem(uid: b.name, base: b, grade: EquipGrade.blue, enhance: 3),
      ];
      return (
        stats: Stats(strength: str, agility: rest, intellect: rest, vitality: rest, luck: rest),
        gear: EquipmentRules.bonusOf(items)
      );
  }
}

void main() {
  print('레벨 | 기준 | 필드 공격수 | 필드 받는 HP% | 필드 지는% | 던전 클리어% | 분신 턴(예고 보며) | 수호자 턴');
  for (final lv in [5, 10, 11, 15, 21, 30]) {
    for (final k in ['A', 'B', 'C']) {
      final p = profile(k, lv);
      Battle field(int seed, {MonsterId m = MonsterId.giantRat}) => Battle.forPlayer(
          level: lv, stats: p.stats, gear: p.gear, rng: math.Random(seed),
          floors: BattleRules.fieldFoes(level: lv, monster: m));
      final probe = field(0);
      final hits = probe.foe.maxHp / probe.playerAttack;
      var lost = 0, taken = 0.0;
      const n = 200;
      for (var s = 0; s < n; s++) {
        final b = field(s, m: MonsterId.values[s % 12]).runToEnd();
        if (b.phase != BattlePhase.cleared) lost++;
        taken += 1 - b.playerHp / b.playerMaxHp;
      }
      var clears = 0;
      for (var s = 0; s < 100; s++) {
        final b = Battle.forPlayer(level: lv, stats: p.stats, gear: p.gear, rng: math.Random(s),
            floors: BattleRules.dungeonFloors(level: lv, atGate: false, rng: math.Random(s))).runToEnd();
        if (b.phase == BattlePhase.cleared) clears++;
      }
      // 턴제 (예고를 보고 싸움 · 물약 셋)
      final hero = Battle.forPlayer(level: lv, stats: p.stats, gear: p.gear, floors: [BattleRules.fieldFoe(level: lv, monster: MonsterId.giantRat)]);
      double ashTurns() {
        var t = 0, w = 0;
        for (var s = 0; s < 100; s++) {
          final a = AshTurn(avatar: AshAvatar.rage, level: lv, heroMaxHp: hero.playerMaxHp, heroHp: hero.playerMaxHp,
              heroAttack: hero.playerAttack, crit: hero.playerCrit, evade: hero.playerEvade, damageTaken: hero.damageTaken,
              mp: 0, mpMax: 0, hasPet: true,
              potions: const [BattlePotion(key: 'p', name: '물약', count: 3, hpRatio: 0.4)], rng: math.Random(s));
          while (!a.isOver && a.turn < 60) {
            if (a.hp < a.heroMaxHp * 0.35 && a.can(AshCmd.potion)) {
              a.act(AshCmd.potion);
            } else if (a.faceOpen && a.gauge >= 4) {
              a.act(AshCmd.face);
            } else if (a.specialNext) {
              a.act(AshCmd.guard);
            } else {
              a.act(AshCmd.attack);
            }
          }
          if (a.won) {
            w++;
            t += a.turn;
          }
        }
        return w == 0 ? -1 : t / w;
      }
      double skyTurns() {
        var t = 0, w = 0;
        for (var s = 0; s < 100; s++) {
          final a = SkyTurn(isle: Isle.values[s % 5], level: lv, heroMaxHp: hero.playerMaxHp, heroHp: hero.playerMaxHp,
              heroAttack: hero.playerAttack, crit: hero.playerCrit, evade: hero.playerEvade, damageTaken: hero.damageTaken,
              mp: 0, mpMax: 0, hasPet: true,
              potions: const [BattlePotion(key: 'p', name: '물약', count: 3, hpRatio: 0.4)], rng: math.Random(s));
          while (!a.isOver && a.turn < 60) {
            SkyCmd c;
            if (a.hp < a.heroMaxHp * 0.35 && a.can(SkyCmd.potion)) {
              c = SkyCmd.potion;
            } else if (a.intent == SkyIntent.bolt || a.intent == SkyIntent.whirl || a.intent == SkyIntent.wash) {
              c = SkyCmd.guard;
            } else if (a.can(SkyCmd.petSkill)) {
              c = SkyCmd.petSkill;
            } else {
              c = SkyCmd.strike;
            }
            a.act(c);
          }
          if (a.won) {
            w++;
            t += a.turn;
          }
        }
        return w == 0 ? -1 : t / w;
      }

      print('Lv.$lv | $k | ${hits.toStringAsFixed(1)} | ${(taken / n * 100).round()}% | ${(lost * 100 / n).round()}% | $clears% | ${ashTurns().toStringAsFixed(1)} | ${skyTurns().toStringAsFixed(1)}');
    }
  }
}
