import 'dart:math' as math;

import '../models/armory.dart';
import 'act2_rules.dart';
import 'baldrin_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'highland_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'party_rules.dart';

/// 보스 장비 세트 (11-11 #82). 보스마다 6부위 한 벌.
/// 묶음 34: ash = 「잿빛 왕의 유품」 (만들 수 없고 분신·본체에게서만 얻는다)
/// 묶음 50: sky = 「하이랜드 수호 기사」 (하늘 돌 조각 + 섬 결정으로 만든다)
/// 묶음 56: party = 파티 보스 세트 「동행」 (파티 보스 재료로 만든다)
enum BossSet { warden, flame, frost, grove, night, storm, ash, sky, party }

/// 6개 세트 효과 (보스 고유 능력, 확률·배율은 숨김)
enum BossSetAbility {
  /// 문지기: 가끔 받는 피해를 절반으로 (돌 피부)
  stoneSkin,

  /// 불꽃 왕: 가끔 적을 불태움
  burn,

  /// 서리 늑대왕: 가끔 적을 얼림
  freeze,

  /// 고목 정령: 매 턴 조금씩 HP 회복
  regrow,

  /// 박쥐 여왕: 준 피해의 일부만큼 HP 회복
  drain,

  /// 천둥 그리폰: 가끔 한 번 더 공격
  chain,

  /// 잿빛 왕의 유품 (묶음 34): 잿빛 몬스터에게 더 세고 덜 다친다
  ashBane,

  /// 하이랜드 수호 기사 (묶음 50): 섬이 조금 더 오래 떠 있다
  skyKnight,

  /// 「동행」 (묶음 56): 파티 보스에게 더 세고, 함께 있을 때 더 자란다
  companion,
}

class BossSetInfo {
  const BossSetInfo({
    required this.id,
    required this.name,
    required this.boss,
    required this.element,
    required this.material,
    required this.ability,
    required this.abilityName,
    required this.abilityText,
    required this.look,
    required this.lookText,
    required this.aura,
    required this.parts,
  });

  final BossSet id;

  /// '서리 늑대 세트'
  final String name;
  final MonsterId boss;

  /// 세트 효과의 속성 (장비 속성을 바꿔도 그대로)
  final Element element;

  /// 그 보스 전용 재료
  final MaterialId material;

  final BossSetAbility ability;
  final String abilityName;

  /// 6개 효과 한 줄 (숫자 없이)
  final String abilityText;

  /// 6개를 다 입은 외형 이름과 설명 (그림 전에는 색·빛으로)
  final String look;
  final String lookText;

  /// 외형 빛 색 (ARGB)
  final int aura;

  /// 무기·머리·몸·장갑·신발·장신구 순서의 이름과 한 줄 설명
  final List<(EquipBase, String, String)> parts;
}

/// 보스 장비 규칙 (11-11 #82, 숫자는 제안값)
class BossGearRules {
  BossGearRules._();

