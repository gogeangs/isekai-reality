part of '../battle_rules.dart';

extension BattleSpecialMoves on Battle {
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
