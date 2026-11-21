part of '../battle_rules.dart';

extension BattleSkills on Battle {
  double get bashRatio => (bashCharge / bashNeed).clamp(0, 1).toDouble();

  double get stanceRatio => (stanceCharge / stanceNeed).clamp(0, 1).toDouble();

  /// 강타
  bool useBash() {
    if (!bashReady) return false;
    bashCharge = 0;
    lastWasSkill = false;
    lastEvent = '강타!';
    // 묶음 50: 강타로 서리 갑옷을 깬다
    if (frostTurns > 0) {
      frostTurns = 0;
      lastEvent = '강타! 서리 갑옷이 깨졌어요!';
    }
    var dmg = (_vary(playerAttack) * Battle.bashMultiplier * (1 + bashBoost) * dealMult).round();
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    // 묶음 77 #346 마검사: 강타에 내 공격 속성이 실리고, 그 속성에 약하면 더
    final bashEl = weaponPotion ?? attackElement ?? (spellblade ? mainElement : null);
    dmg = _elemental(dmg, bashEl,
        level: weaponPotion != null ? 0 : attackLevel);
    if (spellblade && bashEl != null && ElementRules.multiplier(bashEl, foe.element) > 1) {
      dmg = (dmg * (1 + Battle.spellbladeWeak)).round();
    }
    lastDealt = dmg;
    lastTaken = 0;
    lastBash = true;
    bashes++;
    _used('bash');
    _hitFoe(dmg);
    _checkRage();
    return true;
  }

  /// 화면에 보여 줄 몬스터 약점 속성 (현자일 때만)
  Element? get shownWeakness => sage ? _foeWeakTo : null;

  /// 지금 몬스터가 잿빛 몬스터인지
  bool get foeIsAsh =>
      phase == BattlePhase.fighting && foe.monster.name.startsWith('ash');

  bool masteryReady(Mastery m) =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      masteryActives.contains(m) &&
      (masteryCharge[m] ?? 0) >= masteryNeedOf(m) &&
      !skillsLocked;

  double masteryRatio(Mastery m) =>
      ((masteryCharge[m] ?? 0) / masteryNeedOf(m))
          .clamp(0, 1)
          .toDouble();

  /// 몬스터가 약한 속성 하나 (없으면 null)
  Element? get _foeWeakTo {
    final e = foe.element;
    if (e == null) return null;
    final b = ElementRules.beats(e);
    return b.isEmpty ? null : b.first;
  }

  /// 스킬 한 번 치기
  int _strike(double mult,
      {Element? element, bool useElement = true, bool crit = false}) {
    var d = _vary(playerAttack) * mult * dealMult * _skillPower;
    if (foeBreakTurns > 0) d *= Battle.breakTaken;
    if (rallyTurns > 0) d *= Battle.rallyAttack;
    if (ashBoost > 0 && foeIsAsh) d *= 1 + ashBoost;
    if (boundBoost > 0 && foeBindTurns > 0) d *= 1 + boundBoost;
    var dmg = math.max(1, d.round());
    if (crit) {
      dmg = (dmg * StatRules.critMultiplier).round();
      lastCrit = true;
      if (practice) practiceCrits++;
    }
    if (practice) practiceStrikes++;
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    if (useElement) {
      final el = element ?? weaponPotion ?? attackElement;
      dmg = _elemental(dmg, el,
          level: element == null && weaponPotion == null ? attackLevel : 0);
    }
    lastDealt += dmg;
    _hitFoe(dmg);
    _setOnHit(dmg);
    _checkRage();
    _afterHit(dmg, skill: true);
    return dmg;
  }

