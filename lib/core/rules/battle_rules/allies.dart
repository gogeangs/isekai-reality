part of '../battle_rules.dart';

extension BattleAllies on Battle {
  List<BattleAlly> get alliesUp => [for (final a in allies) if (!a.down) a];

  double get _allyFoeMult {
    var m = partyAtkTurns > 0 ? partyAtkMult : 1.0;
    if (lampTurns > 0 && (foeIsAsh || foe.element == Element.dark)) m *= lampMult;
    return m;
  }

  /// 동료 한 명의 보통 공격
  void _allyHit(BattleAlly a, double mult, {bool crit = false, Element? element}) {
    if (phase != BattlePhase.fighting || a.down) return;
    var d = _vary(a.attack) * mult * _allyFoeMult;
    if (a.selfAtkTurns > 0) d *= 1.5;
    if (a.ash > 0 && foeIsAsh) d *= 1 + a.ash;
    final el = element ?? a.element;
    if (el != null && a.elementBonus == el) d *= 1.15;
    if (crit || (a.crit > 0 && _rng.nextDouble() < a.crit)) d *= StatRules.critMultiplier;
    var dmg = math.max(1, d.round());
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    if (foeBreakTurns > 0) dmg = (dmg * Battle.breakTaken).round();
    if (el != null) dmg = _elemental(dmg, el, level: 0);
    a.lastDealt += dmg;
    _hitFoe(dmg);
    _checkRage();
  }

  /// 동료들이 차례로 친다 (각성자 차례 뒤)
  void _alliesTurn() {
    for (final a in allies) {
      a.lastDealt = 0;
      a.lastTaken = 0;
      if (a.down || phase != BattlePhase.fighting) continue;
      final next = partyNext;
      _allyHit(a, next);
      if (a.charge < a.chargeTicks) a.charge++;
    }
    partyNext = 1;
  }

  /// 동료 스킬 (게이지가 차면 누름). 쓸 수 없으면 false
  bool useAllySkill(int i) {
    if (i < 0 || i >= allies.length || phase != BattlePhase.fighting) return false;
    final a = allies[i];
    final s = a.skill;
    if (!a.ready || s == null) return false;
    a.charge = 0;
    lastAllySkill = '${a.name} · ${s.name}!';
    lastEvent = lastAllySkill;
    switch (s.kind) {
      case AllySkillKind.hit:
        _allyHit(a, s.power);
      case AllySkillKind.hits:
        for (var k = 0; k < s.hits; k++) {
          _allyHit(a, s.power);
        }
      case AllySkillKind.crit:
        _allyHit(a, s.power, crit: true);
      case AllySkillKind.stun:
        _allyHit(a, s.power);
        _foeBound = true;
      case AllySkillKind.partyAtk:
        partyAtkTurns = s.turns;
        partyAtkMult = s.power;
        rallyTurns = math.max(rallyTurns, s.turns);
      case AllySkillKind.partyDef:
        partyDefTurns = s.turns;
        partyDefMult = s.power;
      case AllySkillKind.partyNext:
        partyNext = s.power;
        nextHitMult = math.max(nextHitMult, s.power);
      case AllySkillKind.lamp:
        lampTurns = s.turns;
        lampMult = s.power;
      case AllySkillKind.partyCount:
        final n = 1 + alliesUp.length;
        for (var k = 0; k < n; k++) {
          _allyHit(a, s.power);
        }
      case AllySkillKind.rally:
        partyAtkTurns = s.turns;
        partyAtkMult = s.power;
        partyDefTurns = s.turns;
        partyDefMult = 0.7;
        rallyTurns = math.max(rallyTurns, s.turns);
        if (heroSkills) bashCharge = bashNeed;
      case AllySkillKind.selfAtk:
        a.selfAtkTurns = s.turns;
      case AllySkillKind.lowHp:
        _allyHit(a, s.power * (1 + (1 - a.hp / a.maxHp) * 1.5));
      case AllySkillKind.fullHp:
        _allyHit(a, foeHp >= foe.maxHp ? s.power : s.power * 0.4);
      case AllySkillKind.element:
        _allyHit(a, s.power, element: a.element ?? a.elementBonus);
      case AllySkillKind.weak:
        final el = a.element ?? a.elementBonus;
        final e = foe.element;
        final weak = el != null && e != null && ElementRules.beats(el).contains(e);
        _allyHit(a, weak ? s.power : s.power * 0.45, element: el);
      case AllySkillKind.barrier:
        dodgeNext = true;
      case AllySkillKind.healOne:
        _healOne(s.power * (1 + a.heal));
      case AllySkillKind.healAll:
        _healAll(s.power * (1 + a.heal));
      case AllySkillKind.regen:
        regenTurns = math.max(regenTurns, s.turns);
      case AllySkillKind.cleanse:
        poisonTurns = 0;
        frozen = false;
        petrified = false;
        _healAll(0.05 * (1 + a.heal));
      case AllySkillKind.miracle:
        for (final x in allies) {
          if (x.down && !x.revived) {
            x.revived = true;
            x.hp = math.max(1, (x.maxHp * 0.3).round());
            break;
          }
        }
        _healAll(s.power * (1 + a.heal));
      case AllySkillKind.steal:
        _allyHit(a, s.power);
        extraLoot = true;
      case AllySkillKind.poison:
        _allyHit(a, 0.6);
        foeDotTurns = s.turns;
        foeDotRatio = s.power;
      case AllySkillKind.breakDef:
        _allyHit(a, s.power);
        foeBreakTurns = math.max(foeBreakTurns, 2);
      case AllySkillKind.taunt:
        a.tauntTurns = s.turns;
      case AllySkillKind.guardSelf:
        a.guardTurns = s.turns;
      case AllySkillKind.oath:
        shieldHits += 2;
        counterTurns = s.turns;
    }
    return true;
  }

