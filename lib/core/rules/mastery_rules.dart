import 'dart:math' as math;

import '../format.dart';
import '../models/daily_record.dart';
import 'alchemy_rules.dart';
import 'equipment_rules.dart';
import 'harvest_rules.dart';
import 'monsters.dart';
import 'title_rules.dart';

/// 숨은 숙련도 (묶음 27 #176).
///
/// 같은 일을 되풀이할수록 그 일에 익숙해진다. 숫자·막대는 보이지 않고
/// 정령 대사·칭호로만 느낀다. 한 번 오른 숙련도는 줄지 않는다.
/// 효과는 작고(숨은 규칙) 단계마다 장인 기준 최대값을 나눠 준다.
enum Mastery { smith, harvest, alchemy, combat, walk, appraise, spirit, trade }

extension MasteryLabel on Mastery {
  String get label => switch (this) {
        Mastery.smith => '대장일',
        Mastery.harvest => '채집',
        Mastery.alchemy => '연금술',
        Mastery.combat => '전투',
        Mastery.walk => '걷기·탐험',
        Mastery.appraise => '감정',
        Mastery.spirit => '정령술',
        Mastery.trade => '장사·의뢰',
      };
}

/// 단계: 서툰 → 익숙한 → 능숙한 → 숙련된 → 장인
enum MasteryStage { clumsy, familiar, skilled, expert, master }

class MasteryRules {
  MasteryRules._();

  // ───────────── 쌓이는 양 (행동 한 번에)
  static const double craft = 1, enhance = 1, repair = 1;
  static const double harvestOnce = 1;
  static const double brew = 1;
  static const double fieldWin = 1, dungeonClear = 3;
  static const double stepsPerPoint = 1000, newPlace = 3, revisit = 1;
  static const double appraiseOnce = 1;
  static const double expeditionWin = 1, expeditionLoss = 0.5;
  static const double tradeOnce = 1, errandDone = 2;

  // ───────────── 단계 기준 (숨은 규칙, 처음 값)
  static const List<double> bigSteps = [0, 10, 40, 120, 300];
  static const List<double> detailSteps = [0, 5, 20, 60, 150];

  static MasteryStage stageOf(double v, {bool detail = false}) {
    final s = detail ? detailSteps : bigSteps;
    var i = 0;
    while (i + 1 < s.length && v >= s[i + 1]) {
      i++;
    }
    return MasteryStage.values[i];
  }

  /// 효과 비율: 서툰 0 · 익숙한 ¼ · 능숙한 ½ · 숙련된 ¾ · 장인 1
  static double fraction(double v, {bool detail = false}) =>
      stageOf(v, detail: detail).index / (MasteryStage.values.length - 1);

  // ───────────── 효과 (장인 기준 최대값)
  static const double weaponDamage = 0.05;
  static const double monsterDamage = 0.05;
  static const double monsterExtraLoot = 0.10;
  static const double smithBluePoints = 10; // 좋은 등급(파랑) +%p
  static const double smithRepairCut = 0.20;
  static const double harvestExtra = 0.15;
  static const double harvestToolSave = 0.15;
  static const double brewExtra = 0.15;
  static const double brewSave = 0.10;
  static const double walkGauge = 0.05;
  static const double walkPlaceExp = 0.20;
  static const double appraiseBonus = 0.5; // 재료·쪽지 확률 ×1.5까지
  static const double spiritMpCut = 0.10;
  static const double spiritTimeCut = 0.10;
  static const double tradeGold = 0.05;
  static const double errandGold = 0.05;

  // ───────────── 세부 숙련도 열쇠
  /// 무기 종류 (보스 무기는 가장 가까운 종류)
  static String? weaponKind(EquipBase? base) => switch (base) {
        EquipBase.dagger ||
        EquipBase.hornDagger ||
        EquipBase.nightWeapon =>
          'dagger',
        EquipBase.staff || EquipBase.flameWeapon => 'staff',
        EquipBase.ironSword ||
        EquipBase.wardenWeapon ||
        EquipBase.frostWeapon =>
          'sword',
        EquipBase.woodAxe || EquipBase.groveWeapon => 'axe',
        EquipBase.ironSpear || EquipBase.stormWeapon => 'spear',
        null => null,
        _ => EquipmentRules.info(base).slot == EquipSlot.weapon
            ? base.name
            : null,
      };

  static const Map<String, String> weaponLabels = {
    'sword': '검',
    'axe': '도끼',
    'dagger': '단검',
    'spear': '창',
    'staff': '지팡이',
  };

