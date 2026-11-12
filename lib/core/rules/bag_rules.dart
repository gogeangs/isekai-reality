import 'dart:math' as math;

import '../models/armory.dart';
import 'equipment_rules.dart';
import 'materials.dart';
import 'town_rules.dart';

/// 가방 칸 (11-11 #48). 마석·금화는 칸을 차지하지 않는다.
/// 같은 아이템은 한 칸에 99개까지, 장비는 한 칸에 하나.
class BagRules {
  BagRules._();

  static const int baseSlots = 20;
  static const int slotsPerExpansion = 5;
  static const int maxSlots = 100;
  static const int stackMax = 99;

  /// [done] 번 늘린 뒤 다음 확장 가격 (200, 400, 700, 1,000, 그다음 1,000씩 더)
  static int expansionCost(int done) => switch (done) {
        0 => 200,
        1 => 400,
        2 => 700,
        _ => 1000 * (done - 2),
      };

  /// 한 칸씩 열기 (묶음 15 #106): [opened] 칸 연 뒤 다음 한 칸 가격.
  /// 80 → 100 → 130 → 170 → 220 → 280 … (오름폭이 10씩 커진다), 최대 2,000
  static int slotCost(int opened) =>
      math.min(2000, 80 + 5 * opened * opened + 15 * opened);

  /// 광고로도 열 수 있는 칸 (한 칸씩 연 것 중 첫째·둘째)
  static const int adSlots = 2;

  /// 칸 수 (예전 5칸 묶음 + 한 칸씩 연 칸 + 다른 방법으로 늘린 칸)
  static int capacity(
          {int goldExpansions = 0, int extraSlots = 0, int singleSlots = 0}) =>
      math.min(
          maxSlots,
          baseSlots +
              goldExpansions * slotsPerExpansion +
              extraSlots +
              singleSlots);

  static int stacks(int n) => n <= 0 ? 0 : (n + stackMax - 1) ~/ stackMax;

  /// 쓰는 칸 수: 재료·소비 아이템은 99개마다 한 칸, 입지 않은 장비·펫 알은 하나씩
  static int usedSlots({
    required Map<MaterialId, int> materials,
    required Map<ShopItem, int> items,
    required Armory armory,
    int eggs = 0,
    List<int> extraStacks = const [],
  }) {
    var n = eggs;
    for (final v in extraStacks) {
      n += stacks(v);
    }
    for (final v in materials.values) {
      n += stacks(v);
    }
    for (final v in items.values) {
      n += stacks(v);
    }
    for (final e in armory.items) {
      if (!armory.isWorn(e)) n++;
    }
    return n;
  }

  // ───────────────────────── 판매 가격 (잡화상에서 팔 때, 가방이 가득 차 금화로 바뀔 때)

  static int materialPrice(MaterialId m) =>
      Materials.info(m).price ?? (Materials.info(m).rare ? 25 : 5);

  static int itemPrice(ShopItem i) => TownRules.info(i).price ~/ 2;

  static int equipPrice(EquipItem e) {
    final base = switch (e.grade) {
      EquipGrade.white => 30,
      EquipGrade.green => 60,
      EquipGrade.blue => 120,
      EquipGrade.purple => 250,
      EquipGrade.orange => 500,
    };
    return (base * (1 + 0.1 * e.enhance)).round();
  }

  /// 새로 얻은 재료가 가방에 들어갈 만큼만 넣고, 나머지는 금화로 바꾼다.
  /// 이미 있는 칸에 쌓이는 것은 칸을 더 쓰지 않는다.
  static ({Map<MaterialId, int> kept, int gold}) fit({
    required Map<MaterialId, int> incoming,
    required Map<MaterialId, int> have,
    required int freeSlots,
  }) {
    final kept = <MaterialId, int>{};
    var gold = 0;
    var free = freeSlots;
    for (final e in incoming.entries) {
      final cur = have[e.key] ?? 0;
      final room = cur == 0 ? 0 : stacks(cur) * stackMax - cur;
      var take = math.min(room, e.value);
      var rest = e.value - take;
      while (rest > 0 && free > 0) {
        final n = math.min(stackMax, rest);
        take += n;
        rest -= n;
        free--;
      }
      if (take > 0) kept[e.key] = take;
      gold += rest * materialPrice(e.key);
    }
    return (kept: kept, gold: gold);
  }
}
