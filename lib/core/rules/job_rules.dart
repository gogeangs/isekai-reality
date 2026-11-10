import 'element_rules.dart';

/// 직업 전용 규칙 (11-11 #74). 직업 각성(#55)이 생기기 전에는 데이터만 있고
/// 화면에는 「직업 각성 뒤 열림」으로 잠가 둔다.

/// 연금술사 숙련도 단계
enum AlchemistRank { apprentice, skilled, artisan, master }

extension AlchemistRankInfo on AlchemistRank {
  String get label => switch (this) {
        AlchemistRank.apprentice => '견습',
        AlchemistRank.skilled => '숙련',
        AlchemistRank.artisan => '장인',
        AlchemistRank.master => '대가',
      };

  /// 이 단계에 필요한 숙련도 점수
  int get need => switch (this) {
        AlchemistRank.apprentice => 0,
        AlchemistRank.skilled => 100,
        AlchemistRank.artisan => 400,
        AlchemistRank.master => 1000,
      };

  /// 품질 점수 보너스
  int get qualityBonus => switch (this) {
        AlchemistRank.apprentice => 0,
        AlchemistRank.skilled => 1,
        AlchemistRank.artisan => 1,
        AlchemistRank.master => 2,
      };

  /// 끓는 시간 배율
  double get brewTime => switch (this) {
        AlchemistRank.apprentice || AlchemistRank.skilled => 1,
        AlchemistRank.artisan => 0.8,
        AlchemistRank.master => 0.6,
      };
}

/// 연금술사 전용 능력
enum AlchemistAbility { recipeSave, twoBottles, throwPotion, threeBottles, masterPotions }

class AlchemistAbilityInfo {
  const AlchemistAbilityInfo(this.id, this.label, this.level, this.rank);

  final AlchemistAbility id;
  final String label;

  /// 열리는 캐릭터 레벨
  final int level;
  final AlchemistRank rank;
}

class AlchemistRules {
  AlchemistRules._();

  /// 숙련도 점수: 물약 끓이기 3, 변환·정제 1, 최상 품질 +2
  static const int brewPoints = 3;
  static const int convertPoints = 1;
  static const int bestBonusPoints = 2;

  /// 물약 투척: 전투 한 번에 1번, 속성 피해 ×2 + 상태 이상
  static const int throwsPerBattle = 1;
  static const double throwMultiplier = 2;

  /// 대가 물약
  static const double reviveHp = 0.5; // 부활 물약: 쓰러지면 HP 50%로 한 번
  static const double expElixir = 1.5; // 경험의 영약: 30분 경험치 ×1.5
  static const Duration expElixirTime = Duration(minutes: 30);

  /// 호문쿨루스 연결: 데리고 다니면 끓기·변환 시간 -20%.
  /// 속성 마석을 먹이면 속성이 생기고, 바꾸려면 다른 속성 마석 3개.
  static const double homunculusTime = 0.8;
  static const int homunculusChangeStones = 3;

  static const List<AlchemistAbilityInfo> abilities = [
    AlchemistAbilityInfo(AlchemistAbility.recipeSave, '순서 기록·레시피 저장', 15,
        AlchemistRank.apprentice),
    AlchemistAbilityInfo(
        AlchemistAbility.twoBottles, '한 번에 2병', 20, AlchemistRank.skilled),
    AlchemistAbilityInfo(AlchemistAbility.throwPotion, '전투에서 물약 투척', 25,
        AlchemistRank.skilled),
    AlchemistAbilityInfo(
        AlchemistAbility.threeBottles, '한 번에 3병', 30, AlchemistRank.artisan),
    AlchemistAbilityInfo(AlchemistAbility.masterPotions,
        '대가 물약 (부활 물약 · 경험의 영약)', 40, AlchemistRank.master),
  ];

  static AlchemistRank rankOf(int points) {
    var r = AlchemistRank.apprentice;
    for (final x in AlchemistRank.values) {
      if (points >= x.need) r = x;
    }
    return r;
  }

  /// 호문쿨루스에게 속성 마석을 먹였을 때 생기는 속성 (바꾸려면 3개)
  static Element? homunculusElement(Element? now, Element fed, int count) {
    if (now == null) return count >= 1 ? fed : null;
    if (now == fed) return now;
    return count >= homunculusChangeStones ? fed : now;
  }
}

/// 대장간 장비 속성 작업 (11-11 #74, 확정본)
enum SmithAction { apply, change, extract, upgrade }

extension SmithActionLabel on SmithAction {
  String get label => switch (this) {
        SmithAction.apply => '속성 입히기',
        SmithAction.change => '속성 바꾸기',
        SmithAction.extract => '속성 추출',
        SmithAction.upgrade => '속성 강화',
      };
}

class SmithRules {
  SmithRules._();

  /// 속성 강화 최대 단계 (1단계 = 입힌 상태, 강화 0~3)
  static const int maxLevel = 3;

  /// 금화 (NPC 도르군). 대장장이 직업은 절반.
  static int gold(SmithAction a, {bool blacksmith = false}) {
    final g = switch (a) {
      SmithAction.apply => 100,
      SmithAction.change => 150,
      SmithAction.extract => 80,
      SmithAction.upgrade => 200,
    };
    return blacksmith ? g ~/ 2 : g;
  }

  /// 들어가는 빛나는 속성 코어 (추출은 돌려받는다)
  static int cores(SmithAction a) => switch (a) {
        SmithAction.apply || SmithAction.change => 1,
        SmithAction.extract => 0,
        SmithAction.upgrade => 2,
      };

  /// 실패 확률 (숨김). [level] 은 지금 강화 단계 (0~2). 대장장이 직업은 절반.
  static double failChance(SmithAction a, {int level = 0, bool blacksmith = false}) {
    final f = switch (a) {
      SmithAction.apply || SmithAction.change => 0.25,
      SmithAction.extract => 0.0,
      SmithAction.upgrade => switch (level) {
          0 => 0.30,
          1 => 0.45,
          _ => 0.60,
        },
    };
    return blacksmith ? f / 2 : f;
  }

  /// 공격 속성의 강함 배율 (강화 단계마다 +0.1, 숨김)
  static double strongAt(int level) => ElementRules.strong + 0.1 * level;

  /// 방어 속성의 받는 피해 배율 (강화 단계마다 -0.05, 숨김)
  static double guardAt(int level) => ElementRules.guard - 0.05 * level;

  static const String failLine = '망치질이 빗나갔어요. 코어는 돌려드릴게요.';
}