  static const List<BossSetInfo> sets = [
    BossSetInfo(
      id: BossSet.warden,
      name: '문지기 세트',
      boss: MonsterId.labyrinthWarden,
      element: Element.metal,
      material: MaterialId.bossWardenHeart,
      ability: BossSetAbility.stoneSkin,
      abilityName: '돌 피부',
      abilityText: '가끔 받는 피해를 절반으로 줄여요',
      look: '돌의 수호자',
      lookText: '온몸에 은빛 룬이 흐르는 돌갑옷 모습',
      aura: 0xFFC9D2DE,
      parts: [
        (EquipBase.wardenWeapon, '문지기의 대검', '미궁 문을 지키던 돌날 대검'),
        (EquipBase.wardenHead, '문지기 투구', '눈 구멍에 은빛 룬이 빛나는 돌 투구'),
        (EquipBase.wardenBody, '돌심장 갑옷', '가슴에 문지기의 심장이 박힌 돌 갑옷'),
        (EquipBase.wardenHands, '바위 건틀릿', '바위를 깎아 만든 묵직한 손갑옷'),
        (EquipBase.wardenFeet, '석상 장화', '석상처럼 단단한 돌 장화'),
        (EquipBase.wardenAcc, '문지기의 인장', '미궁 문 무늬가 새겨진 돌 인장 반지'),
      ],
    ),
    BossSetInfo(
      id: BossSet.flame,
      name: '불꽃 왕 세트',
      boss: MonsterId.fireSlimeKing,
      element: Element.fire,
      material: MaterialId.bossKingOrb,
      ability: BossSetAbility.burn,
      abilityName: '왕의 불길',
      abilityText: '가끔 적을 불태워요',
      look: '불꽃의 왕',
      lookText: '어깨와 머리 위로 작은 불꽃이 일렁이는 모습',
      aura: 0xFFFF7A45,
      parts: [
        (EquipBase.flameWeapon, '불꽃왕의 지팡이', '끝에 꺼지지 않는 불꽃 구슬이 달린 지팡이'),
        (EquipBase.flameHead, '불꽃 왕관', '불꽃 슬라임 왕이 쓰던 작은 금 왕관'),
        (EquipBase.flameBody, '불꽃 젤리 로브', '따끈한 불꽃 젤리로 물들인 붉은 로브'),
        (EquipBase.flameHands, '불씨 장갑', '손끝에 불씨가 반짝이는 가죽 장갑'),
        (EquipBase.flameFeet, '불꽃 발자국 장화', '걸을 때마다 작은 불꽃 자국이 남는 장화'),
        (EquipBase.flameAcc, '왕의 불꽃 반지', '불꽃 구슬을 박은 금 반지'),
      ],
    ),
    BossSetInfo(
      id: BossSet.frost,
      name: '서리 늑대 세트',
      boss: MonsterId.frostWolfKing,
      element: Element.ice,
      material: MaterialId.bossFrostFang,
      ability: BossSetAbility.freeze,
      abilityName: '서리 송곳니',
      abilityText: '가끔 적을 얼려요',
      look: '서리 늑대',
      lookText: '하얀 늑대 털 망토와 서리 입김이 감도는 모습',
      aura: 0xFFA8E6FF,
      parts: [
        (EquipBase.frostWeapon, '서리 송곳니 검', '늑대왕의 송곳니를 벼린 얼음빛 검'),
        (EquipBase.frostHead, '서리 늑대 투구', '늑대 귀가 달린 하얀 털 투구'),
        (EquipBase.frostBody, '서리 털가죽 갑옷', '서리가 내려앉은 하얀 털가죽 갑옷'),
        (EquipBase.frostHands, '서리 발톱 장갑', '얼음 발톱이 달린 털장갑'),
        (EquipBase.frostFeet, '눈길 장화', '눈 위에서도 미끄러지지 않는 털 장화'),
        (EquipBase.frostAcc, '서리 송곳니 목걸이', '얼음 송곳니를 꿴 목걸이'),
      ],
    ),
    BossSetInfo(
      id: BossSet.grove,
      name: '고목 세트',
      boss: MonsterId.ancientTreant,
      element: Element.earth,
      material: MaterialId.bossTreantHeart,
      ability: BossSetAbility.regrow,
      abilityName: '천 년의 숨',
      abilityText: '싸우는 동안 HP가 조금씩 차요',
      look: '숲의 수호자',
      lookText: '이끼와 작은 잎이 돋은 나무껍질 차림, 발밑에 새싹',
      aura: 0xFF8CC86A,
      parts: [
        (EquipBase.groveWeapon, '고목의 도끼', '고목의 단단한 가지로 자루를 만든 도끼'),
        (EquipBase.groveHead, '이끼 관', '이끼와 작은 버섯이 자란 나무 관'),
        (EquipBase.groveBody, '나무껍질 갑옷', '고목의 껍질을 엮은 갑옷'),
        (EquipBase.groveHands, '뿌리 장갑', '뿌리가 손을 감싸 듯 엮인 장갑'),
        (EquipBase.groveFeet, '뿌리 장화', '땅을 꽉 디디는 뿌리 장화'),
        (EquipBase.groveAcc, '나이테 부적', '천 년 나이테가 새겨진 나무 부적'),
      ],
    ),
    BossSetInfo(
      id: BossSet.night,
      name: '밤날개 세트',
      boss: MonsterId.shadowBatQueen,
      element: Element.dark,
      material: MaterialId.bossQueenWing,
      ability: BossSetAbility.drain,
      abilityName: '여왕의 입맞춤',
      abilityText: '때릴 때 HP를 조금 빨아들여요',
      look: '밤의 여왕',
      lookText: '별무늬 밤날개 망토와 은빛 관을 쓴 모습',
      aura: 0xFF8A5CD6,
      parts: [
        (EquipBase.nightWeapon, '밤날개 단검', '박쥐 날개 모양의 보랏빛 단검'),
        (EquipBase.nightHead, '여왕의 은관', '보라 보석이 박힌 작은 은관'),
        (EquipBase.nightBody, '밤날개 망토', '안쪽에 별밤이 비치는 망토'),
        (EquipBase.nightHands, '그림자 장갑', '그림자처럼 소리 없는 검은 장갑'),
        (EquipBase.nightFeet, '소리 없는 장화', '발소리가 나지 않는 부드러운 장화'),
        (EquipBase.nightAcc, '달빛 목걸이', '초승달 모양 보석 목걸이'),
      ],
    ),
    BossSetInfo(
      id: BossSet.storm,
      name: '천둥 세트',
      boss: MonsterId.thunderGriffin,
      element: Element.thunder,
      material: MaterialId.bossThunderFeather,
      ability: BossSetAbility.chain,
      abilityName: '연쇄 번개',
      abilityText: '가끔 한 번 더 공격해요',
      look: '하늘의 기사',
      lookText: '금빛 깃털 장식과 몸을 두르는 작은 번개',
      aura: 0xFFFFD84A,
      parts: [
        (EquipBase.stormWeapon, '천둥 창', '창끝에 번개가 맺히는 그리폰 창'),
        (EquipBase.stormHead, '그리폰 투구', '그리폰 날개 장식이 달린 금빛 투구'),
        (EquipBase.stormBody, '폭풍 깃털 갑옷', '금빛 깃털을 겹친 가벼운 갑옷'),
        (EquipBase.stormHands, '번개 장갑', '손등에 번개 무늬가 새겨진 장갑'),
        (EquipBase.stormFeet, '바람 발톱 장화', '그리폰 발톱처럼 끝이 휜 장화'),
        (EquipBase.stormAcc, '천둥 깃털 장식', '천둥 깃털을 꽂은 금 장식'),
      ],
    ),
  ];

