import 'element_rules.dart';
import 'dart:math' as math;

import '../geo/geo.dart';
import 'exclusion_index.dart';
import 'exploration_rules.dart';
import 'harvest_rules.dart';
import 'modifier_rules.dart';
import 'monsters.dart';
import 'place_grid.dart';
import 'road_mask.dart';
import 'rule_constants.dart';

/// 지도에 나타난 필드 몬스터 하나
class FieldSpawn {
  const FieldSpawn({
    required this.id,
    required this.monster,
    required this.point,
    this.modifiers = const [],
  });

  /// 하루 안에서 겹치지 않는 id (예: '2026-11-08#3')
  final String id;
  final MonsterId monster;
  final GeoPoint point;

  /// 수식어 (11-10 #21). 자리마다 정해지고, 보는 사람의 레벨로 등급을 나눈다.
  final List<ModifierId> modifiers;

  MonsterInfo get info => Monsters.info(monster);

  /// 수식어를 붙인 이름
  String get name => ModifierRules.displayName(monster, modifiers);

  ModGrade get grade => ModifierRules.gradeOf(modifiers);
}

class FieldMonsterRules {
  FieldMonsterRules._();

  /// 그날의 필드 몬스터. 날짜로 정해지므로 같은 날에는 누구에게나 같은 자리.
  ///
  /// - 전국을 1km 블록으로 나눈 같은 격자를 쓴다 (11-10 전국 확대).
  ///   블록마다 70% 확률로 한 마리: 슬라임 또는 큰쥐.
  ///   블록마다 따로 난수를 쓰므로 어디서 보든 같은 블록에는 같은 몬스터.
  /// - [center] 가 있으면 그 둘레 [radiusM] 안 블록만, 없으면 지역 전체
  /// - 장소가 있는 지역이면 장소마다 한 마리 (장소에서 80~150m, 장소에 맞는 몬스터)
  /// - 밤(오후 7시 ~ 새벽 6시)에는 블록 몬스터 중 다섯에 하나꼴로 그림자 나비
  /// - 제외 구역([exclusions] 포함)과 지역 밖에는 두지 않는다.
  ///   [roads] 가 있으면 큰길·철로 둘레에도 두지 않는다.
  static List<FieldSpawn> spawnsFor(
    ExploreArea area,
    DateTime day, {
    GeoPoint? center,
    double radiusM = RuleConstants.fieldSpawnRadiusM,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    int level = 1,
    double luckBonus = 0,
    Set<Element> favored = const {},
    LandKind? Function(GeoPoint)? land,
    List<MonsterId> lampMonsters = const [],
    double lampShare = 0,
    int? tierLevel,
  }) {
    final key = slotKey(day);
    // 묶음 69 #280: 몬스터 종류는 보는 사람(파티 함께면 파티장) 레벨 단계
    final tier = tierOf(tierLevel ?? level);
    final spawns = <FieldSpawn>[];

    bool allowed(GeoPoint p) =>
        area.bounds.contains(p) &&
        !area.isExcluded(p) &&
        !(exclusions?.contains(p) ?? false) &&
        !(roads?.isRoad(p) ?? false);

    GeoPoint? pick(GeoPoint Function() candidate) {
      for (var attempt = 0; attempt < 8; attempt++) {
        final p = candidate();
        if (allowed(p)) return p;
      }
      return null;
    }

    for (final place in area.places) {
      if (center != null && place.point.distanceTo(center) > radiusM + 200) {
        continue;
      }
      final rng = math.Random(_stableHash('$key|${place.id}'));
      final p = pick(() => _offset(
            place.point,
            80 + rng.nextDouble() * 70,
            rng.nextDouble() * 2 * math.pi,
          ));
      if (p == null) continue;
      final id = '$key#${place.id}';
      final monster = _habitatMonster(place.kind);
      spawns.add(FieldSpawn(
        id: id,
        monster: monster,
        point: p,
        modifiers: ModifierRules.roll(id, monster, level, bonus: luckBonus),
      ));
    }

    // 11-11: 슬라임 30 · 큰쥐 25 · 혼래빗 20 · 아기 와일드 보어 15 · 미궁 박쥐 10
    const blockLat = RuleConstants.fieldSpawnBlockM / 111320;
    final b = area.bounds;
    final double south, north;
    if (center == null) {
      south = b.south;
      north = b.north;
    } else {
      south = center.lat - radiusM / 111320;
      north = center.lat + radiusM / 111320;
    }
    final night = isNight(day);
    for (var r = (south / blockLat).floor();
        r <= (north / blockLat).floor();
        r++) {
      final rowLat = (r + 0.5) * blockLat;
      final blockLng = RuleConstants.fieldSpawnBlockM /
          (111320 * math.cos(rowLat * math.pi / 180));
      final double west, east;
      if (center == null) {
        west = b.west;
        east = b.east;
      } else {
        final dLng =
            radiusM / (111320 * math.cos(center.lat * math.pi / 180));
        west = center.lng - dLng;
        east = center.lng + dLng;
      }
      for (var c = (west / blockLng).floor();
          c <= (east / blockLng).floor();
          c++) {
        final s0 = r * blockLat, w0 = c * blockLng;
        if (center != null &&
            GeoPoint(s0 + blockLat / 2, w0 + blockLng / 2)
                    .distanceTo(center) >
                radiusM) {
          continue;
        }
        // 블록마다 같은 순서로 난수를 쓴다 (밤낮·보는 자리에 따라 바뀌지 않게)
        final rng = math.Random(_stableHash('$key|$r|$c'));
        final roll = rng.nextDouble();
        final kindRoll = rng.nextDouble();
        final butterflyRoll = rng.nextDouble();
        final elementRoll = rng.nextDouble();
        if (roll >= RuleConstants.fieldSpawnChance) continue;
        final p = pick(() => GeoPoint(
              s0 + rng.nextDouble() * blockLat,
              w0 + rng.nextDouble() * blockLng,
            ));
        if (p == null) continue;
        final id = '$key#${r}_$c';
        final landHere = land?.call(p);
        final base = night && butterflyRoll < nightButterflyShare
            ? MonsterId.shadowButterfly
            : pickCommon(kindRoll, elementRoll,
                night: night,
                favored: favored,
                landFavored: landElements(landHere));
        // 묶음 69 #280: 자리 · 수식어는 누구에게나 같고(1단계 몬스터로 정함), 종류만 보는 사람 단계
        final mixRoll = rng.nextDouble();
        final pickRoll = rng.nextDouble();
        final mods = ModifierRules.roll(id, base, level, bonus: luckBonus);
        var monster = tierMonster(base, tier: tier, mixRoll: mixRoll, pickRoll: pickRoll, land: landHere);
        // 묶음 53 #243: 등불을 켠 지역의 몬스터가 가끔 (예전 난수 순서는 그대로 두고 맨 뒤에 굴림)
        if (lampMonsters.isNotEmpty) {
          final lr = rng.nextDouble();
          if (lr < lampShare) {
            monster = lampMonsters[(lr / lampShare * lampMonsters.length)
                .floor()
                .clamp(0, lampMonsters.length - 1)];
          }
        }
        spawns.add(FieldSpawn(
          id: id,
          monster: monster,
          point: p,
          modifiers: mods,
        ));
      }
    }
    return spawns;
  }

