import 'dart:math' as math;

import 'ash_turn_rules.dart' show AshTurnSkill;
import 'battle_rules.dart';
import 'highland_rules.dart';

/// 묶음 83 #389: 하이랜드 수호자 턴제.
///
/// 흐름: 내 명령 하나 → 펫이 따라 한 번(자동) → 수호자 차례. 수호자 옆 말풍선이 「다음 턴에 할 일」을
/// 미리 알려 주고(큰 기술은 붉은 테 + 이름), 그걸 보고 맞는 명령을 고르는 게 핵심.
/// 감정 게이지 · 마주하기는 없다. 섬마다 지금 기술(SkyMove)을 턴으로 옮겼다.
///
/// 숫자는 모두 숨김 · 개발 제안값. 수호자 HP · 공격은 「그 레벨의 고르게 키운 각성자」 기준
/// (같은 레벨이 예고를 보고 싸우면 대략 10~14턴, 예고를 무시하면 물약 없이는 진다).
enum SkyCmd { strike, skill1, skill2, guard, petSkill, potion }

/// 수호자가 다음 턴에 할 일 (말풍선)
enum SkyIntent {
  hit, // 보통 공격
  whirl, // 회오리: 두 번 움직임
  charge, // 먹구름을 모음 (다음 턴 낙뢰)
  bolt, // 낙뢰
  heal, // 햇살 치유
  armor, // 서리 갑옷
  wash, // 물살
}

enum SkyEventKind {
  heroHit, // 내가 때림 (value = 피해)
  heroGuard, // 방어
  heroWall, // 막는 스킬
  heroPotion, // 물약 (value = 회복)
  armorBreak, // 강타로 서리 갑옷을 깸
  petHit, // 펫이 따라 한 번
  petSkill, // 펫 스킬
  foeHit, // 수호자의 공격 (value = 받은 피해)
  foeSpecial, // 큰 기술 (value = 받은 피해, 0 이면 효과만)
  foeHeal, // 햇살 치유 (value = 회복)
  foeCharge, // 먹구름을 모음
  washed, // 물살에 좋은 효과가 씻김
  foeDown,
  heroDown,
}

class SkyEvent {
  const SkyEvent(this.kind, {this.value = 0, this.text = '', this.big = false});
  final SkyEventKind kind;
  final int value;
  final String text;
  final bool big;
}

class SkyTurnRules {
  SkyTurnRules._();

  static const int potionsPerFight = 3;

  /// 펫 스킬: 몇 턴마다
  static const int petEvery = 3;

  /// 처음 그 섬 수호자와 싸울 때 초록 힌트를 보여 주는 예고 수
  static const int hintCount = 3;

  // ───────────── 숫자 (숨김)

  /// 수호자 HP = 그 레벨 기준 공격 × 이 값 × guardianHp
  static const double foeHpBase = 9.0;

  /// 수호자 보통 공격 = 그 레벨 기준 최대 HP × 이 값 × guardianAttack (±10%)
  static const double foeHitBase = 0.10;

  /// 공격 스킬 배율 (+ 스킬 힘)
  static const double skillMul = 1.7;

  /// 펫 따라 치기 · 펫 스킬 (내 공격 대비) · 다 자란 펫
  static const double petMul = 0.35;
  static const double petSkillMul = 1.3;
  static const double petAdultMul = 1.25;

  /// 방어: 그 턴 받는 피해 × · MP 조금 (직업 MP 최대 대비)
  static const double guardCut = 0.5;
  static const double guardMp = 0.08;

  /// 물살: 좋은 효과를 씻어 낸 뒤 세게 밀어붙임 (보통 공격 ×, 방어로 줄임)
  static const double washHit = 1.6;

  /// 막는 스킬(철벽 등): 2턴 동안 받는 피해 ×
  static const double wallCut = 0.4;
  static const int wallTurns = 2;

  static int foeMaxHp(int level) => math.max(1,
      (BattleRules.expectedAttack(level) * foeHpBase * HighlandRules.guardianHp).round());
  static int foeHit(int level) => math.max(1,
      (BattleRules.expectedMaxHp(level) * foeHitBase * HighlandRules.guardianAttack).round());

  /// 다음 턴 말풍선 글 (짧게) · 큰 기술은 이름
  static String intentLine(SkyIntent i, Isle isle) => switch (i) {
        SkyIntent.hit => const ['바람을 가르며 다가와요.', '돌 팔을 들어 올려요.', '눈빛이 번쩍여요.'][isle.index % 3],
        SkyIntent.whirl => '다음 턴: 회오리',
        SkyIntent.charge => '먹구름을 모으고 있어요…',
        SkyIntent.bolt => '다음 턴: 낙뢰',
        SkyIntent.heal => '다음 턴: 햇살 치유',
        SkyIntent.armor => '다음 턴: 서리 갑옷',
        SkyIntent.wash => '다음 턴: 물살',
      };