  /// 「잿빛 왕의 유품」 (묶음 34): 대장간에서 만들 수 없다. 분신 다섯과 본체가 한 부위씩.
  /// 부위 순서는 다른 세트와 같다 (무기·머리·몸·장갑·신발·장신구)
  static const BossSetInfo relicSet = BossSetInfo(
    id: BossSet.ash,
    name: '잿빛 왕의 유품',
    boss: MonsterId.ashKing,
    element: Element.dark,
    material: MaterialId.bossShard,
    ability: BossSetAbility.ashBane,
    abilityName: '왕의 기억',
    abilityText: '잿빛 몬스터에게 주는 피해가 늘고 받는 피해가 줄어요',
    look: '잿빛 왕',
    lookText: '금 간 왕관과 잿빛 망토, 발밑에 흩날리는 잿가루',
    aura: 0xFFB9B2C9,
    parts: [
      (EquipBase.ashWeapon, '분노의 잿불검', '잿불이 금처럼 번진 왕의 검'),
      (EquipBase.ashCrown, '금 간 왕관', '잿빛 군주가 쓰던 금이 간 왕관'),
      (EquipBase.ashBody, '탐욕의 잿금 갑옷', '빛을 움켜쥐려던 잿금빛 갑옷'),
      (EquipBase.ashHands, '슬픔의 잿비 장갑', '눈물 자국처럼 잿비가 스민 장갑'),
      (EquipBase.ashFeet, '외로움의 잿바람 장화', '홀로 걷던 잿바람이 감도는 장화'),
      (EquipBase.ashAcc, '두려움의 잿그림자 목걸이', '그림자가 고인 잿빛 보석 목걸이'),
    ],
  );