  /// 묶음 57: 때린 뒤 각인 효과 (흡혈 · 묶기 · 독 · 펫)
  void _afterHit(int dmg, {bool skill = false}) {
    if (phase != BattlePhase.fighting) return;
    if (lifeSteal > 0 && playerHp < playerMaxHp) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp, playerHp + math.max(1, (dmg * lifeSteal).round()));
      _healed(playerHp - before);
    }
    if (bindChance > 0 && _rng.nextDouble() < bindChance) foeBindTurns = math.max(foeBindTurns, 1);
    if (lanternBurst > 0 && foeIsAsh && _rng.nextDouble() < lanternBurst && phase == BattlePhase.fighting) {
      final extra = math.max(1, (dmg * (lanternBurstMult - 1)).round());
      lastDealt += extra;
      _hitFoe(extra);
      lastEvent = '등불 빛이 터졌어요!';
      if (phase != BattlePhase.fighting) return;
    }
    if (skill && skillDot && foeDotTurns <= 0) {
      foeDotTurns = 3;
      foeDotRatio = 0.02;
    }
    if (petAssist > 0 && skillDamage > 0 && _rng.nextDouble() < petAssist) {
      _hitFoe(math.max(1, (skillDamage * 0.4).round()));
      _checkRage();
    }
  }

  void _startSkill(String event) {
    lastWasSkill = false;
    lastBash = true;
    lastDealt = 0;
    lastTaken = 0;
    lastCrit = false;
    lastSuper = false;
    lastResist = false;
    lastHealed = 0;
    lastEvent = event;
  }

  void _maybeStun(double chance) {
    if (phase == BattlePhase.fighting && _rng.nextDouble() < chance) {
      _foeBound = true;
      lastEvent = '${lastEvent ?? ''} 멈칫!'.trim();
    }
  }

  /// 직업 스킬을 쓴다 (MP는 앱이 따로 쓴다). [power] 는 스킬 단계 세기. 쓸 수 없으면 false
  bool useJobSkill(JobSkill s, {double power = 1}) {
    final ok = _useJobSkill(s, power: power);
    if (ok) {
      skillsUsed++;
      _used(s.name);
    }
    return ok;
  }

  bool _useJobSkill(JobSkill s, {double power = 1}) {
    if (phase != BattlePhase.fighting || skillsLocked) return false;
    final p = power;
    switch (s) {
      case JobSkill.ironWall:
        if (wallTurns > 0) return false;
        _startSkill('철벽!');
        wallTurns = 3;
        return true;
      case JobSkill.warCry:
        if (rallyTurns > 0) return false;
        _startSkill('전투 함성!');
        rallyTurns = 3;
        return true;
      default:
        break;
    }
    switch (s) {
      case JobSkill.hotHammer:
        _startSkill('달군 망치!');
        _strike(2.0 * p);
        foeBreakTurns = 3;
      case JobSkill.thornVine:
        _startSkill('가시덩굴!');
        _strike(1.2 * p);
        foeBindTurns = 2;
        foeDotTurns = 2;
        foeDotRatio = 0.03;
      case JobSkill.potionThrow:
        _startSkill('물약 투척!');
        final w = _foeWeakTo;
        _strike((w == null ? 1.5 : 2.0) * p, element: w);
      case JobSkill.rush:
        _startSkill('돌진!');
        _strike(2.2 * p);
      case JobSkill.galeSlash:
        _startSkill('질풍 베기!');
        _strike(1.4 * p);
        dodgeNext = true;
      case JobSkill.weakStab:
        _startSkill('약점 찌르기!');
        final w = _foeWeakTo;
        _strike((w == null ? 1.4 : 1.8) * p, element: w);
      case JobSkill.chargeOrder:
        _startSkill('돌격 명령!');
        _strike(1.0 * p * RuleConstants.skillDamageMultiplier,
            element: skillElement, useElement: skillElement != null);
        skillCharge = math.min(skillChargeTicks, skillCharge + 2);
      case JobSkill.coinToss:
        _startSkill('금화 던지기!');
        _strike(2.0 * p);
      // 묶음 77 #346: 마검사 · 현자
      case JobSkill.spellbladeSlash:
        _startSkill('마검 베기!');
        _strike(3.0 * p, element: _foeWeakTo ?? mainElement ?? attackElement);
      case JobSkill.sageStrike:
        _startSkill('현자의 일섬!');
        final w = _foeWeakTo;
        _strike((w != null ? 3.0 : 2.0) * p, element: w);
      case JobSkill.masterSlash:
        _startSkill('명검 베기!');
        _strike((1.6 + 0.1 * weaponEnhance) * p);
      case JobSkill.runeBurst:
        _startSkill('룬 폭발!');
        _strike(2.2 * p, element: attackElement, useElement: true);
      case JobSkill.gemShard:
        _startSkill('보석 파편!');
        _strike(1.4 * p);
        _maybeStun(0.30);
      case JobSkill.healingLight:
        _startSkill('치유의 빛!');
        final d = _strike(1.2 * p, element: Element.light);
        final before = playerHp;
        playerHp = math.min(playerMaxHp, playerHp + d);
        _healed(playerHp - before);
      case JobSkill.vitalStrike:
        _startSkill('급소 사격!');
        _strike(1.0 * p, crit: true);
      case JobSkill.relicLight:
        _startSkill('고대 유물의 빛!');
        _strike(1.2 * p, element: Element.light);
        blockNext = true;
      case JobSkill.blessedStrike:
        _startSkill('축복의 일격!');
        _strike(1.2 * p);
        regenTurns = 3;
      case JobSkill.bundleSwing:
        _startSkill('짐 보따리 휘두르기!');
        _strike(1.3 * p);
        _maybeStun(0.30);
      case JobSkill.counterSlash:
        _startSkill('반격 베기!');
        _strike(1.3 * p);
        reflectNext = true;
      case JobSkill.jointAttack:
        // 묶음 77 #344: 약 3배 = 나 1배 + 펫 2배
        _startSkill('합동 돌격!');
        _strike(1.0 * p);
        if (phase == BattlePhase.fighting) {
          _strike(2.0 * p, element: skillElement, useElement: skillElement != null);
        }
        skillCharge = math.min(skillChargeTicks, skillCharge + 2);
      case JobSkill.windBlade:
        _startSkill('바람 칼날!');
        _strike(1.5 * p, element: Element.wind);
        playerSpeed = math.max(playerSpeed, baseSpeed * 1.3);
      case JobSkill.poisonFlask:
        _startSkill('독 물약 뿌리기!');
        _strike(0.6 * p, element: Element.poison);
        foeDotTurns = 4;
        foeDotRatio = 0.03 * p;
      case JobSkill.shadowSlash:
        _startSkill('그림자 베기!');
        _strike((nightTime ? 1.8 : 1.4) * p, element: Element.dark);
        dodgeNext = true;
      case JobSkill.gatekeeperLight:
        _startSkill('문지기의 빛!');
        shieldHits += 3;
        _strike((foeIsAsh ? 3.0 : 1.2) * p, element: Element.light);
      case JobSkill.ashPurge:
        _startSkill('잿빛 정화!');
        _strike((foeIsAsh ? JobRules.ashPurge : 1.5) * p);
      case JobSkill.artisanCombo:
        _startSkill('장인의 연타!');
        for (var i = 0; i <= artisanSubs; i++) {
          if (phase != BattlePhase.fighting) break;
          _strike(0.8 * p);
        }
      default:
        return _useJobSkill57(s, p);
    }
    return true;
  }

  /// 묶음 59: 길드 레이드 특별 공격 (몇 턴마다)
  void _raidSpecial() {
    final id = raidBoss;
    if (id == null) return;
    if (raidShieldTurns > 0) raidShieldTurns--;
    if (raidShellTurns > 0) {
      raidShellTurns--;
      if (raidShellTurns == 0) {
        // 등껍질에서 나오며 크게 들이받음
        final d = math.max(1, (foe.attack * 2.2 * raidTakenMult).round());
        playerHp = math.max(0, playerHp - d);
        lastTaken = d;
        lastEvent = '등껍질에서 나와 들이받아요!';
        if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
        return;
      }
    }
    if (floorTicks % raidSpecialEvery != raidSpecialEvery - 1 || _specialTick == floorTicks) return;
    _specialTick = floorTicks;
    switch (id) {
      case 'raidGiant':
        // 빛 삼키기: 내 좋은 효과를 먹고 체력을 채움
        wardTurns = 0;
        stoneWallTurns = 0;
        nextHitMult = 1;
        foeHp = math.min(foe.maxHp, foeHp + math.max(1, (foe.maxHp * 0.04 / raidTakenMult.clamp(0.5, 1)).round()));
        lastEvent = '빛 삼키기! 거인이 빛을 먹었어요';
      case 'raidDragon':
        final d = math.max(1, (foe.attack * 1.8 * raidTakenMult).round());
        playerHp = math.max(0, playerHp - d);
        lastTaken = d;
        if (immuneTurns <= 0) burning = true;
        lastEvent = '불바다!';
        if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
      case 'raidLich':
        raidShieldTurns = 3;
        lastEvent = '망자의 방패! 해골 병사가 막아서요';
      case 'raidTortoise':
        raidShellTurns = 3;
        lastEvent = '등껍질 숨기!';
    }
  }

  void _partySpecial() {
    _raidSpecial();
    final id = foe.monster;
    if (id != MonsterId.partyGolem &&
        id != MonsterId.partyHydra &&
        id != MonsterId.partyWyvern &&
        id != MonsterId.partyKraken) {
      return;
    }
    if (floorTicks % Battle.partySpecialEvery != Battle.partySpecialEvery - 1 || _specialTick == floorTicks) return;
    _specialTick = floorTicks;
    switch (id) {
      case MonsterId.partyGolem:
        stoneWallTurns = 3;
        lastEvent = '돌벽!';
      case MonsterId.partyHydra:
        foeHp = math.min(foe.maxHp, foeHp + math.max(1, (foe.maxHp * 0.03).round()));
        lastEvent = '머리가 다시 자라요!';
      case MonsterId.partyWyvern:
        if (immuneTurns <= 0) {
          poisonTurns = 3;
          burning = false;
          weakPoisoned = false;
          poisonedThisBattle = true;
        }
        lastEvent = '잿빛 독침!';
      case MonsterId.partyKraken:
        frozen = true;
        lastEvent = '휘감기! 한 턴 움직일 수 없어요';
      default:
        break;
    }
  }

  void _hits(int n, double mult, {Element? element}) {
    for (var i = 0; i < n; i++) {
      if (phase != BattlePhase.fighting) break;
      _strike(mult, element: element, useElement: true);
    }
  }

  /// 묶음 57 #249: 새 스킬 32 중 전투 스킬
  bool _useJobSkill57(JobSkill s, double p) {
    switch (s) {
      case JobSkill.cleave:
        _startSkill('내려베기!');
        _strike(2.4 * p);
      case JobSkill.lastStand:
        _startSkill('결사의 일격!');
        final low = 1 - (playerHp / math.max(1, playerMaxHp));
        _strike((1.4 + 2.6 * low) * p);
      case JobSkill.rapidShot:
        _startSkill('속사!');
        _hits(2, 1.0 * p);
      case JobSkill.trapArrow:
        _startSkill('덫 화살!');
        _strike(1.2 * p);
        if (phase == BattlePhase.fighting) _foeBound = true;
      case JobSkill.starfallArrow:
        _startSkill('별똥별 화살!');
        _strike((foeHp >= foe.maxHp ? 4.0 : 1.6) * p);
      case JobSkill.elementBolt:
        _startSkill('속성 화살!');
        final w = _foeWeakTo;
        _strike(1.8 * p, element: w ?? attackElement);
      case JobSkill.manaShield:
        if (blockNext && shieldHits > 0) return false;
        _startSkill('마력 보호막!');
        blockNext = true;
        shieldHits = math.max(shieldHits, 1);
      case JobSkill.elementBurst:
        _startSkill('속성 폭발!');
        final weak = attackElement != null && _foeWeakTo == attackElement;
        _strike((weak ? 3.4 : 1.4) * p, element: attackElement);
      case JobSkill.grandMagic:
        _startSkill('대마법!');
        _strike(3.0 * p, element: _foeWeakTo ?? attackElement);
      case JobSkill.aegis:
        if (wardTurns > 0) return false;
        _startSkill('가호!');
        wardTurns = 3;
      case JobSkill.purify:
        _startSkill('정화!');
        poisonTurns = 0;
        burning = false;
        frozen = false;
        petrified = false;
        final before = playerHp;
        playerHp = math.min(playerMaxHp, playerHp + math.max(1, (playerMaxHp * 0.12 * p).round()));
        _healed(playerHp - before);
      case JobSkill.holyLight:
        _startSkill('성스러운 빛!');
        _strike((foeIsAsh ? 2.8 : 1.6) * p, element: Element.light);
      case JobSkill.miracle:
        if (_miracleUsed) return false;
        _startSkill('기적!');
        _miracleUsed = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp, playerHp + (playerMaxHp * 0.45 * p).round());
        _healed(playerHp - before);
        revives += 1;
      case JobSkill.ambush:
        _startSkill('기습!');
        _hits(2, 1.1 * p);
      case JobSkill.steal:
        _startSkill('훔치기!');
        _strike(1.2 * p);
        extraLoot = true;
      case JobSkill.poisonBlade:
        _startSkill('독 바르기!');
        _strike(1.0 * p, element: Element.poison);
        foeDotTurns = 4;
        foeDotRatio = 0.035 * p;
      case JobSkill.smokeBomb:
        if (dodgeNext) return false;
        _startSkill('연막!');
        dodgeNext = true;
      case JobSkill.shadowFlurry:
        _startSkill('그림자 연격!');
        _hits(nightThief && nightTime ? 6 : 5, 0.65 * p);
      case JobSkill.shieldBash:
        _startSkill('방패 치기!');
        _strike(1.4 * p);
        foeBreakTurns = math.max(foeBreakTurns, 2);
      case JobSkill.guard:
        if (blockNext) return false;
        _startSkill('수호!');
        blockNext = true;
        _guardCounter = true;
      case JobSkill.taunt:
        if (tauntTurns > 0) return false;
        _startSkill('도발!');
        tauntTurns = 3;
      case JobSkill.lanceCharge:
        _startSkill('창 돌격!');
        _strike(2.3 * p);
        playerSpeed = math.max(playerSpeed, baseSpeed * 1.3);
      case JobSkill.paladinOath:
        if (tauntTurns > 0) return false;
        _startSkill('성기사의 맹세!');
        shieldHits += 2;
        tauntTurns = 3;
      case JobSkill.anvilDrop:
        _startSkill('모루 내려찍기!');
        _strike(2.0 * p);
        _maybeStun(0.30);
      case JobSkill.acidFlask:
        _startSkill('산성 플라스크!');
        _strike(1.2 * p, element: Element.poison);
        foeBreakTurns = math.max(foeBreakTurns, 2);
        foeDotTurns = 3;
        foeDotRatio = 0.025 * p;
      case JobSkill.pollenCloud:
        _startSkill('꽃가루 날리기!');
        _strike(1.3 * p, element: Element.earth);
        dodgeNext = true;
      case JobSkill.dazzleLens:
        _startSkill('눈부신 렌즈!');
        _strike(1.4 * p, element: Element.light);
        if (phase == BattlePhase.fighting) _foeBound = true;
      case JobSkill.scaleWeight:
        _startSkill('저울추 던지기!');
        _strike(2.0 * p);
        goldBonus = true;
      case JobSkill.whistleSignal:
        _startSkill('휘파람 신호!');
        for (var i = 0; i < 2; i++) {
          if (phase != BattlePhase.fighting) break;
          _strike(1.0 * p * RuleConstants.skillDamageMultiplier,
              element: skillElement, useElement: skillElement != null);
        }
        skillCharge = math.min(skillChargeTicks, skillCharge + 2);
      default:
        return false;
    }
    return true;
  }

  /// 숙련 스킬 (MP 없이 몇 턴마다)
  bool useMasterySkill(Mastery m) {
    if (!masteryReady(m)) return false;
    _skillPower = masteryPower[m] ?? 1;
    try {
      _useMasterySkill(m);
    } finally {
      _skillPower = 1;
    }
    _used('m_${m.name}');
    return true;
  }

  void _useMasterySkill(Mastery m) {
    skillsUsed++;
    masteryCharge[m] = 0;
    _startSkill('${JobRules.masteryActive(m).name}!');
    switch (m) {
      case Mastery.smith:
        _strike(2.4);
      case Mastery.harvest:
        _strike(1.3);
        foeBindTurns = math.max(foeBindTurns, 1);
      case Mastery.alchemy:
        _strike(1.5, element: Element.fire);
        foeBurnTurns = 3;
      case Mastery.combat:
        for (var i = 0; i < 3; i++) {
          if (phase != BattlePhase.fighting) break;
          _strike(0.6);
        }
      case Mastery.walk:
        _strike(1.5);
        playerSpeed = math.max(playerSpeed, baseSpeed * 1.3);
      case Mastery.appraise:
        final w = _foeWeakTo;
        _strike(w == null ? 1.4 : 1.6, element: w);
      case Mastery.spirit:
        _strike(1.8, element: Element.light);
      case Mastery.trade:
        _strike(1.5);
    }
  }
}
