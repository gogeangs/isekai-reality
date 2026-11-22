import 'dart:math' as math;

import 'act2_rules.dart';
import 'battle_rules.dart';

/// 묶음 82 #394: 잿빛 틈 분신 턴제 (본체 잿빛 군주는 지금 자동 전투 그대로).
///
/// 흐름: 내 차례 명령 하나 → 펫이 따라 한 번(자동) → 분신 차례(말풍선 + 공격) → 다음 턴.
/// 감정 게이지 5칸: 분신 차례마다 1칸 · 공격 스킬에 맞으면 1칸 더. 다 차면 붉은 말풍선으로
/// 「다음 턴: ○○」을 예고하고 다음 분신 차례에 특별 공격, 게이지는 비운다.
/// 마주하기: 게이지 2칸 이상일 때 피해 없이 2칸 내림 + 왕의 기억 한 조각.
///
/// 숫자는 모두 숨김. 분신의 HP · 공격은 「그 레벨의 고르게 키운 각성자」를 기준으로 정한다
/// (같은 레벨 기준이면 한 판 대략 8~14턴, 특별 공격을 한두 번은 막아야 이김).
enum AshCmd { attack, skill1, skill2, guard, face, potion }

/// 화면 연출 한 걸음 (차례대로 보여 줌)
enum AshEventKind {
  heroHit, // 내가 때림 (value = 피해)
  heroMiss, // 눈물비로 빗나감
  heroGuard, // 방어 자세
  heroWall, // 막는 스킬 (철벽 등)
  heroPotion, // 물약 (value = 회복)
  face, // 마주하기 (memory = 조각 번호, -1 이면 조각 없이 게이지만)
  petHit, // 펫이 때림
  petAway, // 펫이 못 도움 (외로움)
  foeHit, // 분신의 보통 공격 (value = 받은 피해)
  foeSpecial, // 특별 공격 (value = 받은 피해, 0 이면 피해 없는 효과)
  foeHeal, // 눈물비로 분신 회복
  warn, // 게이지가 다 참 → 다음 턴 예고
  foeDown, // 분신 쓰러짐
  heroDown, // 내가 쓰러짐
}

class AshEvent {
  const AshEvent(this.kind, {this.value = 0, this.text = '', this.big = false, this.memory = -1});
  final AshEventKind kind;
  final int value;
  final String text;

  /// 크게 (화면 흔들림 · 큰 숫자)
  final bool big;
  final int memory;
}

/// 전투 칸의 직업 스킬 하나 (공격 스킬이면 피해, 아니면 막는 스킬로 본다)
class AshTurnSkill {
  const AshTurnSkill({required this.key, required this.name, required this.mp, required this.attack, this.power = 1});
  final String key;
  final String name;
  final int mp;
  final bool attack;
  final double power;
}

/// 분신마다 다른 글 · 게이지
class AshTurnInfo {
  const AshTurnInfo({
    required this.gauge,
    required this.color,
    required this.special,
    required this.open,
    required this.lines,
    required this.shaken,
    required this.announce,
    required this.hint,
    required this.memories,
    required this.lastWord,
    required this.emotion,
  });

  /// 게이지 이름 (분노 · 눈물 · 욕심 · 두려움 · 외로움)
  final String gauge;
  final int color;

  /// 특별 공격 이름
  final String special;

  /// 처음 한마디
  final String open;

  /// 매 턴 왕의 목소리 (돌려 씀)
  final List<String> lines;

  /// 마주하기 뒤 흔들리는 대사
  final List<String> shaken;

  /// 게이지가 다 찼을 때 붉은 말풍선
  final String announce;

  /// 정령 힌트 한 줄 (예고 때)
  final String hint;

  /// 왕의 기억 세 조각
  final List<String> memories;

  /// 다 보고 이겼을 때 왕의 마지막 한마디
  final String lastWord;

  /// 끝 장면 「○○이 잠잠해졌어」의 ○○
  final String emotion;
}

class AshTurnRules {
  AshTurnRules._();

