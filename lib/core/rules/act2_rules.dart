import 'dart:math' as math;

import '../format.dart';
import '../geo/geo.dart';
import 'battle_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'exclusion_index.dart';
import 'exploration_rules.dart';
import 'monsters.dart';
import 'place_grid.dart';
import 'road_mask.dart';
import 'rule_constants.dart';
import 'title_rules.dart';

/// 2막 잿빛 군주의 분신 다섯 (묶음 34). 순서대로만 나온다.
enum AshAvatar { rage, sorrow, greed, fear, lonely }

/// 분신·본체 단계의 특별한 공격 (숨은 규칙, 화면에는 문장만)
enum AshMove {
  /// 분노 폭발: 체력이 줄수록 공격이 세진다
  rage,

  /// 눈물비: 몇 턴 동안 내 공격이 가끔 빗나가고, 그사이 스스로 회복
  tears,

  /// 빼앗기: 나에게 걸린 좋은 효과 하나를 빼앗아 자기 힘으로
  steal,

  /// 겁주기: 한 턴 동안 내 스킬 버튼이 잠긴다
  fear,

  /// 고립: 잠시 펫 게이지가 멈춘다
  isolate,
}

class AshAvatarInfo {
  const AshAvatarInfo({
    required this.id,
    required this.name,
    required this.level,
    required this.element,
    required this.monster,
    required this.move,
    required this.moveName,
    required this.moveLine,
    required this.gear,
    required this.title,
    required this.story,
    required this.kingLine,
  });

  final AshAvatar id;

  /// '잿불의 분노'
  final String name;

  /// 처음 나오는 레벨
  final int level;
  final Element element;
  final MonsterId monster;
  final AshMove move;

  /// '분노 폭발'
  final String moveName;

  /// 특별한 공격을 쓸 때 화면 문장 (숫자 없이)
  final String moveLine;

  /// 처음 쓰러뜨리면 받는 유품 장비
  final EquipBase gear;
  final TitleId title;

  /// 왕의 사연 한 조각
  final String story;

  /// 본체에서 이 감정 단계가 시작될 때 문장
  final String kingLine;

  String get asset => 'assets/images/monster_${monster.name}.webp';
}

/// 2막 규칙 (묶음 34). 숫자는 개발 제안값, 화면에는 보이지 않는다.
class Act2Rules {
  Act2Rules._();

  static const List<AshAvatarInfo> avatars = [
    AshAvatarInfo(
      id: AshAvatar.rage,
      name: '잿불의 분노',
      level: 12,
      element: Element.fire,
      monster: MonsterId.ashRage,
      move: AshMove.rage,
      moveName: '분노 폭발',
      moveLine: '분노가 점점 커지고 있어!',
      gear: EquipBase.ashWeapon,
      title: TitleId.ashRage,
      story: '백성들이 하나둘 빛을 잃고 쓰러졌다. 나는 하늘에 소리쳤지만, 대답은 없었다.',
      kingLine: '잿불이 타오른다. 분노가 먼저 덮쳐 와!',
    ),
    AshAvatarInfo(
      id: AshAvatar.sorrow,
      name: '잿비의 슬픔',
      level: 14,
      element: Element.water,
      monster: MonsterId.ashSorrow,
      move: AshMove.tears,
      moveName: '눈물비',
      moveLine: '눈물비가 내려요. 공격이 잘 닿지 않아!',
      gear: EquipBase.ashHands,
      title: TitleId.ashSorrow,
      story: '마지막 등불이 꺼지던 밤, 나는 왕관을 내려놓고 울었다.',
      kingLine: '분노가 걷혔어. 이번엔 슬픔이 차올라…',
    ),
    AshAvatarInfo(
      id: AshAvatar.greed,
      name: '잿금의 탐욕',
      level: 16,
      element: Element.metal,
      monster: MonsterId.ashGreed,
      move: AshMove.steal,
      moveName: '빼앗기',
      moveLine: '좋은 효과를 빼앗겼어! 탐욕이 더 강해졌어.',
      gear: EquipBase.ashBody,
      title: TitleId.ashGreed,
      story: '문 너머에 빛이 넘치는 세계가 있었다. 조금만, 아주 조금만 가져오면 된다고 생각했다.',
      kingLine: '슬픔이 걷혔어. 이번엔 탐욕이 손을 뻗어!',
    ),
    AshAvatarInfo(
      id: AshAvatar.fear,
      name: '잿그림자의 두려움',
      level: 18,
      element: Element.dark,
      monster: MonsterId.ashFear,
      move: AshMove.fear,
      moveName: '겁주기',
      moveLine: '겁에 질려 스킬 버튼이 잠겼어!',
      gear: EquipBase.ashAcc,
      title: TitleId.ashFear,
      story: '빛을 삼킬수록 나는 잿빛이 되어 갔다. 멈추면 나도, 나라도 사라질 것만 같았다.',
      kingLine: '탐욕이 걷혔어. 이번엔 두려움이 그림자를 드리워…',
    ),
    AshAvatarInfo(
      id: AshAvatar.lonely,
      name: '잿바람의 외로움',
      level: 20,
      element: Element.wind,
      monster: MonsterId.ashLonely,
      move: AshMove.isolate,
      moveName: '고립',
      moveLine: '고립됐어! 펫이 잠시 싸울 수 없어.',
      gear: EquipBase.ashFeet,
      title: TitleId.ashLonely,
      story: '이제 내 곁엔 아무도 없다. 잿빛 왕좌에서, 나는 누군가 문을 열고 들어와 주기를 기다렸다.',
      kingLine: '두려움이 걷혔어. 마지막은… 외로움이야.',
    ),
  ];

