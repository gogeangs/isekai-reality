part of '../battle_rules.dart';

extension BattleTurns on Battle {
  int potionLeft(String key) => _potionLeft[key] ?? 0;

  /// 물약을 마신다 (전투 한 번에 3개까지)
  bool drink(String key) {
    final p = potions[key];
    if (p == null || potionLeft(key) <= 0 || isOver) return false;
    if (potionsDrunk >= AlchemyRules.perBattle) return false;
    switch (p.cure) {
      case CureKind.poison:
        if (poisonTurns <= 0 || burning) return false;
        poisonTurns = 0;
        immuneTurns = 3;
      case CureKind.burn:
        if (poisonTurns <= 0 || !burning) return false;
        poisonTurns = 0;
        immuneTurns = 3;
      case CureKind.dazzle:
        if (clearEye) return false;
        clearEye = true;
      case CureKind.freeze:
        if (!frozen) return false;
        frozen = false;
        petrified = false;
        freezeImmune = 3;
      case null when p.jobMpRatio > 0:
        // 묶음 82 #392: 직업 MP 마나 물약
        final now = jobMpNow?.call();
        if (now == null || jobMpMax <= 0 || now >= jobMpMax) return false;
        onJobMp?.call(math.min(jobMpMax - now, math.max(1, (jobMpMax * p.jobMpRatio).round())));
      case null:
        if (p.hpRatio <= 0 || playerHp >= playerMaxHp) return false;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + (playerMaxHp * p.hpRatio * (1 + healBoost)).round());
        _healed(playerHp - before);
        if (potionShare > 0) {
          for (final a in allies) {
            if (a.hp > 0) a.hp = math.min(a.maxHp, a.hp + math.max(1, (a.maxHp * potionShare).round()));
          }
        }
    }
    _potionLeft[key] = potionLeft(key) - 1;
    potionsUsed[key] = (potionsUsed[key] ?? 0) + 1;
    lastEvent = '${p.name}!';
    return true;
  }

  /// 자동으로 마실 물약이 있으면 마신다
  void _autoDrink() {
    autoHealed = false;
    autoCured = false;
    autoManaed = false;
    if (isOver) return;
    final before = potionsDrunk;
    if (autoCure && poisonTurns > 0) {
      final kind = burning ? CureKind.burn : CureKind.poison;
      for (final p in potions.values) {
        if (p.cure == kind && drink(p.key)) break;
      }
    }
    if (autoCure && frozen) {
      for (final p in potions.values) {
        if (p.cure == CureKind.freeze && drink(p.key)) break;
      }
    }
    if (autoCure &&
        !clearEye &&
        floors[floor].trait == MonsterTrait.dazzle) {
      for (final p in potions.values) {
        if (p.cure == CureKind.dazzle && drink(p.key)) break;
      }
    }
    // 묶음 82 #392: 한 턴에 하나 — 상태 이상 → HP → MP
    if (potionsDrunk > before) {
      autoCured = true;
      return;
    }
    if (autoHp > 0 && playerHp * 100 < playerMaxHp * autoHp) {
      // 작은 것부터
      final heals = [
        for (final p in potions.values)
          if (p.cure == null && p.hpRatio > 0 && potionLeft(p.key) > 0) p,
      ]..sort((a, b) => a.hpRatio.compareTo(b.hpRatio));
      if (heals.isNotEmpty && drink(heals.first.key)) {
        autoHealed = true;
        return;
      }
    }
    final jm = jobMpNow?.call();
    if (autoMp > 0 && jm != null && jobMpMax > 0 && jm * 100 < jobMpMax * autoMp) {
      final manas = [
        for (final p in potions.values)
          if (p.jobMpRatio > 0 && potionLeft(p.key) > 0) p,
      ]..sort((a, b) => a.jobMpRatio.compareTo(b.jobMpRatio));
      // 마나 물약이 없으면 그냥 건너뜀
      if (manas.isNotEmpty && drink(manas.first.key)) autoManaed = true;
    }
  }

  bool get skillDisabled => skillChargeTicks >= Battle.skillUnavailable;

  /// 지금 층 몬스터에게 준 피해 (파티 보스: 한 판에 준 피해)
  int get dealtToFoe => math.max(0, foe.maxHp - foeHp);

  Foe get foe => floors[floor];

  bool get isOver =>
      phase == BattlePhase.cleared ||
      phase == BattlePhase.failed ||
      phase == BattlePhase.escaped;

  bool get skillReady =>
      phase == BattlePhase.fighting &&
      skillCharge >= skillChargeTicks &&
      !isolated;

  double get skillRatio =>
      (skillCharge / skillChargeTicks).clamp(0, 1).toDouble();

  /// 정화한 몬스터 (층 순서)
  List<MonsterId> get purified => [
        for (var i = 0; i < floors.length; i++)
          if (i < floor ||
              (i == floor &&
                  (phase == BattlePhase.floorCleared ||
                      phase == BattlePhase.cleared)))
            floors[i].monster,
      ];

  int _vary(int base) {
    final factor = 0.9 + _rng.nextDouble() * 0.2;
    return math.max(1, (base * factor).round());
  }

  void tick() {
    if (isOver) return;
    if (phase == BattlePhase.floorCleared) {
      floor++;
      foeHp = foe.maxHp;
      phase = BattlePhase.fighting;
      floorTicks = 0;
      _charged = false;
      _foeBound = false;
      _foeFrozen = false;
      foeBurnTurns = 0;
      foeBreakTurns = 0;
      foeBindTurns = 0;
      foeDotTurns = 0;
      enraged = false;
      _guard = null;
      lastDealt = 0;
      lastTaken = 0;
      lastWasSkill = false;
      lastEvent = null;
      _clearAshMoves();
      // 묶음 34: 잿빛 군주는 감정 단계가 바뀔 때 한 줄
      lastMove = foe.move == null ? null : Act2Rules.ofMove(foe.move!)?.kingLine;
      _prepareStrong();
      return;
    }
    ticks++;
    floorTicks++;
    // 묶음 56: 파티 보스 한 판은 정해진 턴까지 (그때까지 준 피해만 셈)
    if (tickLimit != null && ticks > tickLimit!) {
      timeUp = true;
      phase = BattlePhase.escaped;
      return;
    }
    lastWasSkill = false;
    lastBash = false;
    lastGuard = null;
    lastGuardBroken = false;
    lastEvent = null;
    // 묶음 58: 이름 있는 장비 회복 (숨김)
    if (regenChance > 0 && playerHp > 0 && playerHp < playerMaxHp && _rng.nextDouble() < regenChance) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp, playerHp + math.max(1, (playerMaxHp * regenRatio).round()));
      _healed(playerHp - before);
    }
    if (allyRegenChance > 0 && _rng.nextDouble() < allyRegenChance) {
      for (final a in allies) {
        if (a.hp > 0) a.hp = math.min(a.maxHp, a.hp + math.max(1, (a.maxHp * Battle.regenRatioAlly).round()));
      }
    }
    lastCrit = false;
    lastSuper = false;
    lastResist = false;
    lastHealed = 0;
    lastMove = null;
    lastAllySkill = null;
    if (skillLockTurns > 0) skillLockTurns--;
    _ashMove();
    lastDealt = 0;
    // 묶음 57 #244: 이그니스(드래곤)와 함께면 싸움을 시작할 때 불을 한 번 뿜음
    if (openingFire > 0 && ticks == 1 && !practice) {
      final d = _elemental(math.max(1, (_vary(playerAttack) * openingFire).round()), Element.fire);
      _hitFoe(d);
      foeBurnTurns = math.max(foeBurnTurns, PetRules.dragonOpeningBurn);
      lastEvent = '이그니스가 불을 뿜었어요!';
      _checkRage();
      if (isOver) return;
    }
    lastTaken = 0;
    // 이번 틱의 몬스터 첫 공격이 예고된 강한 공격인지
    _strongNow = _strongNext;
    _strongNowMult = _strongNextMult;
    _strongNext = false;
    final f = foe;
    final foeFirst = f.has(ModifierId.hungry) ||
        f.speed * (enraged ? Battle.bossRageSpeed : 1) > playerSpeed;

    if (foeFirst) {
      _foeTurn();
      if (isOver) return;
    }

    // 번개 같은: 첫 턴에 한 번 더 공격
    if (foeFirst && f.has(ModifierId.lightning) && floorTicks == 1) {
      _foeTurn();
      if (isOver) return;
    }

    // 각성자 차례
    if (frozen) {
      frozen = false;
      lastEvent = petrified ? '돌처럼 굳어 움직일 수 없어요!' : '얼어서 움직일 수 없어요!';
      petrified = false;
    } else if (f.has(ModifierId.bewitching) && _rng.nextDouble() < 0.25) {
      lastEvent = '홀렸어요!';
    } else if (f.has(ModifierId.nimble) && _rng.nextDouble() < 0.20) {
      lastEvent = '피했어요!';
    } else if (f.has(ModifierId.lightning) && _rng.nextDouble() < 0.25) {
      lastEvent = '피했어요!';
    } else if (f.trait == MonsterTrait.evade && _rng.nextDouble() < 0.15) {
      lastEvent = '피했어요!';
    } else if (f.trait == MonsterTrait.dazzle &&
        !clearEye &&
        _rng.nextDouble() < 0.25) {
      lastEvent = '눈부셔요!';
    } else if (tearTurns > 0 && _rng.nextDouble() < Act2Rules.tearsMiss) {
      lastEvent = '빗나갔어요!';
    } else {
      var dmg = _jobHit(_vary(playerAttack));
      if (insightTurns > 0) {
        dmg = (dmg * (1 + PetRules.insightBonus(adult: petAdult))).round();
        insightTurns--;
      }
      final crit = playerCrit + (firstStrike && floorTicks <= 1 ? 0.15 : 0);
      if (nextCrit || (crit > 0 && _rng.nextDouble() < crit)) {
        nextCrit = false;
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
        lastCrit = true;
      }
      if (f.defense != 1) dmg = math.max(1, (dmg / f.defense).round());
      dmg = _elemental(dmg, weaponPotion ?? attackElement,
          level: weaponPotion != null ? 0 : attackLevel);
      if (f.has(ModifierId.sturdy) && _rng.nextDouble() < 0.20) {
        dmg = math.max(1, dmg ~/ 2);
        lastEvent = '웅크렸어요!';
      }
      lastDealt = dmg;
      _hitFoe(dmg);
      _inflict();
      _setOnHit(dmg);
      _checkRage();
      _afterHit(dmg);
      // 묶음 57: 도적 각인 — 가끔 한 번 더
      if (doubleHit > 0 && phase == BattlePhase.fighting && _rng.nextDouble() < doubleHit) {
        final d2 = math.max(1, (dmg * 0.6).round());
        lastDealt += d2;
        _hitFoe(d2);
        _checkRage();
      }
    }
    if (phase != BattlePhase.fighting) return;

    // 묶음 52 #243: 3막 동료들이 차례로 친다
    if (allies.isNotEmpty) {
      _alliesTurn();
      if (phase != BattlePhase.fighting) return;
    }

    if (!foeFirst) {
      _foeTurn();
      if (isOver) return;
      if (f.has(ModifierId.lightning) && floorTicks == 1) {
        _foeTurn();
        if (isOver) return;
      }
    }

    // 작은 불씨: 몬스터 화상 (최대 체력 2%)
    if (foeBurnTurns > 0) {
      foeBurnTurns--;
      _hitFoe(math.max(1, (f.maxHp * 0.02).round()));
      if (phase != BattlePhase.fighting) return;
    }

    // 묶음 31: 가시덩굴·독 물약 계속 피해
    if (foeDotTurns > 0) {
      foeDotTurns--;
      _hitFoe(math.max(1, (f.maxHp * foeDotRatio).round()));
      if (phase != BattlePhase.fighting) return;
    }

    // 묶음 34 눈물비: 그사이 스스로 회복
    if (tearTurns > 0) {
      tearTurns--;
      if (foeHp < f.maxHp) {
        foeHp = math.min(
            f.maxHp, foeHp + math.max(1, (f.maxHp * Act2Rules.tearsHeal).round()));
      }
    }
    if (stolenTurns > 0) stolenTurns--;
    // 물 슬라임: 매 턴 끝에 5% 회복
    if (f.trait == MonsterTrait.regen && foeHp < f.maxHp) {
      foeHp = math.min(f.maxHp, foeHp + math.max(1, (f.maxHp * 0.05).round()));
    }

    // 중독·화상
    if (poisonTurns > 0) {
      final p = math.max(
          1, (playerMaxHp * (weakPoisoned && !burning ? 0.01 : 0.02)).round());
      poisonTurns--;
      lastTaken += p;
      playerHp = math.max(0, playerHp - p);
      if (playerHp == 0 && !_revive()) {
        phase = BattlePhase.failed;
        return;
      }
    }

    // 황금빛: 3턴 안에 못 잡으면 도망
    if (f.has(ModifierId.golden) && floorTicks >= 3) {
      phase = BattlePhase.escaped;
      lastEvent = '도망쳤어요!';
      return;
    }
    if (immuneTurns > 0) immuneTurns--;
    if (freezeImmune > 0) freezeImmune--;
    if (stanceTurns > 0) stanceTurns--;
    if (wallTurns > 0) wallTurns--;
    if (wardTurns > 0) wardTurns--;
    if (stoneWallTurns > 0) stoneWallTurns--;
    if (tauntTurns > 0) tauntTurns--;
    if (foeBreakTurns > 0) foeBreakTurns--;
    if (regenTurns > 0 && playerHp < playerMaxHp) {
      regenTurns--;
      final before = playerHp;
      playerHp = math.min(
          playerMaxHp, playerHp + math.max(1, (playerMaxHp * 0.04).round()));
      _healed(playerHp - before);
    } else if (regenTurns > 0) {
      regenTurns--;
    }
    // 고목 세트 6개: 매 턴 HP 조금 회복 (11-11 #82)
    if (setAbilities.contains(BossSetAbility.regrow) && playerHp < playerMaxHp) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp,
          playerHp + math.max(1, (playerMaxHp * BossGearRules.regrowRatio).round()));
      _healed(playerHp - before);
      setProcs++;
    }
    _autoDrink();
    // 묶음 34 고립: 그동안 펫 게이지가 멈춘다
    if (isolateTurns > 0) {
      isolateTurns--;
    } else if (skillCharge < skillChargeTicks) {
      skillCharge++;
    }
    if (heroSkills) {
      if (bashCharge < bashNeed) bashCharge++;
      // 묶음 57: 전사 — 강타가 더 빨리 참 (두 턴에 한 번 더)
      if (bashFast && floorTicks.isEven && bashCharge < bashNeed) bashCharge++;
      // 전투 함성: 강타가 더 빨리 참
      if (rallyTurns > 0 && bashCharge < bashNeed) bashCharge++;
      if (stanceCharge < stanceNeed) stanceCharge++;
      for (final m in masteryActives) {
        final c = masteryCharge[m] ?? 0;
        if (c < masteryNeedOf(m)) masteryCharge[m] = c + 1;
      }
    }
    if (rallyTurns > 0) rallyTurns--;
    if (allies.isNotEmpty) _alliesTickEnd();
    _guard = null;
    _prepareStrong();
  }

  void _foeTurn() {
    if (practice) return;
    final f = foe;
    _partySpecial();
    if (isOver) return;
    if (foeBindTurns > 0) {
      foeBindTurns--;
      lastEvent = '묶였어요!';
      return;
    }
    if (dodgeNext) {
      dodgeNext = false;
      lastEvent = '피했어요!';
      return;
    }
    if (blockNext && _strongNow) {
      blockNext = false;
      _strongNow = false;
      lastEvent = '막았다!';
      // 묶음 57 수호: 막고 되받아침
      if (tauntTurns > 0 || _guardCounter) {
        _guardCounter = false;
        _hitFoe(math.max(1, _vary(playerAttack)));
        _checkRage();
      }
      return;
    }
    if (relicBlock > 0 && _strongNow && _rng.nextDouble() < relicBlock) {
      _strongNow = false;
      lastEvent = '고대 유물이 막았다!';
      return;
    }
    if (_foeBound) {
      _foeBound = false;
      lastEvent = '묶였어요!';
      return;
    }
    if (_foeFrozen) {
      _foeFrozen = false;
      lastEvent = '얼어서 움직이지 못해요!';
      return;
    }
    if (playerEvade + extraEvade > 0 && _rng.nextDouble() < playerEvade + extraEvade) {
      lastEvent = '회피!';
      return;
    }
    var atk = f.attack.toDouble();
    // 묶음 69 #281: 도플갱어 — 첫 공격은 내 공격을 따라 함 · 웨어울프 — 보름달 밤엔 더 셈
    if (f.trait == MonsterTrait.mirror && !_mirrored) {
      _mirrored = true;
      atk = math.max(atk, playerAttack * Battle.mirrorShare);
      lastEvent = '내 공격을 따라 했어요!';
    }
    if (f.trait == MonsterTrait.moon && fullMoon) atk *= Battle.fullMoonAttack;
    // 11-11 #75: 예고한 강한 공격 (그 틱의 첫 공격만)
    final strong = _strongNow;
    if (strong) {
      atk *= _strongNowMult;
      _strongNow = false;
    }
    if (enraged) atk *= Battle.bossRageAttack;
    // 묶음 34: 분노 폭발 · 빼앗은 힘 · 유품 세트
    if (f.move == AshMove.rage) {
      atk *= 1 + Act2Rules.rageMax * (1 - foeHp / f.maxHp);
    }
    if (stolenTurns > 0) atk *= Act2Rules.stolenAttack;
    // 묶음 52 #243: 3막 동료가 있으면 가끔 동료를 노린다 (대신 맞는 동료가 먼저)
    if (allies.isNotEmpty) {
      final target = _foeTarget();
      if (target != null) {
        _allyTaken(target, atk);
        if (target.down) lastEvent = '동료가 쓰러졌어요!';
        return;
      }
    }
    if (ashTaken > 0 && foeIsAsh) atk *= 1 - ashTaken;
    if (skyTaken > 0 &&
        f.element != null &&
        HighlandRules.skyElements.contains(f.element)) {
      atk *= 1 - skyTaken;
    }
    if (stanceTurns > 0) atk *= Battle.stanceTaken;
    if (wallTurns > 0) atk *= Battle.wallTaken;
    if (wardTurns > 0) atk *= Battle.wardTaken;
    if (partyDefTurns > 0) atk *= partyDefMult;
    if (f.has(ModifierId.enraged) && foeHp * 2 < f.maxHp) atk *= 1.5;
    if (f.has(ModifierId.charging) && !_charged) {
      atk *= 2;
      _charged = true;
      lastEvent = '돌진!';
    }
    if (f.has(ModifierId.ancient) && floorTicks % 4 == 0) {
      atk *= 2.5;
      lastEvent = '강타!';
    }
    if (damageTaken != 1) atk *= damageTaken;
    if (takenMult != 1) atk *= takenMult;
    final element = f.element;
    if (element != null && (resist[element] ?? 0) > 0) {
      atk *= 1 - resist[element]!;
    }
    if (element != null && elementGuard > 0) atk *= 1 - elementGuard;
    // 방어 속성 장비·주 속성 (11-11 #63, 숫자는 숨김)
    if (element != null) {
      if (guardElements.contains(element)) {
        atk *= SmithRules.guardAt(guardLevels[element] ?? 0);
      }
      if (element == mainElement) atk *= 1 - ElementRules.mainBonus;
    }
    if (shieldHits > 0) {
      atk *= 0.5;
      shieldHits--;
      lastEvent ??= '보호막!';
    }
    // 문지기 세트 6개: 돌 피부 (11-11 #82, 숨김)
    if (setAbilities.contains(BossSetAbility.stoneSkin) &&
        _rng.nextDouble() < BossGearRules.stoneSkinChance) {
      atk *= 0.5;
      setProcs++;
      lastEvent ??= '돌 피부!';
    }
    // 막기 (11-11 #75): 막기는 받는 피해 -60%, 완벽한 막기는 피해 없음 + 반격
    if (strong && _guard == null) lastGuardBroken = true;
    if (strong && _guard != null) {
      final g = _guard!;
      _guard = null;
      lastGuard = g;
      guards++;
      if (g == GuardResult.perfect) {
        lastEvent = '완벽한 막기!';
        final counterDmg = _vary(playerAttack);
        lastDealt = counterDmg;
        _hitFoe(counterDmg);
        _checkRage();
        if (guardFlash > 0) _maybeStun(guardFlash);
        return;
      }
      atk *= Battle.blockTaken;
      lastEvent = '막았다!';
      if (guardFlash > 0) _maybeStun(guardFlash);
    }
    final taken = _vary(math.max(1, atk.round()));
    lastTaken += taken;
    playerHp = math.max(0, playerHp - taken);
    // 반격 베기: 받은 공격 일부를 돌려줌
    if (reflectNext) {
      reflectNext = false;
      _hitFoe(math.max(1, (taken * 0.5).round()));
      if (phase != BattlePhase.fighting) return;
    }
    // 묶음 57 도발 · 성기사의 맹세: 맞을 때마다 되받아침
    if (tauntTurns > 0) {
      _hitFoe(math.max(1, (taken * 0.6 + playerAttack * 0.4).round()));
      if (paladin) {
        playerHp = math.min(playerMaxHp, playerHp + math.max(1, (playerMaxHp * 0.03).round()));
        if (foeIsAsh) _hitFoe(math.max(1, (playerAttack * 0.5).round()));
      }
      _checkRage();
      if (phase != BattlePhase.fighting) return;
    }
    if ((f.has(ModifierId.venomous) ||
            f.has(ModifierId.plagued) ||
            f.trait == MonsterTrait.poison) &&
        immuneTurns <= 0 &&
        _rng.nextDouble() < 0.30) {
      poisonTurns = 3;
      burning = false;
      weakPoisoned = false;
      poisonedThisBattle = true;
      lastEvent = '중독!';
    } else if (f.trait == MonsterTrait.weakPoison &&
        immuneTurns <= 0 &&
        poisonTurns <= 0 &&
        _rng.nextDouble() < Battle.weakPoisonChance) {
      poisonTurns = 2;
      burning = false;
      weakPoisoned = true;
      poisonedThisBattle = true;
      lastEvent = '중독!';
    }
    if (f.trait == MonsterTrait.freeze &&
        freezeImmune <= 0 &&
        !frozen &&
        playerHp > 0 &&
        _rng.nextDouble() < Battle.freezeChance) {
      frozen = true;
      lastEvent = '얼어붙었어요!';
    }
    if (f.trait == MonsterTrait.petrify &&
        freezeImmune <= 0 &&
        !frozen &&
        playerHp > 0 &&
        _rng.nextDouble() < Battle.petrifyChance) {
      frozen = true;
      petrified = true;
      lastEvent = '돌로 굳었어요!';
    }
    if (f.trait == MonsterTrait.burn &&
        immuneTurns <= 0 &&
        _rng.nextDouble() < 0.30) {
      poisonTurns = 3;
      burning = true;
      lastEvent = '화상!';
    }
    // 어둠 슬라임: 때린 피해의 30% 회복
    if (f.trait == MonsterTrait.drain && foeHp < f.maxHp) {
      foeHp = math.min(f.maxHp, foeHp + math.max(1, (taken * 0.3).round()));
    }
    if (f.has(ModifierId.sticky)) playerSpeed = baseSpeed * 0.8;
    if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
  }

  bool _revive() {
    if (revives <= 0) return false;
    revives--;
    revived++;
    playerHp = math.max(1, (playerMaxHp * PetRules.phoenixRevive).round());
    lastEvent = '엠버의 불꽃으로 되살아났어요!';
    return true;
  }

  /// 스킬 '불씨의 일격'. 충전이 다 됐을 때만 쓸 수 있다.
  bool useSkill() {
    if (!skillReady) return false;
    skillsUsed++;
    skillCharge = 0;
    lastWasSkill = true;
    lastEvent = null;
    var dmg = _vary(skillDamage);
    switch (petSkill) {
      case PetSkill.scratch:
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
      case PetSkill.tongue:
        _foeBound = true;
        lastEvent = '묶었어요!';
      case PetSkill.insight:
        insightTurns = PetRules.insightTurns;
        lastEvent = '약점 간파!';
      case PetSkill.ember:
        foeBurnTurns = 3;
        lastEvent = '화상!';
      case PetSkill.shield:
        shieldHits = PetRules.shieldHits(adult: petAdult);
        lastEvent = '보호막!';
      // 묶음 33 #185 희귀 펫
      case PetSkill.thunderClaw:
        if (_rng.nextDouble() < PetRules.thunderStun) {
          _foeBound = true;
          lastEvent = '멈칫!';
        }
      case PetSkill.frostBite:
        _foeFrozen = true;
        foeFreezes++;
        lastEvent = '얼었어요!';
      case PetSkill.flameBreath:
        foeBurnTurns = PetRules.flameTurns;
        lastEvent = '화상!';
      case PetSkill.tideWrap:
        _foeBound = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.tideHeal).round()));
        _healed(playerHp - before);
        lastEvent = '묶었어요!';
      case PetSkill.ambush:
        if (_rng.nextDouble() < PetRules.ambushChance(adult: petAdult)) {
          dmg = (dmg * PetRules.ambushMultiplier).round();
          lastEvent = '깜짝 물기!';
        }
      case PetSkill.stoneWall:
        shieldHits = PetRules.stoneWallHits(adult: petAdult);
        lastEvent = '돌 방벽!';
      // 묶음 49 #235 영웅 펫
      case PetSkill.galeFang:
        lastEvent = '질풍 송곳니!';
      case PetSkill.mossShell:
        shieldHits = PetRules.mossHits(adult: petAdult);
        lastEvent = '이끼 등딱지!';
      case PetSkill.shadowPounce:
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
        if (_rng.nextDouble() < PetRules.pounceBind) {
          _foeBound = true;
          lastEvent = '덮쳐서 묶었어요!';
        }
      case PetSkill.tidalSong:
        _foeBound = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.songHeal).round()));
        _healed(playerHp - before);
        lastEvent = '고래 노래!';
      case PetSkill.rebirthFlame:
        foeBurnTurns = PetRules.rebirthTurns;
        lastEvent = '화상!';
      case PetSkill.dawnHalo:
        insightTurns = PetRules.insightTurns;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.haloHeal).round()));
        _healed(playerHp - before);
        lastEvent = '새벽 햇무리!';
      // 묶음 57 #244 전설 펫
      case PetSkill.starWing:
        lastEvent = '별빛 날개!';
      case PetSkill.quake:
        lastEvent = '땅울림!';
        if (_rng.nextDouble() < PetRules.quakeStun) {
          _foeBound = true;
          lastEvent = '땅울림! 멈칫!';
        }
      case PetSkill.nightTerror:
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '악몽!';
        if (_rng.nextDouble() < PetRules.terrorBind) _foeBound = true;
      case PetSkill.abyssTide:
        _foeBound = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.abyssHeal).round()));
        _healed(playerHp - before);
        lastEvent = '심해 물살!';
      case PetSkill.dragonFire:
        foeBurnTurns = PetRules.dragonFireTurns;
        lastEvent = '용의 불꽃!';
      case PetSkill.holyHorn:
        insightTurns = PetRules.insightTurns;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.hornHeal).round()));
        _healed(playerHp - before);
        lastEvent = '성스러운 뿔!';
      case PetSkill.peck || null:
        break;
    }
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    dmg = _elemental(dmg, skillElement);
    lastDealt = dmg;
    lastTaken = 0;
    _hitFoe(lastDealt);
    return true;
  }

  /// 공격 속성 물약의 상태 이상 (독·불: 3턴 동안 2%, 얼음: 다음 차례를 쉼)
  void _inflict() {
    final e = weaponPotion;
    if (e == null || phase != BattlePhase.fighting) return;
    if (e != Element.fire && e != Element.poison && e != Element.ice) return;
    if (_rng.nextDouble() >= AlchemyRules.weaponInflict) return;
    switch (e) {
      case Element.ice:
        _foeFrozen = true;
        foeFreezes++;
        lastEvent = '얼렸어요!';
      case Element.fire:
        foeBurnTurns = 3;
        lastEvent = '불태웠어요!';
      default:
        foeBurnTurns = 3;
        lastEvent = '중독시켰어요!';
    }
  }

  /// 속성 상성 (11-11 #63): 배율은 숨기고 문구로만 알린다.
  /// [level] 은 장비 속성 강화 단계 (11-11 #74): 강할 때 배율이 더 커진다.
  int _elemental(int dmg, Element? attack, {int level = 0}) {
    var m = ElementRules.multiplier(attack, foe.element);
    if (noWeakness && m < 1) m = 1;
    if (m > 1 && level > 0) m = SmithRules.strongAt(level);
    var d = dmg * m;
    if (attack != null && attack == mainElement) d *= 1 + ElementRules.mainBonus;
    // 보스 장비 4개 세트: 그 속성 공격 강화 (11-11 #82)
    if (attack != null && setAttack[attack] != null) d *= 1 + setAttack[attack]!;
    // 잿빛 왕의 유품 (묶음 34)
    if (ashDealt > 0 && foeIsAsh) d *= 1 + ashDealt;
    if (m > 1) {
      lastEvent = Battle.superEffective;
      lastSuper = true;
    }
    if (m < 1) {
      lastEvent = Battle.notEffective;
      lastResist = true;
    }
    return math.max(1, d.round());
  }

  void _hitFoe(int damage) {
    if (practice) {
      practiceDealt += damage;
      practiceHits++;
      if (damage > practiceMax) practiceMax = damage;
      return;
    }
    // 묶음 57 골렘 「돌벽」: 잠시 받는 피해가 줄어요
    if (stoneWallTurns > 0) {
      final cut = math.max(1, (damage * 0.5).round());
      if (lastDealt >= damage) lastDealt -= damage - cut;
      damage = cut;
    }
    // 묶음 59 레이드: 망자의 방패 · 등껍질 숨기 (받는 피해가 크게 줄어요)
    if (raidShieldTurns > 0 || raidShellTurns > 0) {
      final cut = math.max(1, (damage * (raidShellTurns > 0 ? 0.25 : 0.4)).round());
      if (lastDealt >= damage) lastDealt -= damage - cut;
      damage = cut;
    }
    foeHp = math.max(0, foeHp - damage);
    if (foeHp > 0) return;
    phase = floor == floors.length - 1
        ? BattlePhase.cleared
        : BattlePhase.floorCleared;
  }
}