  // ───────────── 묶음 66 #267: 하루 6칸 (한국 시간 0 · 4 · 8 · 12 · 16 · 20시)

  static const int slotHours = 4;

  static DateTime _kst(DateTime t) => t.toUtc().add(const Duration(hours: 9));

  /// 자리 키: '2026-11-19@3' (한국 날짜 · 칸)
  static String slotKey(DateTime t) {
    final k = _kst(t);
    return '${k.year}-${k.month}-${k.day}@${k.hour ~/ slotHours}';
  }

  /// 다음 칸까지 남은 시간
  static Duration untilNextSlot(DateTime t) {
    final k = _kst(t);
    final next = DateTime.utc(k.year, k.month, k.day, (k.hour ~/ slotHours + 1) * slotHours);
    return next.difference(DateTime.utc(k.year, k.month, k.day, k.hour, k.minute, k.second));
  }

  /// 「몬스터가 바뀌기까지 1시간 20분」 (1시간 안 남으면 「○분」)
  static String untilText(DateTime t) {
    final d = untilNextSlot(t);
    final m = (d.inSeconds + 59) ~/ 60;
    final h = m ~/ 60, r = m % 60;
    if (h <= 0) return '몬스터가 바뀌기까지 $r분';
    return r == 0 ? '몬스터가 바뀌기까지 $h시간' : '몬스터가 바뀌기까지 $h시간 $r분';
  }