  /// 큰 기술 설명 (말풍선 아래 작은 글)
  static String intentTip(SkyIntent i) => switch (i) {
        SkyIntent.hit => '보통 공격',
        SkyIntent.whirl => '두 번 공격해요 · 방어나 막는 스킬로 버티기',
        SkyIntent.charge => '다음 턴에 낙뢰가 떨어져요',
        SkyIntent.bolt => '아주 큰 한 방 · 방어하면 거의 막아요',
        SkyIntent.heal => '크게 회복해요 · 지금 몰아치면 덜 회복돼요',
        SkyIntent.armor => '받는 피해가 크게 줄어요 · 강타로 깨기',
        SkyIntent.wash => '좋은 효과를 씻고 세게 밀어붙여요 · 막는 스킬은 아끼고 방어',
      };

  static bool big(SkyIntent i) => i != SkyIntent.hit && i != SkyIntent.charge;
}

/// 수호자 한 판. 화면은 [act] 가 돌려준 걸음을 차례대로 보여 준다.
class SkyTurn {
  SkyTurn({
    required this.isle,
    required this.level,
    required this.heroMaxHp,
    required int heroHp,
    required this.heroAttack,
    this.crit = 0,
    this.evade = 0,
    this.damageTaken = 1,
    this.skyTaken = 0,
    required int mp,
    required this.mpMax,
    this.skills = const [],
    this.hasPet = false,
    this.petAdult = false,
    this.potions = const [],
    this.hints = false,
    math.Random? rng,
  })  : _rng = rng ?? math.Random(),
        hp = heroHp.clamp(0, heroMaxHp),
        mp = mp.clamp(0, math.max(0, mpMax)),
        foeMax = SkyTurnRules.foeMaxHp(level),
        _foeHit = SkyTurnRules.foeHit(level) {
    foeHp = foeMax;
    hintsLeft = hints ? SkyTurnRules.hintCount : 0;
    intent = _plan(1);
  }

  final Isle isle;
  final int level;
  final int heroMaxHp;
  final int heroAttack;
  final double crit;
  final double evade;
  final double damageTaken;

  /// 「하이랜드 수호 기사」 4개: 하늘 속성 피해 감소 (수호자는 모두 하늘 속성)
  final double skyTaken;
  final int mpMax;
  final List<AshTurnSkill> skills;
  final bool hasPet;
  final bool petAdult;
  final List<BattlePotion> potions;

  /// 처음 그 섬 수호자와 싸우는지 (초록 힌트)
  final bool hints;
  final math.Random _rng;

  final int foeMax;
  final int _foeHit;

  IsleInfo get info => HighlandRules.info(isle);

  int hp;
  int mp;
  late int foeHp;

  /// 지금 턴 (1부터, 내 명령을 고르는 턴)
  int turn = 1;
  late SkyIntent intent;
  late int hintsLeft;

  bool guarding = false;
  int wall = 0;

  /// 서리 갑옷 남은 턴
  int frost = 0;
  bool healed = false;
  bool _boltNext = false;

  /// 펫 스킬까지 남은 턴 (0 이면 준비됨)
  int petWait = 0;

  final Map<String, int> potionsUsed = {};
  int get potionsLeftThisFight =>
      SkyTurnRules.potionsPerFight - potionsUsed.values.fold<int>(0, (a, b) => a + b);
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
  bool get bigNext => SkyTurnRules.big(intent);

  /// 이번 턴 초록 힌트 명령 (처음 그 섬 수호자와 싸울 때 · 큰 기술 예고 세 번까지)
  Set<SkyCmd> get hinted {
    if (hintsLeft <= 0 || isOver) return const {};
    final atk = _skillIndex(attack: true);
    final wallCmd = _skillIndex(attack: false);
    final Set<SkyCmd> out = switch (intent) {
      SkyIntent.whirl => {SkyCmd.guard, if (wallCmd != null) wallCmd},
      SkyIntent.bolt => {SkyCmd.guard},
      SkyIntent.heal => {atk ?? SkyCmd.strike},
      SkyIntent.armor => {SkyCmd.strike},
      SkyIntent.wash => {SkyCmd.guard},
      _ => frost > 0 ? {SkyCmd.strike} : const {},
    };
    return {for (final c in out) if (can(c)) c};
  }

