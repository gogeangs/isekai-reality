part of '../battle_view.dart';

extension _BattleViewHelpers on _BattleViewState {
  void _allyStruck(int i, int dealt, {bool now = false}) {
    final old = _allySwing[i]?.swing ?? 0;
    _allySwing[i] = (swing: old + 1, dealt: dealt, now: now);
  }

  Battle get _b => widget.battle;

  bool get _autoOn => _b.autoHp > 0 || _b.autoCure;

  Duration get _interval =>
      _fast ? widget.tickInterval ~/ 2 : widget.tickInterval;

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _step);
  }

  void _record() {
    String? line;
    final e = _b.lastEvent;
    if (e != null) {
      line = e;
      if (_b.lastDealt > 0) line = '$e ${comma(_b.lastDealt)} 피해';
    } else if (_b.lastDealt > 0) {
      line = '${_b.foe.name}에게 ${comma(_b.lastDealt)} 피해';
    } else if (_b.lastTaken > 0) {
      line = '${comma(_b.lastTaken)} 피해를 받았어요';
    }
    if (_b.lastTaken > 0 && e != null && _b.lastDealt == 0) {
      line = '$e ${comma(_b.lastTaken)} 피해를 받았어요';
    }
    if (line == null) return;
    _addLog(line);
  }

  void _addLog(String line) {
    _log.add(line);
    if (_log.length > 2) _log.removeAt(0);
  }

  void _feel() {
    if (widget.sound) {
      final e = _b.lastEvent;
      if (_b.lastGuard == GuardResult.perfect) {
        Sfx.play(SfxKind.perfect);
      } else if (_b.lastGuard == GuardResult.block) {
        Sfx.play(SfxKind.block);
      } else if (_b.lastCrit || _b.lastBash) {
        Sfx.play(SfxKind.crit);
      } else if (_b.lastSuper || e == Battle.superEffective) {
        Sfx.play(SfxKind.superEffective, volume: 0.6);
      } else if (_b.lastDealt > 0) {
        Sfx.play(SfxKind.hit, volume: 0.7);
      }
    }
    if (!widget.vibrate) return;
    if (_b.lastGuard == GuardResult.perfect) {
      HapticFeedback.heavyImpact();
    } else if (_b.lastGuard == GuardResult.block) {
      HapticFeedback.mediumImpact();
    } else if (_b.lastCrit || _b.lastBash) {
      HapticFeedback.mediumImpact();
    } else if (_b.lastTaken > 0) {
      HapticFeedback.lightImpact();
    } else if (_b.lastDealt > 0) {
      HapticFeedback.selectionClick();
    }
  }

  /// 묶음 76 #338: 강한 공격 예고 중 (아래 「막기!」 버튼 · 다른 버튼은 쉼)
  bool get _guardTime => _warning && !_b.isOver;

  BattlePotion? get _antidote {
    for (final p in _b.potions.values) {
      if (p.cure == CureKind.poison && _b.potionLeft(p.key) > 0) return p;
    }
    return null;
  }

  void _checkEnd() {
    if (!_b.isOver || _reported) return;
    _reported = true;
    SkillMasteryHook.count(_b);
    _timer?.cancel();
    _warning = false;
    if (widget.sound) {
      if (_b.phase == BattlePhase.cleared) Sfx.play(SfxKind.victory);
      if (_b.phase == BattlePhase.failed) Sfx.play(SfxKind.defeat);
    }
    if (widget.vibrate) {
      _b.phase == BattlePhase.cleared
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.vibrate();
    }
    // 마지막 타격을 잠깐 보여 주고 결과로 넘어간다
    Timer(widget.tickInterval, () {
      if (mounted) widget.onFinished();
    });
  }

  List<_Status> get _heroStatus => [
        if (_b.poisonTurns > 0 && !_b.burning) _Status.poison,
        if (_b.poisonTurns > 0 && _b.burning) _Status.burn,
        if (_b.frozen) _Status.frozen,
        if (_b.foe.trait == MonsterTrait.dazzle && !_b.clearEye) _Status.dazzle,
        if (_b.stanceTurns > 0) _Status.stance,
      ];

  List<_Status> get _foeStatus => [
        if (_b.foeBurnTurns > 0) _Status.burn,
        if (_b.foeFrozen) _Status.frozen,
        if (_b.foeBound) _Status.bound,
      ];

  /// 묶음 76 #315: 방어 태세는 방패로만 보이고 주인공을 물들이지 않는다
  Color? get _heroTint {
    if (_b.isOver) return null;
    final s = [for (final x in _heroStatus) if (x != _Status.stance) x];
    return s.isEmpty ? null : s.first.color;
  }

  Color? get _foeTint => _foeStatus.isEmpty || _b.isOver
      ? null
      : _foeStatus.first.color;

  String get _counter =>
      widget.counterOf?.call(_b) ?? '${_b.purified.length} / ${_b.floors.length}';

  String get _floorLabel {
    if (widget.floorLabelOf case final f?) return f(_b);
    if (_b.floors.length == 1) return '필드 전투';
    // 수식어 무리(필드): 몇 번째 마리인지
    if (!_b.floors.last.isBoss) {
      return '${_b.floor + 1} / ${_b.floors.length}마리';
    }
    return _b.foe.isBoss
        ? 'BOSS'
        : '${_b.floor + 1}층 / ${_b.floors.length - 1}층';
  }

  /// 맞춤 모드면 남은 높이를 장면이 차지한다 (너무 작아지지 않게)
  Widget _fitScene(Widget scene) => widget.fit
      ? Expanded(
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150), child: scene))
      : scene;

  /// 정화한 수 · 빠르기 (작은 한 줄)
  Widget _counterRow() => Row(children: [
        const GameIcon('mana_stone', size: 20),
        const SizedBox(width: 4),
        Text(_counter,
            style: AppText.title(15, color: AppColors.text)),
        const Spacer(),
        InkWell(
          key: const Key('battleSpeed'),
          onTap: _toggleSpeed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _fast ? AppColors.goldBright : AppColors.textMuted),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GameGlyph(_fast ? Glyph.fast : Glyph.play, size: 13, dim: !_fast),
              const SizedBox(width: 3),
              Text(_fast ? '2배' : '1배',
                  style: TextStyle(
                      color: _fast ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]);

  Widget _poisonTip() {
    final a = _antidote;
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: OrnatePanel(
            key: const Key('poisonTip'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('중독됐어요!', style: AppText.title(19)),
                const SizedBox(height: 6),
                Text(
                    a != null
                        ? '해독제를 마시면 바로 풀리고 잠깐 다시 걸리지 않아요.'
                        : '해독제를 마시면 바로 풀려요. 공방에서 만들거나 잡화상에서 살 수 있어요.',
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 14, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('poisonTipClose'),
                      onPressed: () => _closeTip(),
                      child: const Text('알겠어요'),
                    ),
                    if (a != null)
                      TextButton(
                        key: const Key('poisonTipUse'),
                        onPressed: () => _closeTip(drink: true),
                        child: Text('${a.name} 쓰기',
                            style: const TextStyle(
                                color: AppColors.goldBright,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