  /// 초반(Lv.2~5) 나에게만 보이는 몬스터 (묶음 25 #171).
  /// 그날 처음 위치를 잡은 곳([anchor]) 둘레 150~400m에 [count]마리.
  /// 큰길·제외 구역·물 위는 피하고, 종류는 보통 비율, 수식어 규칙 그대로.
  static List<FieldSpawn> nearSpawns(
    ExploreArea area, {
    required String dayKey,
    required GeoPoint anchor,
    int count = 3,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    int level = 1,
    double luckBonus = 0,
    bool night = false,
    Set<Element> favored = const {},
    LandKind? Function(GeoPoint)? land,
    int? tierLevel,
  }) {
    final tier = tierOf(tierLevel ?? level);
    bool allowed(GeoPoint p) {
      final l = land?.call(p);
      return area.bounds.contains(p) &&
          !area.isExcluded(p) &&
          !(exclusions?.contains(p) ?? false) &&
          !(roads?.isRoad(p) ?? false) &&
          l != LandKind.water &&
          l != LandKind.sea;
    }

    final out = <FieldSpawn>[];
    for (var i = 0; i < count; i++) {
      final rng = math.Random(_stableHash('$dayKey|near|$i'));
      final kindRoll = rng.nextDouble();
      final elementRoll = rng.nextDouble();
      GeoPoint? p;
      for (var attempt = 0; attempt < 12 && p == null; attempt++) {
        // 셋이 고르게 퍼지도록 방향을 120°씩 나누고 그 안에서 흔든다
        final bearing =
            (i + rng.nextDouble()) * 2 * math.pi / count;
        final c = _offset(anchor, 150 + rng.nextDouble() * 250, bearing);
        if (allowed(c)) p = c;
      }
      if (p == null) continue;
      final id = 'near-$dayKey-$i';
      final base = pickCommon(kindRoll, elementRoll,
          night: night,
          favored: favored,
          landFavored: landElements(land?.call(p)));
      final mixRoll = rng.nextDouble();
      final pickRoll = rng.nextDouble();
      out.add(FieldSpawn(
        id: id,
        monster: tierMonster(base, tier: tier, mixRoll: mixRoll, pickRoll: pickRoll, land: land?.call(p), night: night),
        point: p,
        modifiers: ModifierRules.roll(id, base, level, bonus: luckBonus),
      ));
    }
    return out;
  }

  /// 블록 몬스터 비율 (11-11)
  static const List<(MonsterId, double)> commonWeights = [
    (MonsterId.ashSlime, 0.30),
    (MonsterId.giantRat, 0.25),
    (MonsterId.hornRabbit, 0.20),
    (MonsterId.babyBoar, 0.15),
    (MonsterId.labyrinthBat, 0.10),
  ];