  static const int gaugeMax = 5;
  static const int faceNeed = 2;
  static const int potionsPerFight = 3;
  static const int memoryCount = 3;

  // ───────────── 숫자 (숨김)

  /// 분신 HP = 그 레벨 기준 공격 × 이 값
  static const double foeHpMul = 13.5;

  /// 분신 보통 공격 = 그 레벨 기준 최대 HP × 이 값 (±10%)
  static const double foeHitMul = 0.115;

  /// 분노 폭발 · 슬픔 등 특별 공격 세기 (기준 최대 HP 대비)
  static const double rageBurst = 0.42;

  /// 분노: 분신 HP 절반 아래면 보통 공격 ×
  static const double rageLowHp = 1.25;

  /// 공격 스킬 배율 (+ 스킬 힘)
  static const double skillMul = 1.7;

  /// 펫 한 번 (내 공격 대비)
  static const double petMul = 0.35;
  static const double petAdultMul = 1.25;

  /// 방어: 그 턴 받는 피해 × · 특별 공격(분노 폭발)은 더 크게 줄임
  static const double guardCut = 0.5;
  static const double guardBurstCut = 0.3;

  /// 막는 스킬(철벽 등): 2턴 동안 받는 피해 ×
  static const double wallCut = 0.4;
  static const int wallTurns = 2;

  /// 방어 때 MP 조금 (직업 MP 최대 대비)
  static const double guardMp = 0.08;

  /// 눈물비: 2턴 · 내 공격 절반 빗나감 · 분신 차례마다 최대 HP의 2% 회복
  static const int rainTurns = 2;
  static const double rainMiss = 0.5;
  static const double rainHeal = 0.02;

  /// 탐욕: 빼앗은 힘 (분신 공격 +)
  static const double greedSteal = 0.3;
  static const double greedNothing = 0.15;

  /// 외로움: 2턴 펫이 못 도움
  static const int lonelyTurns = 2;

  /// 탐욕 · 두려움 · 외로움 특별 공격 턴의 공격 × (방어로 막을 만큼 세게)
  static const double specialHit = 1.6;

  static int foeMaxHp(int level) => math.max(1, (BattleRules.expectedAttack(level) * foeHpMul).round());
  static int foeHit(int level) => math.max(1, (BattleRules.expectedMaxHp(level) * foeHitMul).round());
  static int foeBurst(int level) => math.max(1, (BattleRules.expectedMaxHp(level) * rageBurst).round());

  // ───────────── 글