  /// 「하이랜드 수호 기사」 (묶음 50 #146): 대장간 보스 장비 탭. 부위마다 하늘 돌 조각 + 그 부위 결정
  static const BossSetInfo skySet = BossSetInfo(
    id: BossSet.sky,
    name: '하이랜드 수호 기사',
    boss: MonsterId.guardWind,
    element: Element.wind,
    material: MaterialId.skyStone,
    ability: BossSetAbility.skyKnight,
    abilityName: '돌아온 왕의 기사',
    abilityText: '하늘에 뜬 섬이 조금 더 오래 머물러요',
    look: '돌아온 왕의 기사',
    lookText: '등 뒤로 빛나는 날개 망토가 펼쳐진 모습',
    aura: 0xFFDDF3FF,
    parts: [
      (EquipBase.skyWeapon, '뇌운 기사검', '날개 장식 칼자루에 뇌운 핵을 박은 기사검'),
      (EquipBase.skyHead, '햇살 날개 투구', '이마에 햇살 이슬이 빛나는 날개 투구'),
      (EquipBase.skyBody, '서리 수호 갑옷', '서리 결정을 두른 하늘빛 망토 갑옷'),
      (EquipBase.skyHands, '폭포 진주 건틀릿', '손등에 폭포 진주를 박은 하얀 건틀릿'),
      (EquipBase.skyFeet, '구름 걸음 장화', '걸을 때마다 구름 결이 감도는 날개 장화'),
      (EquipBase.skyAcc, '다섯 섬의 목걸이', '다섯 섬의 결정을 하나씩 단 날개 목걸이'),
    ],
  );

  /// 「동행」 (묶음 56 #236): 대장간 보스 장비 탭. 부위마다 파티 보스 재료 + 금화
  static const BossSetInfo partySet = BossSetInfo(
    id: BossSet.party,
    name: '동행 세트',
    boss: MonsterId.partyGolem,
    element: Element.light,
    material: MaterialId.golemCore,
    ability: BossSetAbility.companion,
    abilityName: '함께 걷는 길',
    abilityText: '파티 보스에게 주는 피해가 더 커져요',
    look: '함께 걷는 이',
    lookText: '네 가지 보스 재료가 어깨 망토에서 빛나는 모습',
    aura: 0xFFFFE3B0,
    parts: [
      (EquipBase.partyWeapon, '동행의 깃발창', '파티 깃발을 매단 창, 네 보스의 재료로 벼림'),
      (EquipBase.partyHead, '골렘돌 투구', '이마에 골렘의 심장돌을 박은 투구'),
      (EquipBase.partyBody, '진주 비늘 갑옷', '크라켄 진주와 골렘돌로 엮은 갑옷'),
      (EquipBase.partyHands, '비늘 발톱 장갑', '히드라 비늘에 와이번 발톱을 단 장갑'),
      (EquipBase.partyFeet, '바람 발톱 장화', '와이번 발톱 장식이 달린 가벼운 장화'),
      (EquipBase.partyAcc, '네 빛의 목걸이', '보스 재료 넷을 하나씩 꿴 목걸이'),
    ],
  );

  /// 만들 수 있는 보스 세트 + 유품 세트 + 하이랜드 세트 + 동행 세트
  static const List<BossSetInfo> allSets = [...sets, relicSet, skySet, partySet];

  /// 부위 하나를 만드는 데 드는 재료와 금화 (하이랜드 세트는 부위마다 결정이 다르다)
  static ({Map<MaterialId, int> mats, int gold}) partCost(EquipBase base,
      {bool blacksmith = false}) {
    final slot = EquipmentRules.info(base).slot;
    if (setOf(base) == BossSet.sky) {
      final c = HighlandRules.partCost(slot);
      return (mats: c.mats, gold: blacksmith ? (c.gold * 0.7).round() : c.gold);
    }
    if (setOf(base) == BossSet.party) {
      final i = _slots.indexOf(slot);
      return (mats: PartyRules.partCost(i), gold: PartyRules.partGold(i));
    }
    final set = info(setOf(base) ?? BossSet.warden);
    final c = cost(slot, blacksmith: blacksmith);
    return (
      mats: {MaterialId.bossShard: c.shards, set.material: c.mats},
      gold: c.gold,
    );
  }