  /// 대장일 세부: 무기는 무기 종류, 방어구는 부위
  static String smithKind(EquipBase base) {
    final slot = EquipmentRules.info(base).slot;
    if (slot == EquipSlot.weapon) return weaponKind(base) ?? base.name;
    return slot.name;
  }

  static String smithKindLabel(String kind) =>
      weaponLabels[kind] ??
      switch (kind) {
        'head' => '투구',
        'body' => '갑옷',
        'hands' => '장갑',
        'feet' => '신발',
        'accessory' => '장신구',
        _ => '장비',
      };

  /// 채집 세부: 꽃·버섯은 약초, 보석은 광석. 물가·유물은 큰 숙련도만
  static String? harvestKind(HarvestKind k) => switch (k) {
        HarvestKind.herb ||
        HarvestKind.flower ||
        HarvestKind.mushroom =>
          'herb',
        HarvestKind.ore || HarvestKind.gem => 'ore',
        HarvestKind.wood => 'wood',
        HarvestKind.water || HarvestKind.relic => null,
      };

  static const Map<String, String> harvestLabels = {
    'herb': '약초',
    'ore': '광석',
    'wood': '나무',
  };

  static String smithKey(String kind) => 'smith:$kind';
  static String weaponKey(String kind) => 'weapon:$kind';
  static String monsterKey(MonsterId m) => 'monster:${m.name}';
  static String harvestKey(String kind) => 'harvest:$kind';
  static String potionKey(PotionId p) => 'potion:${p.name}';

  /// 세부 열쇠가 어느 큰 숙련도에 속하는지
  static Mastery? bigOf(String detailKey) =>
      switch (detailKey.split(':').first) {
        'smith' => Mastery.smith,
        'weapon' || 'monster' => Mastery.combat,
        'harvest' => Mastery.harvest,
        'potion' => Mastery.alchemy,
        _ => null,
      };

  /// 걷기·탐험은 기록에서 바로 센다 (줄지 않는다): 1,000보마다 1, 새 장소 3, 다시 찾기 1
  static double walkFrom(List<DailyRecord> history) {
    var steps = 0, places = 0, again = 0;
    for (final d in history) {
      steps += d.steps;
      places += d.newPlacesVisited;
      again += d.placesRevisited;
    }
    return (steps ~/ stepsPerPoint) + places * newPlace + again * revisit;
  }

  // ───────────── 칭호 (큰 숙련도 숙련된·장인)
  static const Map<Mastery, (TitleId, TitleId)> titles = {
    Mastery.smith: (TitleId.smithAdept, TitleId.smithMaster),
    Mastery.harvest: (TitleId.harvestAdept, TitleId.harvestMaster),
    Mastery.alchemy: (TitleId.alchemyAdept, TitleId.alchemyMaster),
    Mastery.combat: (TitleId.combatAdept, TitleId.combatMaster),
    Mastery.walk: (TitleId.walkAdept, TitleId.walkMaster),
    Mastery.appraise: (TitleId.appraiseAdept, TitleId.appraiseMaster),
    Mastery.spirit: (TitleId.spiritAdept, TitleId.spiritMaster),
    Mastery.trade: (TitleId.tradeAdept, TitleId.tradeMaster),
  };

  /// 그 단계에서 얻는 칭호 (숙련된·장인만)
  static TitleId? titleAt(Mastery m, MasteryStage s) => switch (s) {
        MasteryStage.expert => titles[m]!.$1,
        MasteryStage.master => titles[m]!.$2,
        _ => null,
      };