  static AshAvatarInfo info(AshAvatar a) => avatars[a.index];

  static AshAvatarInfo? ofMonster(MonsterId m) {
    for (final a in avatars) {
      if (a.monster == m) return a;
    }
    return null;
  }

  static AshAvatarInfo? ofMove(AshMove m) {
    for (final a in avatars) {
      if (a.move == m) return a;
    }
    return null;
  }

  /// 본체
  static const String kingName = '잿빛 군주';
  static const TitleId kingTitle = TitleId.bridgeMaker;
  static const EquipBase kingGear = EquipBase.ashCrown;

  /// 잿빛 틈이 처음 생길 때 첫 펫 한마디
  static const String riftFirstLine = '저기… 잿빛 틈이 열렸어. 왕의 기운이 느껴져. 걸어가도 되고, 나를 보내도 돼.';

  /// 분신 다섯을 모두 쓰러뜨렸을 때 첫 펫 한마디 (본체가 열림)
  static const String gateOpenLine = '던전 끝 「문 앞」이 다시 열렸어. 이제 왕을 만나러 가자.';

  /// 본체를 쓰러뜨린 뒤 Lv.21 이상이면 (또는 Lv.21이 될 때) 한 줄
  static const String bridgeLine = '다리 너머 세계가 곧 열려요';
  static const int bridgeLevel = 21;

  /// 다 진 날 잿빛 틈 문구
  static const String closedLine = '내일 다시 열려요';

  // ───────────── 지금 나올 분신

  /// 쓰러뜨린 분신 수와 레벨로 지금 나올 분신 (없으면 null). 앞 분신을 쓰러뜨려야 다음.
  static AshAvatar? nextAvatar({required int beaten, required int level}) {
    if (beaten < 0 || beaten >= avatars.length) return null;
    final a = avatars[beaten];
    return level >= a.level ? a.id : null;
  }

  // ───────────── 잿빛 틈 자리 (그날 처음 위치를 잡은 곳 둘레 300~800m, 하루 고정)

  static const double riftMinM = 300;
  static const double riftMaxM = 800;

  /// 걸어서 들어갈 수 있는 거리
  static const double riftEnterM = 50;

  /// 하루에 질 수 있는 횟수 (다 쓰면 내일)
  static const int triesPerDay = 3;

  static GeoPoint riftSpot(
    ExploreArea area, {
    required String dayKey,
    required GeoPoint anchor,
    required int avatar,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    LandKind? Function(GeoPoint)? land,
  }) {
    bool allowed(GeoPoint p, {bool road = true}) {
      final l = land?.call(p);
      return area.bounds.contains(p) &&
          !area.isExcluded(p) &&
          !(exclusions?.contains(p) ?? false) &&
          !(road && (roads?.isRoad(p) ?? false)) &&
          l != LandKind.water &&
          l != LandKind.sea;
    }

    final rng = math.Random(_hash('$dayKey|rift|$avatar'));
    final tries = [
      for (var i = 0; i < 24; i++)
        _offset(anchor, riftMinM + rng.nextDouble() * (riftMaxM - riftMinM),
            rng.nextDouble() * 2 * math.pi),
    ];
    for (final p in tries) {
      if (allowed(p)) return p;
    }
    for (final p in tries) {
      if (allowed(p, road: false)) return p;
    }
    return tries.first;
  }

  // ───────────── 경험치 (묶음 34 확인 답: 처음 쓰러뜨릴 때 한 번, 재료는 없음)

  /// 분신: 던전 보스 클리어 경험치의 2배
  static const int avatarExp = RuleConstants.dungeonClearExp * 2;

  /// 본체: 던전 보스 클리어 경험치의 3배
  static const int kingExp = RuleConstants.dungeonClearExp * 3;

  // ───────────── 강함 (그 레벨 던전 보스보다 조금 세게)

  /// 분신: 던전 보스 대비 체력·공격 배율
  static const double avatarHp = 1.5;
  static const double avatarAttack = 1.2;

  /// 본체: 감정 단계 하나의 체력·공격 배율 (단계 다섯을 이어서 싸운다)
  static const double kingPhaseHp = 1.2;
  static const double kingAttack = 1.3;

  static ({int hp, int attack}) _boss(int level) {
    final atk = BattleRules.expectedAttack(level);
    final hp = BattleRules.expectedMaxHp(level);
    final floorAttack =
        math.max(1, (hp / RuleConstants.dungeonHpBudgetTicks).round());
    return (
      hp: atk * RuleConstants.bossHitsToClear,
      attack: (floorAttack * RuleConstants.bossAttackMultiplier).round(),
    );
  }