  /// 실패하면 잃는 조각 (보스 장비 조각 · 하이랜드는 하늘 돌 조각)
  static MaterialId shardOf(EquipBase base) => switch (setOf(base)) {
        BossSet.sky => MaterialId.skyStone,
        // 동행 세트: 그 부위에 드는 첫 보스 재료
        BossSet.party =>
          PartyRules.partCost(_slots.indexOf(EquipmentRules.info(base).slot)).keys.first,
        _ => MaterialId.bossShard,
      };

  static BossSetInfo info(BossSet s) => allSets.firstWhere((x) => x.id == s);

  /// 이 장비가 속한 세트 (일반 장비면 null)
  static BossSet? setOf(EquipBase base) {
    for (final s in allSets) {
      for (final p in s.parts) {
        if (p.$1 == base) return s.id;
      }
    }
    return null;
  }

  static const _slots = [
    EquipSlot.weapon,
    EquipSlot.head,
    EquipSlot.body,
    EquipSlot.hands,
    EquipSlot.feet,
    EquipSlot.accessory,
  ];

  // ───────────── 힘 (같은 부위 가장 좋은 일반 장비보다 조금 위, 차이는 세트 효과에서)

  static ({double attack, double reduce, double maxHp}) baseStat(EquipSlot s) =>
      switch (s) {
        EquipSlot.weapon => (attack: 0.12, reduce: 0.0, maxHp: 0.0), // 묶음 19: 도끼(+10%)보다 조금 위
        EquipSlot.head => (attack: 0.0, reduce: 0.035, maxHp: 0.0),
        EquipSlot.body => (attack: 0.0, reduce: 0.08, maxHp: 0.0),
        EquipSlot.hands => (attack: 0.0, reduce: 0.025, maxHp: 0.0),
        EquipSlot.feet => (attack: 0.0, reduce: 0.025, maxHp: 0.0),
        EquipSlot.accessory => (attack: 0.0, reduce: 0.0, maxHp: 0.09),
      };

  /// EquipmentRules 에 넣는 36부위
  static final List<EquipBaseInfo> infos = [
    for (final s in allSets)
      for (var i = 0; i < 6; i++)
        EquipBaseInfo(
          id: s.parts[i].$1,
          name: s.parts[i].$2,
          slot: _slots[i],
          recipe: const {},
          attack: baseStat(_slots[i]).attack,
          reduce: baseStat(_slots[i]).reduce,
          maxHp: baseStat(_slots[i]).maxHp,
          asset: _tempArt[s.parts[i].$1] ?? 'equip_${s.parts[i].$1.name}',
        ),
  ];

  /// 그림이 오기 전 잠시 쓰는 그림 (묶음 56 「동행」 세트 — 같은 이름 그림이 오면 지움)
  static const Map<EquipBase, String> _tempArt = {
    EquipBase.partyWeapon: 'equip_spear',
    EquipBase.partyHead: 'equip_cap',
    EquipBase.partyBody: 'equip_armor',
    EquipBase.partyHands: 'equip_gloves',
    EquipBase.partyFeet: 'equip_boots',
    EquipBase.partyAcc: 'equip_stone_charm',
  };

  // ───────────── 만들기 (대장간 NPC, 숫자는 제안값)