  SkyCmd? _skillIndex({required bool attack}) {
    for (var i = 0; i < skills.length && i < 2; i++) {
      final c = i == 0 ? SkyCmd.skill1 : SkyCmd.skill2;
      if (skills[i].attack == attack && can(c)) return c;
    }
    return null;
  }

  bool can(SkyCmd c) {
    if (isOver) return false;
    switch (c) {
      case SkyCmd.strike:
      case SkyCmd.guard:
        return true;
      case SkyCmd.petSkill:
        return hasPet && petWait <= 0;
      case SkyCmd.potion:
        return potionsLeftThisFight > 0 && bestPotion != null && hp < heroMaxHp;
      case SkyCmd.skill1:
      case SkyCmd.skill2:
        final i = c == SkyCmd.skill1 ? 0 : 1;
        if (i >= skills.length) return false;
        return mp >= skills[i].mp;
    }
  }

  AshTurnSkill? skillOf(SkyCmd c) => switch (c) {
        SkyCmd.skill1 => skills.isNotEmpty ? skills[0] : null,
        SkyCmd.skill2 => skills.length > 1 ? skills[1] : null,
        _ => null,
      };

  int _roll(int base) => math.max(1, (base * (0.9 + _rng.nextDouble() * 0.2)).round());

  /// 그 턴 수호자가 할 일
  SkyIntent _plan(int t) {
    if (_boltNext) return SkyIntent.bolt;
    switch (info.move) {
      case SkyMove.whirl:
        if (t % HighlandRules.whirlEvery == 3) return SkyIntent.whirl;
      case SkyMove.bolt:
        if (t % HighlandRules.boltEvery == 3) return SkyIntent.charge;
      case SkyMove.sunHeal:
        if (!healed && foeHp < foeMax * HighlandRules.sunHealBelow) return SkyIntent.heal;
      case SkyMove.frostArmor:
        if (frost <= 0 && t % HighlandRules.frostEvery == 3) return SkyIntent.armor;
      case SkyMove.wash:
        if (t % HighlandRules.washEvery == 3) return SkyIntent.wash;
    }
    return SkyIntent.hit;
  }

  /// 한 턴: 내 명령 → 펫 → 수호자. 쓸 수 없는 명령이면 빈 목록
  List<SkyEvent> act(SkyCmd c) {
    if (!can(c)) return const [];
    final out = <SkyEvent>[];
    if (hinted.isNotEmpty) hintsLeft--;
    guarding = false;
    var petUsed = false;
    // ① 내 차례
    switch (c) {
      case SkyCmd.strike:
        if (frost > 0) {
          frost = 0;
          out.add(const SkyEvent(SkyEventKind.armorBreak, text: '강타로 서리 갑옷을 깼어요!'));
        }
        _heroHit(out, heroAttack.toDouble(), big: false);
      case SkyCmd.skill1:
      case SkyCmd.skill2:
        final s = skillOf(c)!;
        mp -= s.mp;
        if (s.attack) {
          _heroHit(out, heroAttack * (SkyTurnRules.skillMul + 0.3 * (s.power - 1).clamp(0, 2)),
              big: true, skill: s.name);
        } else {
          wall = SkyTurnRules.wallTurns;
          out.add(SkyEvent(SkyEventKind.heroWall, text: '${s.name}! 잠시 받는 피해가 크게 줄어요.'));
        }
      case SkyCmd.guard:
        guarding = true;
        if (mpMax > 0) mp = math.min(mpMax, mp + math.max(1, (mpMax * SkyTurnRules.guardMp).round()));
        out.add(const SkyEvent(SkyEventKind.heroGuard, text: '방어 태세. 이번 턴 받는 피해가 줄어요.'));
      case SkyCmd.petSkill:
        petUsed = true;
        petWait = SkyTurnRules.petEvery;
        final d = _cut(_roll((heroAttack * SkyTurnRules.petSkillMul * (petAdult ? SkyTurnRules.petAdultMul : 1)).round()));
        foeHp = math.max(0, foeHp - d);
        out.add(SkyEvent(SkyEventKind.petSkill, value: d, big: true, text: '펫 스킬!'));
      case SkyCmd.potion:
        final p = bestPotion!;
        potionsUsed[p.key] = (potionsUsed[p.key] ?? 0) + 1;
        final v = math.min(heroMaxHp - hp, math.max(1, (heroMaxHp * p.hpRatio).round()));
        hp += v;
        out.add(SkyEvent(SkyEventKind.heroPotion, value: v, text: '${p.name}을(를) 마셨어요.'));
    }
    if (won) {
      out.add(const SkyEvent(SkyEventKind.foeDown));
      return out;
    }
    // ② 펫 (자동, 펫 스킬을 쓴 턴은 빼고)
    if (hasPet && !petUsed) {
      final d = _cut(_roll((heroAttack * SkyTurnRules.petMul * (petAdult ? SkyTurnRules.petAdultMul : 1)).round()));
      foeHp = math.max(0, foeHp - d);
      out.add(SkyEvent(SkyEventKind.petHit, value: d));
      if (won) {
        out.add(const SkyEvent(SkyEventKind.foeDown));
        return out;
      }
    }
    // ③ 수호자 차례
    _foeTurn(out);
    if (wall > 0) wall--;
    if (petWait > 0) petWait--;
    if (lost) {
      out.add(const SkyEvent(SkyEventKind.heroDown));
      return out;
    }
    turn++;
    intent = _plan(turn);
    return out;
  }

