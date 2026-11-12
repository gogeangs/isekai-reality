import 'dart:math' as math;

import '../models/armory.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'materials.dart';
import 'monsters.dart';

/// 보스 장비 세트 (11-11 #82). 보스마다 6부위 한 벌.
enum BossSet { warden, flame, frost, grove, night, storm }

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

  static BossSetInfo info(BossSet s) => sets.firstWhere((x) => x.id == s);

  /// 이 장비가 속한 세트 (일반 장비면 null)
  static BossSet? setOf(EquipBase base) {
    for (final s in sets) {
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
        EquipSlot.weapon => (attack: 0.10, reduce: 0.0, maxHp: 0.0),
        EquipSlot.head => (attack: 0.0, reduce: 0.035, maxHp: 0.0),
        EquipSlot.body => (attack: 0.0, reduce: 0.08, maxHp: 0.0),
        EquipSlot.hands => (attack: 0.0, reduce: 0.025, maxHp: 0.0),
        EquipSlot.feet => (attack: 0.0, reduce: 0.025, maxHp: 0.0),
        EquipSlot.accessory => (attack: 0.0, reduce: 0.0, maxHp: 0.09),
      };

  /// EquipmentRules 에 넣는 36부위
  static final List<EquipBaseInfo> infos = [
    for (final s in sets)
      for (var i = 0; i < 6; i++)
        EquipBaseInfo(
          id: s.parts[i].$1,
          name: s.parts[i].$2,
          slot: _slots[i],
          recipe: const {},
          attack: baseStat(_slots[i]).attack,
          reduce: baseStat(_slots[i]).reduce,
          maxHp: baseStat(_slots[i]).maxHp,
          asset: 'equip_${s.parts[i].$1.name}',
        ),
  ];

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
  });

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
    c.forEach((s, n) {
      final info = BossGearRules.info(s);
      if (n >= 2) resist[info.element] = BossGearRules.setResist;
      if (n >= 4) attack[info.element] = BossGearRules.setAttack;
      if (n >= 6) {
        ab.add(info.ability);
        look = s;
      }
    });
    return SetBonus(resist: resist, attack: attack, abilities: ab, look: look);
  }
}