  /// 보스 장비 조각 · 전용 재료 · 금화. 무기가 가장 많이 든다.
  static ({int shards, int mats, int gold}) cost(EquipSlot s,
      {bool blacksmith = false}) {
    final c = switch (s) {
      EquipSlot.weapon => (shards: 6, mats: 2, gold: 800),
      EquipSlot.body => (shards: 5, mats: 2, gold: 600),
      EquipSlot.head => (shards: 3, mats: 1, gold: 400),
      EquipSlot.accessory => (shards: 3, mats: 1, gold: 400),
      EquipSlot.hands => (shards: 2, mats: 1, gold: 300),
      EquipSlot.feet => (shards: 2, mats: 1, gold: 300),
    };
    if (!blacksmith) return c;
    // 대장장이 직업 (#55 각성 뒤): 금화 30% 싸게
    return (shards: c.shards, mats: c.mats, gold: (c.gold * 0.7).round());
  }

  /// 실패 확률 (숨김). 대장장이 직업은 절반.
  static double failChance({bool blacksmith = false}) => blacksmith ? 0.10 : 0.20;

  /// 실패하면 잃는 것: 금화 절반, 조각 3분의 1 (적어도 1개). 전용 재료는 돌려받는다.
  static ({int shards, int gold}) failLoss(EquipSlot s, {bool blacksmith = false}) {
    final c = cost(s, blacksmith: blacksmith);
    return (shards: math.max(1, c.shards ~/ 3), gold: c.gold ~/ 2);
  }

  static const List<String> failLines = [
    '불길이 고르지 못했어요. 조각 하나가 녹아 버렸어요.',
    '망치질이 어긋났어요. 조각 몇 개가 부서졌어요. 보스 재료는 돌려드릴게요.',
    '담금질이 빨랐어요. 조각이 갈라져 버렸어요. 보스 재료는 무사해요.',
  ];

  // ───────────── 세트 효과 (2·4·6개, 숨김)

  /// 2개: 그 보스 속성 저항
  static const double setResist = 0.15;

  /// 4개: 그 보스 속성으로 공격할 때 피해 증가
  static const double setAttack = 0.15;

  /// 6개 고유 능력의 세기 (숨김)
  static const double stoneSkinChance = 0.15;
  static const double burnChance = 0.20;
  static const double freezeChance = 0.12;
  static const double regrowRatio = 0.02;
  static const double drainRatio = 0.10;
  static const double chainChance = 0.15;

  /// 입은 장비에서 세트별 개수 (장비 속성을 바꿔도 세트는 그대로)
  static Map<BossSet, int> counts(Iterable<EquipItem> worn) {
    final m = <BossSet, int>{};
    for (final it in worn) {
      final s = setOf(it.base);
      if (s != null) m[s] = (m[s] ?? 0) + 1;
    }
    return m;
  }

  static const List<int> steps = [2, 4, 6];
}

/// 입은 보스 장비의 세트 효과 (전투에 넘긴다)
class SetBonus {
  const SetBonus({
    this.resist = const {},
    this.attack = const {},
    this.abilities = const {},
    this.look,
    this.ashDealt = 0,
    this.ashTaken = 0,
    this.skyTaken = 0,
    this.skyFeather = false,
    this.guardFlash = 0,
    this.petFaster = 0,
    this.partyBoss = 0,
    this.togetherExp = 0,
  });

  /// 묶음 56: 「동행」 — 파티 보스에게 주는 피해 · 함께 있을 때 사냥 경험치 (숨김)
  final double partyBoss;
  final double togetherExp;

  /// 묶음 53: 볼크의 금 간 투구 — 막을 때 적이 멈출 확률 (숨김)
  final double guardFlash;

  /// 묶음 53: 바람의 은빛 목걸이 — 펫 게이지가 이만큼 빨리 참 (틱)
  final int petFaster;

  /// 하이랜드 수호 기사 (묶음 50): 4개 — 하늘 속성 공격에 받는 피해 감소 (숨김)
  final double skyTaken;

  /// 2개: 걸을 때 하늘 깃털이 조금 더 잘 모임
  final bool skyFeather;

  /// 잿빛 왕의 유품 (묶음 34): 잿빛 몬스터에게 주는 피해 증가 · 받는 피해 감소 (숨김)
  final double ashDealt;
  final double ashTaken;

  /// 2개: 속성 저항 (배율)
  final Map<Element, double> resist;