  /// 슬라임 속성 비율 (낮, 밤). 빛은 낮에, 어둠은 밤에 조금 더 자주.
  /// 11-11 #63: 속성 슬라임 11종 (무속성 + 10속성)
  static const List<(MonsterId, double, double)> slimeWeights = [
    (MonsterId.ashSlime, 0.32, 0.32),
    (MonsterId.fireSlime, 0.075, 0.075),
    (MonsterId.waterSlime, 0.075, 0.075),
    (MonsterId.windSlime, 0.075, 0.075),
    (MonsterId.earthSlime, 0.075, 0.075),
    (MonsterId.iceSlime, 0.075, 0.075),
    (MonsterId.thunderSlime, 0.075, 0.075),
    (MonsterId.metalSlime, 0.075, 0.075),
    (MonsterId.poisonSlime, 0.075, 0.075),
    (MonsterId.lightSlime, 0.06, 0.02),
    (MonsterId.darkSlime, 0.02, 0.06),
  ];

  /// 장소 종류에 어울리는 속성 (묶음 14 A3, 숨은 규칙). 마을은 고르게.
  static Set<Element> landElements(LandKind? land) => switch (land) {
        LandKind.water || LandKind.sea => const {Element.water, Element.ice},
        LandKind.park || LandKind.forest => const {
            Element.earth,
            Element.wind,
            Element.poison
          },
        LandKind.mountain => const {Element.earth, Element.metal, Element.wind},
        LandKind.city => const {Element.metal, Element.thunder, Element.dark},
        LandKind.village || null => const {},
      };

  /// 장소에 맞는 속성 몬스터가 조금 더 자주 (숨김)
  static const double landWeight = 1.4;

  /// [kindRoll]·[elementRoll] 은 0~1 난수
  /// [favored]: 내 주 속성에 강한 속성 (11-11 #63). 그 속성 몬스터가 1.5배 자주.
  /// [landFavored]: 장소에 어울리는 속성 (묶음 14). 둘 다 맞아도 곱하지 않고 큰 쪽만
  /// (어느 한쪽이 너무 커지지 않게).
  static MonsterId pickCommon(double kindRoll, double elementRoll,
      {bool night = false,
      Set<Element> favored = const {},
      Set<Element> landFavored = const {}}) {
    double w(MonsterId m, double base) {
      final e = Monsters.info(m).element;
      var f = 1.0;
      if (favored.contains(e)) f = ElementRules.challengeWeight;
      if (landFavored.contains(e) && landWeight > f) f = landWeight;
      return base * f;
    }
    final kinds = [for (final (m, b) in commonWeights) (m, w(m, b))];
    final kindTotal = kinds.fold(0.0, (a, e) => a + e.$2);
    var acc = 0.0;
    var kind = commonWeights.last.$1;
    for (final (m, x) in kinds) {
      acc += x / kindTotal;
      if (kindRoll < acc) {
        kind = m;
        break;
      }
    }
    if (kind != MonsterId.ashSlime) return kind;
    final slimes = [
      for (final (m, day, nightW) in slimeWeights) (m, w(m, night ? nightW : day)),
    ];
    final total = slimes.fold(0.0, (a, e) => a + e.$2);
    acc = 0;
    for (final (m, x) in slimes) {
      acc += x / total;
      if (elementRoll < acc) return m;
    }
    return MonsterId.ashSlime;
  }

  // ───────────── 묶음 69 #280 · #281: 레벨이 오르면 지도 몬스터가 강한 몬스터로

  /// 보는 사람 레벨 → 단계 (1 Lv.1~10 · 2 Lv.11~20 · 3 Lv.21~30 · 4 Lv.31~49 · 5 Lv.50~)
  static int tierOf(int level) => level >= 50
      ? 5
      : level >= 31
          ? 4
          : level >= 21
              ? 3
              : level >= 11
                  ? 2
                  : 1;