  // ───────────── 대사 (숫자·% 없음)
  /// 큰 숙련도 단계가 오를 때 한 번 (익숙한·능숙한·숙련된·장인)
  static const Map<Mastery, List<String>> stageLines = {
    Mastery.smith: [
      '망치질이 제법 손에 붙었는데?',
      '불꽃 색만 봐도 쇠가 얼마나 달궈졌는지 알겠어!',
      '네가 만든 장비는 어딘가 달라. 손끝이 야무져!',
      '이제 대장간 모루가 너를 기다리는 것 같아. 진짜 장인이야!',
    ],
    Mastery.harvest: [
      '풀이랑 돌을 고르는 눈이 생겼네!',
      '이제 어디에 좋은 약초가 있는지 보이는 것 같아!',
      '땅이 네 손을 알아보는 것 같아. 캘 때마다 수월해!',
      '숲도 바위도 너한테는 다 보물 창고구나!',
    ],
    Mastery.alchemy: [
      '가마솥 앞에 선 모습이 제법 그럴듯한데?',
      '재료 냄새만 맡아도 어떤 물약이 될지 알겠지?',
      '네가 끓인 물약은 빛깔부터 달라!',
      '이 정도면 왕궁 연금술사도 부러워하겠어!',
    ],
    Mastery.combat: [
      '싸움이 조금 익숙해졌지? 몸이 먼저 움직여!',
      '몬스터 움직임이 눈에 들어오기 시작했어!',
      '이제 웬만한 몬스터는 너를 보면 겁부터 먹을걸?',
      '전장의 바람이 네 편이야. 정말 든든해!',
    ],
    Mastery.walk: [
      '발걸음이 가벼워졌어! 걷는 게 즐겁지?',
      '이 동네 골목은 이제 네 손바닥 안이네!',
      '지도 없이도 길이 보이는 것 같아!',
      '이 동네에서 네가 안 가 본 길이 있을까?',
    ],
    Mastery.appraise: [
      '돋보기를 드는 손이 자연스러워졌어!',
      '사람들 사이에 숨은 이세계 종족이 조금씩 보이지?',
      '네 눈은 웬만한 변장으로는 못 속이겠다!',
      '이제 돋보기 없이도 다 보일 것 같아. 진실의 눈이야!',
    ],
    Mastery.spirit: [
      '원정 보내는 손발이 조금씩 맞아 가!',
      '말 안 해도 어디로 가야 할지 알 것 같아!',
      '나랑 손발이 척척 맞네. 원정이 훨씬 수월해졌어!',
      '우린 이제 마음이 하나야. 어디든 다녀올 수 있어!',
    ],
    Mastery.trade: [
      '흥정하는 말투가 제법이야!',
      '상인들이 너를 반가워하는 것 같아!',
      '길드에서도 네 이름을 알더라. 믿을 만한 해결사래!',
      '장사면 장사, 의뢰면 의뢰. 이 동네 해결사는 너야!',
    ],
  };

  /// 그 단계로 오를 때의 대사 (서툰은 없음)
  static String? stageLine(Mastery m, MasteryStage s) =>
      s == MasteryStage.clumsy ? null : stageLines[m]![s.index - 1];

  /// 세부 숙련도가 장인이 될 때 한마디
  static String? masterLine(String detailKey) {
    final parts = detailKey.split(':');
    if (parts.length != 2) return null;
    final v = parts[1];
    switch (parts[0]) {
      case 'weapon':
        final w = weaponLabels[v] ?? '무기';
        return '이제 ${josa(w, '이/가')} 손에 꼭 맞아!';
      case 'monster':
        final id = Monsters.byName(v);
        if (id == null) return null;
        return '${josa(Monsters.info(id).name, '은/는')} 눈 감고도 잡겠다!';
      case 'smith':
        return '${josa(smithKindLabel(v), '은/는')} 이제 눈 감고도 만들겠어!';
      case 'harvest':
        final h = harvestLabels[v] ?? '재료';
        return '$h 캐는 건 이제 일도 아니야!';
      case 'potion':
        final p = PotionId.values.where((x) => x.name == v).firstOrNull;
        if (p == null) return null;
        return '${AlchemyRules.info(p).name} 끓이는 건 이제 식은 죽 먹기야!';
    }
    return null;
  }

  /// 성향 대사: 가장 높은 큰 숙련도
  static String leanLine(Mastery m) => switch (m) {
        Mastery.smith => '요즘 망치를 자주 드네. 꼭 대장장이 같아!',
        Mastery.harvest => '요즘 채집을 많이 하네. 꼭 약초꾼 같아!',
        Mastery.alchemy => '가마솥 앞에 자주 서네. 연금술사 냄새가 나!',
        Mastery.combat => '요즘 사냥을 많이 하네. 꼭 사냥꾼 같아!',
        Mastery.walk => '정말 많이 걸었어. 꼭 길잡이 같아!',
        Mastery.appraise => '돋보기를 자주 드네. 감정사가 다 됐어!',
        Mastery.spirit => '나를 자주 믿고 보내 줘서 고마워. 우린 좋은 짝이야!',
        Mastery.trade => '장사 수완이 좋은데? 상인이 다 됐네!',
      };

  /// 성향 대사를 섞는 간격
  static const Duration leanEvery = Duration(days: 7);

  /// 성향을 말할 만큼 쌓였는지 (가장 높은 큰 숙련도가 익숙한 이상)
  static bool leanReady(double top) => top >= bigSteps[1];

  /// 예전 기록 무기 세부 시작 값: 사냥 수의 절반쯤
  static double legacyWeaponShare(int hunts) => (hunts / 2).floorToDouble();

  /// 확률 [chance] 를 효과 비율에 맞춰 올린다 (최대 [max]배)
  static double scaled(double chance, double frac, double max) =>
      math.min(1, chance * (1 + max * frac));
}