  /// 4개: 그 속성 공격 피해 증가 (배율)
  final Map<Element, double> attack;

  /// 6개: 고유 능력
  final Set<BossSetAbility> abilities;

  /// 6개를 다 입은 세트 (외형 빛)
  final BossSet? look;

  static const none = SetBonus();

  static SetBonus of(Iterable<EquipItem> worn) {
    final c = BossGearRules.counts(worn);
    final resist = <Element, double>{};
    final attack = <Element, double>{};
    final ab = <BossSetAbility>{};
    BossSet? look;
    var ashDealt = 0.0;
    var ashTaken = 0.0;
    var skyTaken = 0.0;
    var skyFeather = false;
    // 묶음 53 #243: 「발드린 문지기」 일반 세트 · 지역 1 이름 있는 장비 (숨김)
    var baldrin = 0;
    var guardFlash = 0.0;
    var petFaster = 0;
    var partyBoss = 0.0;
    var togetherExp = 0.0;
    for (final it in worn) {
      switch (it.base) {
        case EquipBase.baldrinWeapon ||
              EquipBase.baldrinHead ||
              EquipBase.baldrinBody ||
              EquipBase.baldrinHands ||
              EquipBase.baldrinFeet ||
              EquipBase.baldrinAcc:
          baldrin++;
        case EquipBase.uniqVolkHelm:
          guardFlash = BaldrinRules.volkFlash;
        case EquipBase.uniqTeoSpear:
          ashDealt += BaldrinRules.teoAsh;
        case EquipBase.uniqWindPendant:
          petFaster = BaldrinRules.windFaster;
        default:
          break;
      }
    }
    if (baldrin >= 6) {
      ashTaken += BaldrinRules.set6Taken;
      ashDealt += BaldrinRules.set6Dealt;
    } else {
      if (baldrin >= 2) ashTaken += BaldrinRules.set2Taken;
      if (baldrin >= 4) ashDealt += BaldrinRules.set4Dealt;
    }
    c.forEach((s, n) {
      final info = BossGearRules.info(s);
      if (s == BossSet.sky) {
        // 2개 깃털 · 4개 하늘 속성 피해 ↓ · 6개 모습 + 섬이 더 오래
        if (n >= 2) skyFeather = true;
        if (n >= 4) skyTaken = HighlandRules.setTaken4;
        if (n >= 6) {
          ab.add(info.ability);
          look = s;
        }
        return;
      }
      if (s == BossSet.party) {
        // 2개 파티 보스 피해 · 4개 함께 있을 때 경험치 · 6개 파티 보스 피해 더 + 모습
        if (n >= 2) partyBoss = PartyRules.set2Boss;
        if (n >= 4) togetherExp = PartyRules.set4Together;
        if (n >= 6) {
          partyBoss = PartyRules.set6Boss;
          ab.add(info.ability);
          look = s;
        }
        return;
      }
      if (s == BossSet.ash) {
        // 2개 받는 피해 ↓ · 4개 주는 피해 ↑ · 6개 둘 다 더
        if (n >= 2) ashTaken += Act2Rules.setTaken2;
        if (n >= 4) ashDealt += Act2Rules.setDealt4;
        if (n >= 6) {
          ashTaken += Act2Rules.setTaken6 - Act2Rules.setTaken2;
          ashDealt += Act2Rules.setDealt6 - Act2Rules.setDealt4;
          ab.add(info.ability);
          look = s;
        }
        return;
      }
      if (n >= 2) resist[info.element] = BossGearRules.setResist;
      if (n >= 4) attack[info.element] = BossGearRules.setAttack;
      if (n >= 6) {
        ab.add(info.ability);
        look = s;
      }
    });
    return SetBonus(
        resist: resist,
        attack: attack,
        abilities: ab,
        look: look,
        ashDealt: ashDealt,
        ashTaken: ashTaken,
        skyTaken: skyTaken,
        skyFeather: skyFeather,
        guardFlash: guardFlash,
        petFaster: petFaster,
        partyBoss: partyBoss,
        togetherExp: togetherExp);
  }
}