  /// 단계마다 장소별 몬스터 (2~4단계는 3막 몬스터, 5단계는 새 몬스터 13종)
  static List<MonsterId> tierLand(int tier, LandKind? land) {
    final l = land == LandKind.sea ? LandKind.water : land;
    return switch ((tier, l)) {
      (2, LandKind.forest) => const [MonsterId.woodWolf, MonsterId.wildBoar],
      (2, LandKind.mountain) => const [MonsterId.harpy, MonsterId.koboldMiner],
      (2, LandKind.water) => const [MonsterId.wildBoar, MonsterId.goblinRaider],
      (2, _) => const [MonsterId.goblinRaider, MonsterId.koboldMiner],
      (3, LandKind.forest || LandKind.park) => const [MonsterId.giantSpider, MonsterId.treant],
      (3, LandKind.water) => const [MonsterId.wildLizardman],
      (3, LandKind.mountain) => const [MonsterId.salamander, MonsterId.orcMerc],
      (3, _) => const [MonsterId.orcMerc, MonsterId.gargoyle],
      (4, LandKind.city) => const [MonsterId.livingArmor],
      (4, LandKind.forest || LandKind.park) => const [MonsterId.dryad],
      (4, LandKind.mountain) => const [MonsterId.wildTroll, MonsterId.koboldrake],
      (4, LandKind.water) => const [MonsterId.wildLizardman, MonsterId.ogre],
      (4, _) => const [MonsterId.ogre],
      (5, LandKind.city) => const [MonsterId.sphinx, MonsterId.clockworkKnight],
      (5, LandKind.forest || LandKind.park) => const [MonsterId.centaur, MonsterId.owlbear],
      (5, LandKind.water) => const [MonsterId.kelpie, MonsterId.naga],
      (5, LandKind.mountain) => const [MonsterId.roc],
      (5, _) => const [MonsterId.doppelganger, MonsterId.arachne],
      _ => const [],
    };
  }

  /// 단계마다 밤 몬스터 (그림자 나비 자리)
  static List<MonsterId> tierNight(int tier) => switch (tier) {
        2 => const [MonsterId.vampireBat],
        3 => const [MonsterId.skeletonGuard],
        4 => const [MonsterId.wraith, MonsterId.ghoul],
        5 => const [MonsterId.dullahan, MonsterId.werewolf, MonsterId.deathKnight],
        _ => const [],
      };

  /// 섞는 비율: 지금 단계 60% · 바로 아래 단계 30% · 1단계 10%
  static const double tierNowShare = 0.6;
  static const double tierBelowShare = 0.3;

  /// 5단계에서 바실리스크: 블록 몬스터의 3%
  static const double basiliskShare = 0.03;

  /// 단계 몬스터 모두 (도감 「더 강한 필드 몬스터」 순서)
  static List<MonsterId> get tierMonsters {
    final out = <MonsterId>[];
    for (var t = 2; t <= 5; t++) {
      for (final land in [null, LandKind.city, LandKind.forest, LandKind.water, LandKind.mountain]) {
        for (final m in tierLand(t, land)) {
          if (!out.contains(m)) out.add(m);
        }
      }
      for (final m in tierNight(t)) {
        if (!out.contains(m)) out.add(m);
      }
      if (t == 5) out.add(MonsterId.basilisk);
    }
    return out;
  }

  /// 단계 몬스터인지 (지도에서 레벨 단계로 나오는 몬스터)
  static bool isTierMonster(MonsterId m) => tierMonsters.contains(m);

  /// 1단계 몬스터 [base] → 보는 사람 단계의 몬스터. [mixRoll] · [pickRoll] 은 자리마다 정한 0~1 난수
  static MonsterId tierMonster(MonsterId base,
      {required int tier, required double mixRoll, required double pickRoll, LandKind? land, bool night = false}) {
    if (tier <= 1) return base;
    final int t;
    if (mixRoll < tierNowShare) {
      t = tier;
    } else if (mixRoll < tierNowShare + tierBelowShare) {
      t = tier - 1;
    } else {
      t = 1;
    }
    if (t <= 1) return base;
    // 5단계: 어디서든 드물게 바실리스크
    if (t == 5 && pickRoll < basiliskShare / tierNowShare && base != MonsterId.shadowButterfly) {
      return Monsters.hasArt(MonsterId.basilisk) ? MonsterId.basilisk : _pick(tierLand(4, land), pickRoll);
    }
    final list = base == MonsterId.shadowButterfly || night ? tierNight(t) : tierLand(t, land);
    final m = _pick(list, pickRoll);
    // 5단계 그림이 아직 없으면 4단계 몬스터로 (그림이 오면 바로 씀)
    if (t == 5 && !Monsters.hasArt(m)) {
      return _pick(base == MonsterId.shadowButterfly || night ? tierNight(4) : tierLand(4, land), pickRoll);
    }
    return m;
  }