  static const Map<AshAvatar, AshTurnInfo> infos = {
    AshAvatar.rage: AshTurnInfo(
      gauge: '분노',
      color: 0xFFFF7A2F,
      special: '분노 폭발',
      open: '…누구냐. 이 불길 속에 들어온 자는.',
      lines: ['나를 막지 마라…!', '모두 타 버려라!', '왜… 아무도 대답하지 않지?', '이 불은 꺼지지 않는다!', '백성들은… 어디 있지…'],
      shaken: ['…그 이야기를… 어떻게…', '이 불이… 조금 흔들린다…'],
      announce: '더는… 참지 않겠다!',
      hint: '다음 턴에 분노 폭발이야! 방어하거나 마주하기로 달래!',
      memories: ['「백성들이 하나둘 빛을 잃고 쓰러졌다.」', '「나는 하늘에 소리쳤다. 왜 나의 백성인가.」', '「대답은 없었다. 남은 것은… 타오르는 이 마음뿐.」'],
      lastWord: '「…고맙다. 이제야 조용하구나.」',
      emotion: '분노',
    ),
    AshAvatar.sorrow: AshTurnInfo(
      gauge: '눈물',
      color: 0xFF6FA8FF,
      special: '눈물비',
      open: '…여기까지 와서, 무엇을 보려는 것이냐.',
      lines: ['비가… 그치지 않는구나.', '모두 떠나 버렸다…', '울지 마라… 아니, 울게 두어라.', '이 눈물은 마르지 않는다.', '등불은… 다 어디 갔지…'],
      shaken: ['…그 밤을 기억하는가…', '눈물이… 조금 가벼워진다…'],
      announce: '쏟아져라, 눈물아…!',
      hint: '눈물비가 와! 오면 공격이 잘 안 닿아. 마주하기로 그칠 수 있어.',
      memories: ['「등불이 하나씩 꺼져 갔다.」', '「마지막 등불이 꺼지던 밤, 나는 왕관을 내려놓았다.」', '「그리고… 아무도 모르게 울었다.」'],
      lastWord: '「…울어도 괜찮다고, 누군가 말해 주길 바랐다.」',
      emotion: '슬픔',
    ),
    AshAvatar.greed: AshTurnInfo(
      gauge: '욕심',
      color: 0xFFE9C46A,
      special: '빼앗기',
      open: '…그 빛, 탐이 나는구나.',
      lines: ['더… 더 가져와야 해.', '그것도 내 것이다!', '조금만, 아주 조금만…', '빛이 모자라… 모자라!', '내 손을 놓지 마라.'],
      shaken: ['…그건… 누군가의 빛이었나…', '손이… 떨린다…'],
      announce: '네 힘도 내놓아라!',
      hint: '내 좋은 효과를 빼앗으려 해! 빼앗기면 마주하기로 돌려받자.',
      memories: ['「문 너머에 빛이 넘치는 세계가 있었다.」', '「조금만, 아주 조금만 가져오면 된다고 생각했다.」', '「그 빛이 누군가의 하루였다는 걸… 나는 몰랐다.」'],
      lastWord: '「…이제 돌려주겠다. 처음부터 내 것이 아니었으니.」',
      emotion: '탐욕',
    ),
    AshAvatar.fear: AshTurnInfo(
      gauge: '두려움',
      color: 0xFF9A7BFF,
      special: '겁주기',
      open: '…오지 마라. 가까이 오지 마.',
      lines: ['멈추면… 사라진다.', '다가오지 마…!', '어둠이 나를 삼킨다…', '무섭지 않다… 무섭지 않아…', '그림자가 자꾸 커진다.'],
      shaken: ['…멈춰도… 괜찮은 건가…', '그림자가… 조금 옅어진다…'],
      announce: '너도 겁에 질려라!',
      hint: '다음 턴엔 스킬이 잠겨! 쓰려면 지금 써.',
      memories: ['「빛을 삼킬수록 나는 잿빛이 되어 갔다.」', '「멈추면 나도, 나라도 사라질 것만 같았다.」', '「그래서 멈출 수 없었다. 무서웠으니까.」'],
      lastWord: '「…멈춰도 사라지지 않는구나.」',
      emotion: '두려움',
    ),
    AshAvatar.lonely: AshTurnInfo(
      gauge: '외로움',
      color: 0xFF7FD6C2,
      special: '고립',
      open: '…또 누가 왔다가, 떠나겠지.',
      lines: ['아무도… 오지 않는다.', '곁에 있는 그 녀석도 곧 떠날 거다.', '바람만 분다…', '혼자인 게… 익숙해.', '누구라도… 좋으니…'],
      shaken: ['…정말 와 준 건가…', '바람이… 조금 따뜻하다…'],
      announce: '너도 혼자가 되어라!',
      hint: '펫이 잠시 떨어지게 돼! 마주하기로 다시 불러올 수 있어.',
      memories: ['「이제 내 곁엔 아무도 없다.」', '「잿빛 왕좌에서, 나는 문만 바라보았다.」', '「누군가 문을 열고 들어와 주기를… 오래, 기다렸다.」'],
      lastWord: '「…와 주었구나. 고맙다.」',
      emotion: '외로움',
    ),
  };

  static AshTurnInfo info(AshAvatar a) => infos[a]!;
}

