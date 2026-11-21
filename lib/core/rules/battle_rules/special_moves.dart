part of '../battle_rules.dart';

extension BattleSpecialMoves on Battle {
  /// 낙뢰가 다가오는지 (화면 표시)
  bool get boltComing => boltIn > 0 && phase == BattlePhase.fighting;

  /// 서리 갑옷을 둘렀는지 (화면 표시)
  bool get frosted => frostTurns > 0 && phase == BattlePhase.fighting;

  void _clearSkyMoves() {
    whirlTurns = 0;
    boltIn = 0;
    sunHealed = false;
    frostTurns = 0;
  }

  /// 틱 처음: 하이랜드 수호자의 특별한 공격
  void _skyMove() {
    final m = foe.sky;
    if (m == null) return;
    final t = floorTicks;
    final line = HighlandRules.ofMove(m)?.moveLine;
    switch (m) {
      case SkyMove.whirl:
        if (whirlTurns <= 0 && t % HighlandRules.whirlEvery == 2) {
          whirlTurns = HighlandRules.whirlLength;
          lastMove = line;
        }
      case SkyMove.bolt:
        if (boltIn > 0) {
          boltIn--;
          if (boltIn == 0) _boltStrike();
        } else if (t % HighlandRules.boltEvery == 4) {
          boltIn = HighlandRules.boltDelay;
          lastMove = line;
        }
      case SkyMove.sunHeal:
        if (!sunHealed && foeHp < foe.maxHp * HighlandRules.sunHealBelow) {
          sunHealed = true;
          foeHp = math.min(foe.maxHp,
              foeHp + math.max(1, (foe.maxHp * HighlandRules.sunHeal).round()));
          lastMove = line;
        }
      case SkyMove.frostArmor:
        if (frostTurns <= 0 && t % HighlandRules.frostEvery == 1) {
          frostTurns = HighlandRules.frostLength;
          lastMove = line;
        }
      case SkyMove.wash:
        if (t % HighlandRules.washEvery == 3) {
          var any = false;
          while (_stealBuff()) {
            any = true;
          }
          if (any) lastMove = line;
        }
    }
  }

  /// 낙뢰가 떨어진다: 방어 태세면 거의 막는다
  void _boltStrike() {
    if (practice) return;
    var atk = foe.attack * HighlandRules.boltPower;
    final blocked = stanceTurns > 0;
    if (blocked) atk *= HighlandRules.boltBlocked;
    if (damageTaken != 1) atk *= damageTaken;
    if (skyTaken > 0) atk *= 1 - skyTaken;
    final taken = _vary(math.max(1, atk.round()));
    lastTaken += taken;
    playerHp = math.max(0, playerHp - taken);
    lastMove = blocked ? '방어 태세로 낙뢰를 막아 냈어요!' : '낙뢰가 떨어졌어요!';
    if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
  }

  /// 지금 스킬 버튼이 잠겼는지 (겁주기)
  bool get skillsLocked => skillLockTurns > 0 && phase == BattlePhase.fighting;

  /// 지금 펫이 고립됐는지
  bool get isolated => isolateTurns > 0 && phase == BattlePhase.fighting;

  void _clearAshMoves() {
    tearTurns = 0;
    skillLockTurns = 0;
    isolateTurns = 0;
    stolenTurns = 0;
    _rageStep = 0;
  }

  /// 틱 처음: 분신·본체 단계의 특별한 공격
  void _ashMove() {
    final m = foe.move;
    if (m == null) return;
    final t = floorTicks;
    final line = Act2Rules.ofMove(m)?.moveLine;
    switch (m) {
      case AshMove.rage:
        final step = ((1 - foeHp / foe.maxHp) * 3).floor().clamp(0, 2);
        if (step > _rageStep) {
          _rageStep = step;
          lastMove = line;
        }
      case AshMove.tears:
        if (tearTurns <= 0 && t % Act2Rules.tearsEvery == 3) {
          tearTurns = Act2Rules.tearsLength;
          lastMove = line;
        }
      case AshMove.steal:
        if (t % Act2Rules.stealEvery == 0 && _stealBuff()) {
          stolenTurns = Act2Rules.stolenLength;
          lastMove = line;
        }
      case AshMove.fear:
        if (heroSkills && t % Act2Rules.fearEvery == 2) {
          skillLockTurns = 1;
          lastMove = line;
        }
      case AshMove.isolate:
        if (isolateTurns <= 0 && t % Act2Rules.isolateEvery == 3) {
          isolateTurns = Act2Rules.isolateLength;
          lastMove = line;
        }
    }
  }

  /// 나에게 걸린 좋은 효과 하나를 없앤다 (있었으면 true)
  bool _stealBuff() {
    if (rallyTurns > 0) {
      rallyTurns = 0;
    } else if (wallTurns > 0) {
      wallTurns = 0;
    } else if (stanceTurns > 0) {
      stanceTurns = 0;
    } else if (regenTurns > 0) {
      regenTurns = 0;
    } else if (insightTurns > 0) {
      insightTurns = 0;
    } else if (shieldHits > 0) {
      shieldHits = 0;
    } else if (dodgeNext) {
      dodgeNext = false;
    } else if (blockNext) {
      blockNext = false;
    } else if (reflectNext) {
      reflectNext = false;
    } else {
      return false;
    }
    return true;
  }
}