  static MonsterId _pick(List<MonsterId> list, double roll) =>
      list[(roll * list.length).floor().clamp(0, list.length - 1)];

  /// 특정 몬스터 부탁: 그 몬스터가 지금 단계에서 거의 안 나오면 그 단계의 비슷한 몬스터로
  /// (슬라임 → 고블린 약탈자 · 큰쥐 → 코볼트 광부 · 밤 몬스터 → 그 단계 밤 몬스터 …)
  static MonsterId askFor(MonsterId m, int level) {
    final tier = tierOf(level);
    if (tier <= 1) return m;
    if (isTierMonster(m)) return m;
    final night = m == MonsterId.shadowButterfly || m == MonsterId.labyrinthBat;
    final list = night ? tierNight(tier) : tierLand(tier, null);
    final i = Monsters.slimes.contains(m) ? 0 : 1;
    final pick = list[i.clamp(0, list.length - 1)];
    return tier == 5 && !Monsters.hasArt(pick) ? (night ? tierNight(4) : tierLand(4, null)).first : pick;
  }

  /// 보름달 밤 (웨어울프가 더 셈): 보름 앞뒤 하루 (숨김)
  static bool isFullMoon(DateTime t) {
    const synodic = 29.530588853;
    final ref = DateTime.utc(2000, 1, 6, 18, 14); // 삭
    final days = t.toUtc().difference(ref).inMinutes / 1440.0;
    final age = days % synodic;
    return (age - synodic / 2).abs() <= 1.0;
  }

  /// 밤에 그림자 나비가 되는 블록 몬스터 비율
  static const double nightButterflyShare = 0.2;

  /// 그림자 나비가 나오는 시간 (오후 7시 ~ 새벽 6시)
  static bool isNight(DateTime t) => HarvestRules.isNight(t); // 묶음 69: 밤은 19~6시 하나로

  /// 지금 위치에서 만날 수 있는 가장 가까운 몬스터.
  /// 차량 속도로 움직이는 중이거나 제외 구역 안이면 없음.
  static FieldSpawn? encounter({
    required ExploreArea area,
    required List<FieldSpawn> spawns,
    required LocationFix fix,
    ExclusionIndex? exclusions,
  }) {
    if (!ExplorationRules.countsAsExploring(fix)) return null;
    if (area.isExcluded(fix.point)) return null;
    if (exclusions?.contains(fix.point) ?? false) return null;
    FieldSpawn? best;
    double? bestDistance;
    for (final s in spawns) {
      final d = s.point.distanceTo(fix.point);
      if (d > RuleConstants.fieldEncounterRadiusM) continue;
      if (bestDistance == null || d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  static MonsterId _habitatMonster(PlaceKind kind) => switch (kind) {
        PlaceKind.labyrinthGate => MonsterId.labyrinthBat,
        // 물방울 정령(정령계)을 뺐다 (11-10)
        PlaceKind.spiritLake => MonsterId.ashSlime,
      };

  /// [from] 에서 [meters] 만큼 [bearing] 방향으로 옮긴 점 (짧은 거리용 근사)
  static GeoPoint _offset(GeoPoint from, double meters, double bearing) {
    final dLat = meters * math.cos(bearing) / 111320;
    final dLng = meters *
        math.sin(bearing) /
        (111320 * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  /// 실행할 때마다 같은 값을 내는 문자열 해시 (FNV-1a 32비트)
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