/// 한 판. 화면은 [act] 가 돌려준 걸음을 차례대로 보여 준다.
class AshTurn {
  AshTurn({
    required this.avatar,
    required this.level,
    required this.heroMaxHp,
    required int heroHp,
    required this.heroAttack,
    this.crit = 0,
    this.evade = 0,
    this.damageTaken = 1,
    required int mp,
    required this.mpMax,
    this.skills = const [],
    this.hasPet = false,
    this.petAdult = false,
    this.potions = const [],
    this.memoriesSeen = 0,
    math.Random? rng,
  })  : _rng = rng ?? math.Random(),
        hp = heroHp.clamp(0, heroMaxHp),
        mp = mp.clamp(0, math.max(0, mpMax)),
        foeMax = AshTurnRules.foeMaxHp(math.max(level, Act2Rules.info(avatar).level)),
        _foeHit = AshTurnRules.foeHit(math.max(level, Act2Rules.info(avatar).level)),
        _foeBurst = AshTurnRules.foeBurst(math.max(level, Act2Rules.info(avatar).level)) {
    foeHp = foeMax;
    say = info.open;
  }

  final AshAvatar avatar;
  final int level;
  final int heroMaxHp;
  final int heroAttack;
  final double crit;
  final double evade;
  final double damageTaken;
  final int mpMax;
  final List<AshTurnSkill> skills;
  final bool hasPet;
  final bool petAdult;

  /// 마실 수 있는 회복 물약 (좋은 것부터 고름)
  final List<BattlePotion> potions;
  final math.Random _rng;

  final int foeMax;
  final int _foeHit;
  final int _foeBurst;

  AshTurnInfo get info => AshTurnRules.info(avatar);

  int hp;
  int mp;
  late int foeHp;
  int gauge = 0;
  int turn = 0;

  /// 지금까지 본 왕의 기억 (이전 판 포함)
  int memoriesSeen;

  /// 이번 판에 새로 본 조각
  int memoriesNew = 0;

  /// 지금 말풍선 · 붉은지
  String say = '';
  bool sayWarn = false;

  // 상태
  bool guarding = false;
  int wall = 0;
  int rain = 0;
  int petAway = 0;
  bool skillsLocked = false;
  double foePower = 1;

  /// 탐욕이 빼앗은 철벽 (마주하기로 돌려받음)
  int stolenWall = 0;

  final Map<String, int> potionsUsed = {};
  int get potionsLeftThisFight => AshTurnRules.potionsPerFight - potionsUsed.values.fold<int>(0, (a, b) => a + b);
  BattlePotion? get bestPotion {
    BattlePotion? best;
    for (final p in potions) {
      if (p.hpRatio <= 0) continue;
      if ((potionsUsed[p.key] ?? 0) >= p.count) continue;
      if (best == null || p.hpRatio > best.hpRatio) best = p;
    }
    return best;
  }

  bool get won => foeHp <= 0;
  bool get lost => hp <= 0;
  bool get isOver => won || lost;
  bool get specialNext => gauge >= AshTurnRules.gaugeMax;
  bool get faceOpen => gauge >= AshTurnRules.faceNeed;
  bool get allMemories => memoriesSeen >= AshTurnRules.memoryCount;

  /// 명령을 쓸 수 있는지
  bool can(AshCmd c) {
    if (isOver) return false;
    switch (c) {
      case AshCmd.attack:
      case AshCmd.guard:
        return true;
      case AshCmd.face:
        return faceOpen;
      case AshCmd.potion:
        return potionsLeftThisFight > 0 && bestPotion != null && hp < heroMaxHp;
      case AshCmd.skill1:
      case AshCmd.skill2:
        final i = c == AshCmd.skill1 ? 0 : 1;
        if (skillsLocked || i >= skills.length) return false;
        return mp >= skills[i].mp;
    }
  }

  AshTurnSkill? skillOf(AshCmd c) => switch (c) {
        AshCmd.skill1 => skills.isNotEmpty ? skills[0] : null,
        AshCmd.skill2 => skills.length > 1 ? skills[1] : null,
        _ => null,
      };

  int _roll(int base) => math.max(1, (base * (0.9 + _rng.nextDouble() * 0.2)).round());