  /// 서리 갑옷이면 내 피해 ×
  int _cut(int d) => frost > 0 ? math.max(1, (d * HighlandRules.frostTaken).round()) : d;

  void _heroHit(List<SkyEvent> out, double base, {required bool big, String? skill}) {
    final cr = _rng.nextDouble() < crit;
    final d = _cut(_roll((base * (cr ? 1.5 : 1)).round()));
    foeHp = math.max(0, foeHp - d);
    out.add(SkyEvent(SkyEventKind.heroHit,
        value: d, big: big || cr, text: skill != null ? '$skill!' : (cr ? '치명타!' : '강타!')));
  }

  int _taken(double raw, {bool bolt = false}) {
    var m = damageTaken * (1 - skyTaken);
    if (guarding) m *= bolt ? HighlandRules.boltBlocked : SkyTurnRules.guardCut;
    if (wall > 0) m *= bolt ? HighlandRules.boltBlocked : SkyTurnRules.wallCut;
    return math.max(1, (_roll(raw.round()) * m).round());
  }

  void _normalHit(List<SkyEvent> out, {String text = ''}) {
    if (_rng.nextDouble() < evade) {
      out.add(const SkyEvent(SkyEventKind.foeHit, value: 0, text: '피했어요!'));
      return;
    }
    final d = _taken(_foeHit.toDouble());
    hp = math.max(0, hp - d);
    out.add(SkyEvent(SkyEventKind.foeHit, value: d, text: text));
  }

  void _foeTurn(List<SkyEvent> out) {
    final i = intent;
    if (frost > 0) frost--;
    switch (i) {
      case SkyIntent.hit:
        _normalHit(out);
      case SkyIntent.whirl:
        out.add(const SkyEvent(SkyEventKind.foeSpecial, text: '회오리! 수호자가 두 번 움직여요.'));
        for (var k = 0; k < HighlandRules.whirlLength && !lost; k++) {
          _normalHit(out);
        }
      case SkyIntent.charge:
        _boltNext = true;
        out.add(const SkyEvent(SkyEventKind.foeCharge, text: '먹구름이 모여요… 다음 턴에 낙뢰!'));
      case SkyIntent.bolt:
        _boltNext = false;
        final blocked = guarding || wall > 0;
        final d = _taken(_foeHit * HighlandRules.boltPower, bolt: true);
        hp = math.max(0, hp - d);
        out.add(SkyEvent(SkyEventKind.foeSpecial,
            value: d, big: !blocked, text: blocked ? '방어 태세로 낙뢰를 막아 냈어요!' : '낙뢰가 떨어졌어요!'));
      case SkyIntent.heal:
        healed = true;
        final v = math.min(foeMax - foeHp, math.max(1, (foeMax * HighlandRules.sunHeal).round()));
        foeHp += v;
        out.add(SkyEvent(SkyEventKind.foeHeal, value: v, text: '햇살이 쏟아져요! 수호자가 크게 회복했어요.'));
      case SkyIntent.armor:
        frost = HighlandRules.frostLength;
        out.add(const SkyEvent(SkyEventKind.foeSpecial, text: '서리 갑옷을 둘렀어요! 강타로 깨뜨려요.'));
        _normalHit(out);
      case SkyIntent.wash:
        final had = wall > 0;
        wall = 0;
        if (had) out.add(const SkyEvent(SkyEventKind.washed, text: '거센 물살에 좋은 효과가 씻겨 나갔어요!'));
        final d = _taken(_foeHit * SkyTurnRules.washHit);
        hp = math.max(0, hp - d);
        out.add(SkyEvent(SkyEventKind.foeSpecial, value: d, big: !guarding, text: guarding ? '방어 태세로 물살을 버텼어요!' : '거센 물살이 밀려와요!'));
    }
  }
}
