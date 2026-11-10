import 'dart:math' as math;

import 'materials.dart';

/// 걸음 주머니 · 던전 재료 · 길가의 발견 · 떠돌이 상인 (11-11 #59, 제안서 3 확정 값)
class GatherRules {
  GatherRules._();

  /// 1,500보마다 걸음 주머니 하나, 하루 6개까지
  static const int pouchSteps = 1500;
  static const int pouchesPerDay = 6;

  static int pouchesFor(int steps) =>
      math.min(pouchesPerDay, steps ~/ pouchSteps);

  /// 길에서 주울 만한 재료
  static const roadside = [
    MaterialId.herb,
    MaterialId.twig,
    MaterialId.ironShard,
    MaterialId.slimeJelly,
    MaterialId.ratHide,
  ];

  /// 귀한 재료 (주머니·길가·상인)
  static const rares = [
    MaterialId.slimeCore,
    MaterialId.glossyFur,
    MaterialId.batFang,
    MaterialId.goldenRabbitFur,
    MaterialId.smallTusk,
    MaterialId.sleepPowder,
    MaterialId.fireCore,
    MaterialId.waterCore,
    MaterialId.windCore,
    MaterialId.earthCore,
  ];

  /// 주머니를 열면: 길 재료 2개, 20% 귀한 재료 1개, 10% 금화 10~30, 3% 레시피 쪽지
  static ({Map<MaterialId, int> mats, int gold, bool note}) openPouch(
      math.Random rng) {
    final mats = <MaterialId, int>{};
    for (var i = 0; i < 2; i++) {
      final m = roadside[rng.nextInt(roadside.length)];
      mats[m] = (mats[m] ?? 0) + 1;
    }
    if (rng.nextDouble() < 0.20) {
      final r = rares[rng.nextInt(rares.length)];
      mats[r] = (mats[r] ?? 0) + 1;
    }
    final gold = rng.nextDouble() < 0.10 ? 10 + rng.nextInt(21) : 0;
    return (mats: mats, gold: gold, note: rng.nextDouble() < 0.03);
  }

  // ───────────── 던전 재료

  /// 던전 한 번에 미궁 석재 1~2 (클리어 못 해도), 클리어하면 10%로 빛바랜 룬석
  static Map<MaterialId, int> dungeon(bool cleared, math.Random rng) => {
        MaterialId.labyrinthStone: 1 + rng.nextInt(2),
        if (cleared && rng.nextDouble() < 0.10) MaterialId.runeStone: 1,
      };

  // ───────────── 길가의 발견

  /// 새로 2,000보마다 25%, 하루 3번, 알림 뒤 30분 안에 열어야 받는다
  static const int findSteps = 2000;
  static const double findChance = 0.25;
  static const int findsPerDay = 3;
  static const Duration findValid = Duration(minutes: 30);

  /// 재료 2~3개(귀한 것 30%) 또는 금화 30~60, 10%로 레시피 쪽지
  static ({Map<MaterialId, int> mats, int gold, bool note}) openFind(
      math.Random rng) {
    final note = rng.nextDouble() < 0.10;
    if (rng.nextDouble() < 0.5) {
      return (mats: const {}, gold: 30 + rng.nextInt(31), note: note);
    }
    final mats = <MaterialId, int>{};
    final n = 2 + rng.nextInt(2);
    for (var i = 0; i < n; i++) {
      final m = rng.nextDouble() < 0.30
          ? rares[rng.nextInt(rares.length)]
          : roadside[rng.nextInt(roadside.length)];
      mats[m] = (mats[m] ?? 0) + 1;
    }
    return (mats: mats, gold: 0, note: note);
  }

  // ───────────── 떠돌이 상인

  /// 새로 3,000보마다 15%, 하루 1번, 20분 동안
  static const int merchantSteps = 3000;
  static const double merchantChance = 0.15;
  static const int merchantPerDay = 1;
  static const Duration merchantStay = Duration(minutes: 20);

  /// 귀한 재료 3가지를 1개씩 금화 60, 20%로 레시피 쪽지 금화 150
  static const int offerPrice = 60;
  static const int notePrice = 150;
  static const double noteOfferChance = 0.20;

  static Map<MaterialId, int> offers(math.Random rng) {
    final pool = [...rares]..shuffle(rng);
    return {for (final m in pool.take(3)) m: offerPrice};
  }

  /// 밤 10시 ~ 아침 7시에는 휴대폰 알림을 보내지 않는다
  static bool quietHour(DateTime t) => t.hour >= 22 || t.hour < 7;
}