  /// 한 턴: 내 명령 → 펫 → 분신. 쓸 수 없는 명령이면 빈 목록
  List<AshEvent> act(AshCmd c) {
    if (!can(c)) return const [];
    final out = <AshEvent>[];
    turn++;
    guarding = false;
    skillsLocked = false; // 잠긴 턴은 이번 한 번 (예고 턴에 미리 쓰기)
    // ① 내 차례
    switch (c) {
      case AshCmd.attack:
        _heroHit(out, heroAttack.toDouble(), big: false);
      case AshCmd.skill1:
      case AshCmd.skill2:
        final s = skillOf(c)!;
        mp -= s.mp;
        if (s.attack) {
          _heroHit(out, heroAttack * (AshTurnRules.skillMul + 0.3 * (s.power - 1).clamp(0, 2)), big: true, skill: s.name);
          // 큰 스킬에 맞으면 게이지 1칸 더
          if (foeHp > 0) gauge = math.min(AshTurnRules.gaugeMax, gauge + 1);
        } else {
          wall = AshTurnRules.wallTurns;
          out.add(AshEvent(AshEventKind.heroWall, text: '${s.name}! 잠시 받는 피해가 크게 줄어요.'));
        }
      case AshCmd.guard:
        guarding = true;
        final add = math.max(1, (mpMax * AshTurnRules.guardMp).round());
        if (mpMax > 0) mp = math.min(mpMax, mp + add);
        out.add(const AshEvent(AshEventKind.heroGuard, text: '방어 자세. 이 턴 받는 피해가 줄어요.'));
      case AshCmd.potion:
        final p = bestPotion!;
        potionsUsed[p.key] = (potionsUsed[p.key] ?? 0) + 1;
        final v = math.min(heroMaxHp - hp, math.max(1, (heroMaxHp * p.hpRatio).round()));
        hp += v;
        out.add(AshEvent(AshEventKind.heroPotion, value: v, text: '${p.name}을(를) 마셨어요.'));
      case AshCmd.face:
        gauge = math.max(0, gauge - AshTurnRules.faceNeed);
        var mem = -1;
        if (!allMemories) {
          mem = memoriesSeen;
          memoriesSeen++;
          memoriesNew++;
        }
        // 마주하기: 눈물비가 그침 · 빼앗긴 것을 돌려받음 · 펫이 돌아옴
        rain = 0;
        petAway = 0;
        if (stolenWall > 0 || foePower > 1) {
          wall = math.max(wall, stolenWall);
          stolenWall = 0;
          foePower = 1;
        }
        say = info.shaken[(memoriesSeen + turn) % info.shaken.length];
        sayWarn = false;
        out.add(AshEvent(AshEventKind.face, memory: mem, text: '마주하기 — ${info.gauge}이(가) 가라앉았어요.'));
    }
    if (won) {
      out.add(const AshEvent(AshEventKind.foeDown));
      return out;
    }
    // ② 펫 (자동)
    if (hasPet) {
      if (petAway > 0) {
        out.add(const AshEvent(AshEventKind.petAway, text: '펫이 멀리 떨어져 돕지 못해요.'));
      } else {
        final d = _roll((heroAttack * AshTurnRules.petMul * (petAdult ? AshTurnRules.petAdultMul : 1)).round());
        foeHp = math.max(0, foeHp - d);
        out.add(AshEvent(AshEventKind.petHit, value: d));
        if (won) {
          out.add(const AshEvent(AshEventKind.foeDown));
          return out;
        }
      }
    }
    // ③ 분신 차례
    _foeTurn(out);
    if (petAway > 0) petAway--;
    return out;
  }

  void _heroHit(List<AshEvent> out, double base, {required bool big, String? skill}) {
    if (rain > 0 && _rng.nextDouble() < AshTurnRules.rainMiss) {
      out.add(const AshEvent(AshEventKind.heroMiss, text: '눈물비에 가려 빗나갔어요.'));
      return;
    }
    final crit = _rng.nextDouble() < this.crit;
    final d = _roll((base * (crit ? 1.5 : 1)).round());
    foeHp = math.max(0, foeHp - d);
    out.add(AshEvent(AshEventKind.heroHit,
        value: d,
        big: big || crit,
        text: skill != null ? '$skill!' : (crit ? '치명타!' : '')));
  }