  /// 분신 한 판 (층 없이 보스만). 레벨은 그 분신 레벨과 내 레벨 중 높은 쪽.
  static Foe avatarFoe(AshAvatar a, int level) {
    final i = info(a);
    final b = _boss(math.max(level, i.level));
    return Foe(
      monster: i.monster,
      maxHp: math.max(1, (b.hp * avatarHp).round()),
      attack: math.max(1, (b.attack * avatarAttack).round()),
      move: i.move,
    );
  }

  /// 본체: [from] 단계부터 다섯 번째 단계까지 (걷어낸 단계는 건너뜀)
  static List<Foe> kingFoes(int level, {int from = 0}) {
    final b = _boss(math.max(level, 20));
    return [
      for (var p = from.clamp(0, 4); p < 5; p++)
        Foe(
          monster: MonsterId.ashKing,
          maxHp: math.max(1, (b.hp * kingPhaseHp).round()),
          attack: math.max(1, (b.attack * kingAttack).round()),
          forceElement: avatars[p].element,
          move: avatars[p].move,
          reveal: p / 4,
        ),
    ];
  }

  // ───────────── 특별한 공격 세기 (숨김)

  /// 분노 폭발: 체력이 다 줄었을 때 공격 배율 +
  static const double rageMax = 0.6;

  /// 눈물비: 몇 턴마다 · 몇 턴 동안 · 빗나갈 확률 · 턴마다 회복(최대 체력 비율)
  static const int tearsEvery = 5;
  static const int tearsLength = 3;
  static const double tearsMiss = 0.35;
  static const double tearsHeal = 0.03;

  /// 빼앗기: 몇 턴마다 · 빼앗은 힘이 남는 턴 · 그동안 공격 배율
  static const int stealEvery = 4;
  static const int stolenLength = 3;
  static const double stolenAttack = 1.3;

  /// 겁주기: 몇 턴마다 (한 턴 동안 잠김)
  static const int fearEvery = 4;

  /// 고립: 몇 턴마다 · 몇 턴 동안 펫 게이지가 멈춤
  static const int isolateEvery = 5;
  static const int isolateLength = 3;

  // ───────────── 결말 컷신 「문을 다리로」

  /// (그림, 말하는 이(null 이면 내레이션), 각성자인지, 대사, 대사창 위, 펫인지(묶음 81 #376 얼굴))
  static List<({String image, String? speaker, bool hero, String line, bool top, bool pet})>
      ending({
    required String hero,
    required String spirit,
    required String pet,
    required bool female,
  }) {
    String img(String n) => 'assets/images/$n.webp';
    const king = '왕';
    return [
      (
        image: img('ending_01_face'),
        speaker: king,
        hero: false,
        line: '…나를 멈춰 주었구나.',
        top: false,
        pet: false,
      ),
      (
        image: img('ending_02_face_to_face${female ? '_female' : ''}'),
        speaker: king,
        hero: false,
        line: '내 나라는 아직 어둠 속에 있다. 빛을 빼앗지 않으면, 무엇으로 살리겠느냐.',
        top: false,
        pet: false,
      ),
      (
        image: img('ending_02_face_to_face${female ? '_female' : ''}'),
        speaker: hero,
        hero: true,
        line: '빼앗지 말고 나눠요. 우리 빛을 조금씩.',
        top: false,
        pet: false,
      ),
      (
        image: img('ending_03_promise'),
        speaker: king,
        hero: false,
        line: '…그래. 이번엔 문을 두드리지 않고, 함께 열겠다.',
        top: false,
        pet: false,
      ),
      (
        image: img('ending_04_bridge'),
        speaker: null,
        hero: false,
        line: '깨진 문은 다리가 되었다. 두 세계는 더 이상 서로를 삼키지 않는다.',
        top: true,
        pet: false,
      ),
      (
        image: img('ending_05_dawn'),
        speaker: pet,
        hero: false,
        line: '저 빛… ${josa(spirit, '이야/야')}. 문이 다리가 됐어도, '
            '${josa(spirit, '은/는')} 여기 있었구나.',
        top: false,
        pet: true,
      ),
      (
        image: img('ending_05_dawn'),
        speaker: null,
        hero: false,
        line: '여명의 탑 아르카에 다시 불꽃이 켜졌다.',
        top: false,
        pet: false,
      ),
    ];
  }

  // ───────────── 「잿빛 왕의 유품」 세트 (숨김)

  /// 2개: 잿빛 몬스터에게 받는 피해 감소
  static const double setTaken2 = 0.10;

  /// 4개: 잿빛 몬스터에게 주는 피해 증가
  static const double setDealt4 = 0.10;

  /// 6개: 둘 다 더 (합해서)
  static const double setTaken6 = 0.25;
  static const double setDealt6 = 0.25;

  static GeoPoint _offset(GeoPoint from, double meters, double bearing) {
    final dLat = meters * math.cos(bearing) / 111320;
    final dLng = meters *
        math.sin(bearing) /
        (111320 * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}
