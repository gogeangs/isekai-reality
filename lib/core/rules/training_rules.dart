import 'dart:math' as math;

import 'battle_rules.dart';
import 'element_rules.dart';
import 'materials.dart';
import 'monsters.dart';

/// 허수아비 연습 종류 (보통 · 단단한 · 속성)
enum DummyKind { normal, hard, element }

/// 마을 새 건물 「훈련장」 (묶음 43 #228). 수치는 숨은 값(처음 값, 테스트로 조정).
/// 경험치는 어디에서도 주지 않는다 — 걷기가 중심
class TrainingRules {
  TrainingRules._();

  /// 열리는 레벨 (#225 공사 중 규칙: Lv.10 터 닦기 · 11 뼈대 · 12 거의 완성)
  static const int openLevel = 13;

  // ───────────── 연습

  /// 연습 허수아비 (쓰러지지 않고, 때리지 않는다)
  static Foe practiceFoe(DummyKind k, int level, {Element? element}) {
    final base = BattleRules.fieldFoe(level: level, monster: monsterOf(k));
    return Foe(
      monster: monsterOf(k),
      maxHp: base.maxHp,
      attack: 1,
      defense: k == DummyKind.hard ? hardDefense : 1,
      speed: 0.5,
      forceElement: k == DummyKind.element ? (element ?? Element.fire) : null,
    );
  }

  static MonsterId monsterOf(DummyKind k) => switch (k) {
        DummyKind.normal => MonsterId.dummy,
        DummyKind.hard => MonsterId.dummyHard,
        DummyKind.element => MonsterId.dummyElement,
      };

  static String dummyName(DummyKind k) => switch (k) {
        DummyKind.normal => '보통 허수아비',
        DummyKind.hard => '단단한 허수아비',
        DummyKind.element => '속성 허수아비',
      };

  static String dummyText(DummyKind k) => switch (k) {
        DummyKind.normal => '마음껏 때려 보는 허수아비',
        DummyKind.hard => '갑옷을 입어 방어가 높아요',
        DummyKind.element => '속성을 골라 상성을 시험해요',
      };

  /// 단단한 허수아비 방어 배수
  static const double hardDefense = 2.2;

  // ───────────── 하루 훈련 (하루 1번 · 3판)

  /// 허수아비 → 훈련 골렘 → 교관의 시험 (강함은 내 레벨의 필드 몬스터 기준)
  static List<Foe> dailyFoes(int level) => [
        _scaled(MonsterId.dummy, level, hp: 0.9, atk: 0.7),
        _scaled(MonsterId.trainingGolem, level, hp: 1.2, atk: 1.0),
        _scaled(MonsterId.trainingGolem, level, hp: 1.8, atk: 1.3),
      ];

  static const List<String> dailyNames = ['허수아비', '훈련 골렘', '교관의 시험'];

  /// 판마다 금화 (넘긴 판까지 더함)
  static const List<int> dailyGold = [15, 20, 35];

  /// 판마다 전투 숙련도
  static const double dailyMastery = 1;

  /// 세 판 다 넘기면 가끔 재료
  static const double dailyMatChance = 0.4;
  static const List<MaterialId> dailyMats = [
    MaterialId.ironShard,
    MaterialId.twig,
    MaterialId.toughHide,
    MaterialId.smallHorn,
    MaterialId.herb,
  ];

  /// 가렌과 단짝이면 하루 훈련 금화 더 (숨은 값)
  static const double garenGold = 1.25;

  // ───────────── 펫 훈련 (하루 1번 · 8시간)

  static const Duration petTime = Duration(hours: 8);

  /// 펫 경험치 (간식 한 번의 1.5배쯤)
  static const int petExp = 60;

  // ───────────── 시련 (매주 월요일 새로 · 하루 1번)

  /// 한 번에 준비하는 판 수 (사실상 끝없음)
  static const int trialFloors = 60;

  /// 판이 갈수록: 체력 +10% · 공격 +7%씩
  static const double trialHpStep = 0.10;
  static const double trialAtkStep = 0.07;

  /// n번째 판(1부터): 5판마다 훈련 골렘, 그 사이는 허수아비 · 단단한 허수아비
  static Foe trialFoe(int level, int n) {
    final hp = 1 + trialHpStep * (n - 1);
    final atk = 1 + trialAtkStep * (n - 1);
    if (n % 5 == 0) {
      return _scaled(MonsterId.trainingGolem, level, hp: hp * 1.4, atk: atk * 1.2);
    }
    if (n.isEven) {
      final f = _scaled(MonsterId.dummyHard, level, hp: hp, atk: atk);
      return Foe(
          monster: f.monster,
          maxHp: f.maxHp,
          attack: f.attack,
          defense: 1.4,
          speed: f.speed);
    }
    return _scaled(MonsterId.dummy, level, hp: hp, atk: atk);
  }

  static List<Foe> trialFoes(int level) =>
      [for (var n = 1; n <= trialFloors; n++) trialFoe(level, n)];

  /// 이번 주 처음 넘기면 받는 판
  static const List<int> trialMarks = [5, 10, 15];

  /// 그 판을 처음 넘길 때 주간 보상 (우편 선물과 같은 키)
  static Map<String, int> trialReward(int mark) => switch (mark) {
        5 => const {'manaStone': 3, 'ironShard': 3},
        10 => const {'manaStone': 5, 'ironIngot': 1},
        _ => const {'manaStone': 8, 'labyrinthStone': 2},
      };

  /// 처음 넘기면 칭호 「시련을 견딘 자」
  static const int trialTitleAt = 15;

  static Foe _scaled(MonsterId m, int level,
      {required double hp, required double atk}) {
    final b = BattleRules.fieldFoe(level: level, monster: m);
    return Foe(
      monster: m,
      maxHp: math.max(1, (b.maxHp * hp).round()),
      attack: math.max(1, (b.attack * atk).round()),
      defense: b.defense,
      speed: b.speed,
    );
  }

  // ───────────── 문구 (개발 초안)

  /// 「새로 열렸어요」 카드
  static const String openedLine = '훈련장이 열렸어! 가렌 교관이 기다리고 있대.';

  /// 탭 안내 (가렌)
  static String tabGuide(int tab) => switch (tab) {
        0 => '허수아비는 얼마든지 때려도 된다! 다치지도 닳지도 않으니 마음껏 연습해라!',
        1 => '하루 한 번, 세 판이다! 마지막은 내가 직접 고른 시험이다!',
        2 => '펫도 몸을 단련해야 한다! 여덟 시간 뒤에 데려가라!',
        _ => '시련은 끝이 없다! 쓰러질 때까지 버텨 봐라! 기록은 월요일에 새로 센다!',
      };

  /// 하루 훈련을 오늘 이미 했을 때
  static const String dailyDone = '오늘 훈련은 끝났다! 푹 쉬고 내일 또 와라!';

  /// 시련을 오늘 이미 했을 때
  static const String trialDone = '오늘 시련은 끝났다! 내일 다시 도전해라!';
}