  int _taken(int raw, {bool burst = false}) {
    var m = damageTaken;
    if (guarding) m *= burst ? AshTurnRules.guardBurstCut : AshTurnRules.guardCut;
    if (wall > 0) m *= burst ? AshTurnRules.wallCut * 0.75 : AshTurnRules.wallCut;
    return math.max(1, (raw * m).round());
  }

  void _foeTurn(List<AshEvent> out) {
    final special = specialNext;
    var normal = (_foeHit * foePower);
    if (avatar == AshAvatar.rage && foeHp * 2 < foeMax) normal *= AshTurnRules.rageLowHp;
    if (special) {
      gauge = 0;
      sayWarn = true;
      say = '${info.special}!';
      switch (avatar) {
        case AshAvatar.rage:
          final d = _taken(_roll((_foeBurst * foePower).round()), burst: true);
          hp = math.max(0, hp - d);
          out.add(AshEvent(AshEventKind.foeSpecial, value: d, big: true, text: guarding || wall > 0 ? '분노 폭발! 막아서 크게 줄었어요.' : '분노 폭발!'));
        case AshAvatar.sorrow:
          rain = AshTurnRules.rainTurns;
          final d = _taken(_roll((normal * 0.5).round()));
          hp = math.max(0, hp - d);
          out.add(AshEvent(AshEventKind.foeSpecial, value: d, text: '눈물비가 내려요. 공격이 잘 닿지 않아요.'));
        case AshAvatar.greed:
          if (wall > 0) {
            stolenWall = wall;
            wall = 0;
            foePower += AshTurnRules.greedSteal;
            out.add(const AshEvent(AshEventKind.foeSpecial, text: '좋은 효과를 빼앗겼어요! 탐욕이 더 강해졌어요.'));
          } else {
            foePower += AshTurnRules.greedNothing;
            out.add(const AshEvent(AshEventKind.foeSpecial, text: '빼앗을 것을 찾다 힘을 끌어모았어요.'));
          }
          _normalHit(out, normal * AshTurnRules.specialHit);
        case AshAvatar.fear:
          skillsLocked = true;
          out.add(const AshEvent(AshEventKind.foeSpecial, text: '겁에 질려 다음 턴 스킬이 잠겼어요.'));
          _normalHit(out, normal * AshTurnRules.specialHit);
        case AshAvatar.lonely:
          petAway = AshTurnRules.lonelyTurns + 1; // 이번 턴 끝에 하나 줄어 2턴
          out.add(const AshEvent(AshEventKind.foeSpecial, text: '고립됐어요! 펫이 잠시 도울 수 없어요.'));
          _normalHit(out, normal * AshTurnRules.specialHit);
      }
    } else {
      say = info.lines[turn % info.lines.length];
      sayWarn = false;
      _normalHit(out, normal);
    }
    if (rain > 0 && !special) {
      final h = math.min(foeMax - foeHp, (foeMax * AshTurnRules.rainHeal).round());
      if (h > 0) {
        foeHp += h;
        out.add(AshEvent(AshEventKind.foeHeal, value: h));
      }
      rain--;
    }
    if (wall > 0) wall--;
    if (lost) {
      out.add(const AshEvent(AshEventKind.heroDown));
      return;
    }
    if (!special) {
      gauge = math.min(AshTurnRules.gaugeMax, gauge + 1);
      if (specialNext) {
        say = info.announce;
        sayWarn = true;
        out.add(AshEvent(AshEventKind.warn, text: '다음 턴: ${info.special}'));
      }
    }
  }

  void _normalHit(List<AshEvent> out, double raw) {
    if (_rng.nextDouble() < evade) {
      out.add(const AshEvent(AshEventKind.foeHit, value: 0, text: '피했어요!'));
      return;
    }
    final d = _taken(_roll(raw.round()));
    hp = math.max(0, hp - d);
    out.add(AshEvent(AshEventKind.foeHit, value: d));
  }
}