  void _healOne(double ratio) {
    // 가장 많이 다친 쪽 (각성자 포함)
    BattleAlly? low;
    var lowRatio = playerHp / playerMaxHp;
    for (final x in alliesUp) {
      final r = x.hp / x.maxHp;
      if (r < lowRatio) {
        low = x;
        lowRatio = r;
      }
    }
    if (low == null) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp, playerHp + (playerMaxHp * ratio).round());
      _healed(playerHp - before);
    } else {
      low.hp = math.min(low.maxHp, low.hp + (low.maxHp * ratio).round());
    }
  }

  void _healAll(double ratio) {
    final before = playerHp;
    playerHp = math.min(playerMaxHp, playerHp + (playerMaxHp * ratio).round());
    _healed(playerHp - before);
    for (final x in alliesUp) {
      x.hp = math.min(x.maxHp, x.hp + (x.maxHp * ratio).round());
    }
  }

  /// 몬스터 공격이 동료에게 갔으면 그 동료 (각성자면 null). 대신 맞는 동료가 먼저
  BattleAlly? _foeTarget() {
    final up = alliesUp;
    if (up.isEmpty) return null;
    for (final a in up) {
      if (a.tauntTurns > 0) return a;
    }
    if (_rng.nextDouble() >= Act3Rules.foeTargetsAlly) return null;
    return up[_rng.nextInt(up.length)];
  }

  /// 동료가 맞는다
  void _allyTaken(BattleAlly a, double atk) {
    var x = atk;
    if (partyDefTurns > 0) x *= partyDefMult;
    if (a.guardTurns > 0) x *= 0.4;
    final taken = _vary(math.max(1, x.round()));
    a.hp = math.max(0, a.hp - taken);
    a.lastTaken += taken;
    if (counterTurns > 0) _allyHit(a, 0.5);
  }

  /// 틱 끝: 동료 쪽 남은 턴
  void _alliesTickEnd() {
    if (partyAtkTurns > 0) partyAtkTurns--;
    if (partyDefTurns > 0) partyDefTurns--;
    if (lampTurns > 0) lampTurns--;
    if (counterTurns > 0) counterTurns--;
    for (final a in allies) {
      if (a.selfAtkTurns > 0) a.selfAtkTurns--;
      if (a.guardTurns > 0) a.guardTurns--;
      if (a.tauntTurns > 0) a.tauntTurns--;
      if (regenTurns > 0 && !a.down) {
        a.hp = math.min(a.maxHp, a.hp + math.max(1, (a.maxHp * 0.04).round()));
      }
    }
  }
}
