import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../data/sound/sfx.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'modifier_view.dart';
import '../bulssi/bulssi_mood.dart';
import '../bulssi/spirit_art.dart';
import 'element_view.dart';
import '../../data/weather/weather_source.dart' show WeatherKind;

/// 자동 전투 화면 (목업 구도): 동굴 배경 위 각성자 vs 몬스터,
/// 아래에 체력 막대, 정화 수, 둥근 스킬 버튼 '정령의 일격'.
///
/// [tickInterval] 마다 [Battle.tick] 을 부르고, 끝나면 [onFinished] 를 한 번 부른다.
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onFinished,
    this.tickInterval = const Duration(milliseconds: 900),
    this.playerName = '각성자',
    this.look = HeroLook.male,
    this.vibrate = false,
    this.sound = false,
    this.fast = false,
    this.onFastChanged,
    this.poisonTip = false,
    this.onPoisonTipShown,
    this.aura,
    this.hour,
    this.weather,
  });

  /// 보스 장비 6개 세트 외형 빛 (11-11 #82)
  final Color? aura;

  /// 지금 시각 (낮·노을·밤 색감, 11-11 #81). 없으면 낮.
  final int? hour;

  /// 지금 날씨 (비·눈 효과). 날씨를 모르면 null.
  final WeatherKind? weather;

  final Battle battle;
  final VoidCallback onFinished;
  final Duration tickInterval;
  final String playerName;
  final HeroLook look;

  /// 때리고 막을 때 진동 (설정 「진동」, 11-11 #75)
  final bool vibrate;

  /// 효과음 (설정 「효과음」)
  final bool sound;

  /// 2배속으로 시작 (마지막에 고른 속도를 기억한다)
  final bool fast;
  final ValueChanged<bool>? onFastChanged;

  /// 처음 중독되면 해독제 안내를 한 번 보여 준다 (11-11 A4)
  final bool poisonTip;
  final VoidCallback? onPoisonTipShown;

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  Timer? _timer;
  bool _reported = false;

  /// 공격이 한 번 오갈 때마다 1씩 늘어난다 (전투 장면 연출의 신호)
  int _beat = 0;

  late bool _fast = widget.fast;

  /// 예고가 뜬 뒤 흐른 실제 시간 (2배속이어도 판정은 실제 시간)
  final _warnClock = Stopwatch();
  bool _warning = false;
  bool _tapped = false;

  bool _tipShown = false;
  bool _tipOpen = false;

  /// 전투 기록 두 줄
  final List<String> _log = [];

  /// 보스가 나오는 순간 (이름 띠 + 확대, 11-11 #81)
  int _bossBeat = 0;

  /// 강한 타격 뒤 잠깐 멈춤 (손맛)
  static const _hitStop = Duration(milliseconds: 120);

  Battle get _b => widget.battle;

  Duration get _interval =>
      _fast ? widget.tickInterval ~/ 2 : widget.tickInterval;

  @override
  void initState() {
    super.initState();
    _afterTick(first: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _step);
  }

  void _step() {
    if (!mounted || _b.isOver || _tipOpen) return;
    final floorBefore = _b.floor;
    setState(() {
      final before = _b.ticks;
      _b.tick();
      if (_b.ticks != before) _beat++; // 층이 바뀌는 틱은 연출하지 않는다
      if (_b.floor != floorBefore && _b.foe.isBoss) _bossBeat++;
      _record();
    });
    _feel();
    _checkEnd();
    if (_b.isOver) return;
    _afterTick();
  }

  /// 다음 틱 시간을 정하고, 강한 공격 예고면 막기 시간을 연다
  void _afterTick({bool first = false}) {
    var next = _interval;
    if (!first &&
        (_b.lastGuard == GuardResult.perfect || _b.lastCrit || _b.lastBash)) {
      next += _hitStop;
    }
    // 보스 등장: 이름 띠를 보여 주는 동안 잠깐 기다린다
    if (!first && _bossBeat > 0 && _b.floorTicks == 0) {
      next += const Duration(milliseconds: 1300);
    }
    if (_b.strongNext) {
      _warning = true;
      _tapped = false;
      _warnClock
        ..reset()
        ..start();
      final window = Battle.guardWindow + const Duration(milliseconds: 60);
      if (next < window) next = window;
    } else {
      _warning = false;
      _warnClock.stop();
    }
    // 처음 중독되면 해독제 안내 (한 번, 전투를 잠깐 멈춘다)
    if (widget.poisonTip &&
        !_tipShown &&
        _b.poisonedThisBattle &&
        _b.poisonTurns > 0 &&
        !_b.burning) {
      _tipShown = true;
      _tipOpen = true;
      widget.onPoisonTipShown?.call();
      _timer?.cancel();
      if (!first) setState(() {});
      return;
    }
    _schedule(next);
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

  /// 화면 아무 곳이나 누르면 막기 (예고 하나에 한 번만, 일찍 눌러도 벌 없음)
  void _onPointer(PointerDownEvent _) {
    if (!_warning || _tapped || _b.isOver) return;
    final r = Battle.judgeGuard(_warnClock.elapsed);
    if (r == null) return;
    if (_b.guard(perfect: r == GuardResult.perfect)) {
      _tapped = true;
      if (widget.vibrate) HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  /// 전투 중 물약 (11-11 #57): 전투 한 번에 3개까지
  Future<void> _potionSheet() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, setSheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('물약 (${_b.potionsDrunk} / ${AlchemyRules.perBattle})',
                      style: AppText.title(18)),
                  for (final p in _b.potions.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${p.name} × ${_b.potionLeft(p.key)}',
                          style: const TextStyle(color: AppColors.text)),
                      trailing: TextButton(
                        onPressed: _b.potionLeft(p.key) > 0
                            ? () {
                                if (_b.drink(p.key)) {
                                  setState(() {});
                                  Navigator.of(sheet).pop();
                                } else {
                                  setSheet(() {});
                                }
                              }
                            : null,
                        child: const Text('마시기'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  void _skill() {
    setState(() {
      if (_b.useSkill()) {
        _beat++;
        _record();
        if (widget.sound) Sfx.play(SfxKind.crit);
      }
    });
    if (widget.vibrate) HapticFeedback.mediumImpact();
    _checkEnd();
  }

  void _bash() {
    setState(() {
      if (_b.useBash()) {
        _beat++;
        _record();
        if (widget.sound) Sfx.play(SfxKind.crit);
      }
    });
    if (widget.vibrate) HapticFeedback.mediumImpact();
    _checkEnd();
  }

  void _stance() {
    setState(() {
      if (_b.useStance()) _record();
    });
    if (widget.vibrate) HapticFeedback.lightImpact();
  }

  void _toggleSpeed() {
    setState(() => _fast = !_fast);
    widget.onFastChanged?.call(_fast);
  }

  BattlePotion? get _antidote {
    for (final p in _b.potions.values) {
      if (p.cure == CureKind.poison && _b.potionLeft(p.key) > 0) return p;
    }
    return null;
  }

  void _closeTip({bool drink = false}) {
    setState(() {
      if (drink && _antidote != null) {
        _b.drink(_antidote!.key);
        _record();
      }
      _tipOpen = false;
    });
    if (!_b.isOver) _afterTick(first: true);
  }

  void _checkEnd() {
    if (!_b.isOver || _reported) return;
    _reported = true;
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

  Color? get _heroTint => _heroStatus.isEmpty || _b.isOver
      ? null
      : _heroStatus.first.color;

  Color? get _foeTint => _foeStatus.isEmpty || _b.isOver
      ? null
      : _foeStatus.first.color;

  String get _floorLabel {
    if (_b.floors.length == 1) return '필드 전투';
    // 수식어 무리(필드): 몇 번째 마리인지
    if (!_b.floors.last.isBoss) {
      return '${_b.floor + 1} / ${_b.floors.length}마리';
    }
    return _b.foe.isBoss
        ? 'BOSS'
        : '${_b.floor + 1}층 / ${_b.floors.length - 1}층';
  }

  @override
  Widget build(BuildContext context) {
    final foe = _b.foe;
    final cleared = _b.phase == BattlePhase.floorCleared ||
        _b.phase == BattlePhase.cleared;
    final warning = _warning && _b.strongNext && !_b.isOver;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointer,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Scene(
                foe: foe,
                cleared: cleared,
                floorLabel: _floorLabel,
                dealt: _b.lastDealt,
                taken: _b.lastTaken,
                skill: _b.lastWasSkill || _b.lastBash,
                petDash: _b.lastWasSkill,
                look: widget.look,
                beat: _beat,
                beatDuration: _interval * 0.85,
                warning: warning ? (_b.strongLabel ?? '강한 공격!') : null,
                guarded: _tapped && warning,
                guard: _b.lastGuard,
                enraged: _b.enraged,
                stance: _b.stanceTurns > 0,
                aura: widget.aura,
                crit: _b.lastCrit,
                superHit: _b.lastSuper,
                heals: _b.heals,
                healed: _b.lastHealed,
                defeated: _b.phase == BattlePhase.failed,
                bossBeat: _bossBeat,
                hitElement: _b.weaponPotion ?? _b.attackElement,
                heroTint: _heroTint,
                foeTint: _foeTint,
                hour: widget.hour,
                weather: widget.weather,
              ),
              const SizedBox(height: 8),
              OrnatePanel(
                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                child: Column(children: [
                  Row(children: [
                    _Avatar(look: widget.look),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HpColumn(
                        name: widget.playerName,
                        hp: _b.playerHp,
                        maxHp: _b.playerMaxHp,
                        colors: BarColors.hp,
                        note: _b.lastTaken > 0
                            ? '-${comma(_b.lastTaken)}'
                            : null,
                      ),
                    ),
                    if (_b.potions.isNotEmpty && !_b.isOver)
                      IconButton(
                        key: const Key('battlePotion'),
                        tooltip: '물약 마시기',
                        visualDensity: VisualDensity.compact,
                        onPressed: _potionSheet,
                        icon: const Icon(Icons.local_drink_rounded,
                            color: AppColors.goldBright),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HpColumn(
                        name: foe.name,
                        nameColor: modGradeColor(foe.grade),
                        element: Monsters.info(foe.monster).element,
                        showElement: true,
                        hp: _b.foeHp,
                        maxHp: foe.maxHp,
                        colors: BarColors.foe,
                        note: _b.lastEvent,
                        alignEnd: true,
                      ),
                    ),
                  ]),
                  // 상태 이상 (11-11 #81): 체력 막대 아래 아이콘
                  if (_heroStatus.isNotEmpty || _foeStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const SizedBox(width: 52),
                        Expanded(child: _StatusIcons(_heroStatus)),
                        Expanded(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: _StatusIcons(_foeStatus)),
                        ),
                      ]),
                    ),
                  // 전투 기록 두 줄
                  Container(
                    key: const Key('battleLog'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x55000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 2; i++)
                          Text(
                            i < _log.length ? _log[i] : ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: i == _log.length - 1
                                    ? AppColors.text
                                    : AppColors.textMuted,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: OrnatePanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const GameIcon('mana_stone', size: 26),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                  '${_b.purified.length} / ${_b.floors.length}',
                                  style: AppText.title(20,
                                      color: AppColors.text)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          InkWell(
                            key: const Key('battleSpeed'),
                            onTap: _toggleSpeed,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _fast
                                        ? AppColors.goldBright
                                        : AppColors.textMuted),
                              ),
                              child: Text(_fast ? '▶▶ 2배' : '▶ 1배',
                                  style: TextStyle(
                                      color: _fast
                                          ? AppColors.goldBright
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_b.heroSkills) ...[
                    const SizedBox(width: 8),
                    _MiniSkill(
                      key: const Key('bashButton'),
                      label: '강타',
                      icon: Icons.gavel_rounded,
                      ratio: _b.bashRatio,
                      ready: _b.bashReady,
                      onPressed: _bash,
                    ),
                    const SizedBox(width: 6),
                    _MiniSkill(
                      key: const Key('stanceButton'),
                      label: _b.stanceTurns > 0 ? '방어 중' : '방어 태세',
                      icon: Icons.shield_rounded,
                      ratio: _b.stanceTurns > 0 ? 1 : _b.stanceRatio,
                      ready: _b.stanceReady,
                      active: _b.stanceTurns > 0,
                      onPressed: _stance,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _SkillOrb(
                    ratio: _b.skillRatio,
                    ready: _b.skillReady,
                    away: _b.skillDisabled,
                    onPressed: _skill,
                    size: _b.heroSkills ? 84 : 104,
                  ),
                ],
              ),
            ],
          ),
          if (_tipOpen) Positioned.fill(child: _poisonTip()),
        ],
      ),
    );
  }

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
                Text('중독됐어요!', style: AppText.title(18)),
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

/// 내 스킬 작은 버튼 (강타 · 방어 태세, 11-11 #75)
class _MiniSkill extends StatelessWidget {
  const _MiniSkill({
    super.key,
    required this.label,
    required this.icon,
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final double ratio;
  final bool ready;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final lit = ready || active;
    return GestureDetector(
      onTap: ready ? onPressed : null,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 4,
                    color: active ? AppColors.mana : AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit ? const Color(0xFF6A4A1C) : const Color(0xFF262A5A),
                    border: Border.all(
                        color: AppColors.goldBright, width: ready ? 2 : 1),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.7),
                                blurRadius: 14),
                          ]
                        : null,
                  ),
                  child: Icon(icon,
                      size: 24,
                      color: lit ? AppColors.goldBright : AppColors.textMuted),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                    color: lit ? AppColors.goldBright : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────── 전투 장면

class _Scene extends StatefulWidget {
  const _Scene({
    required this.foe,
    required this.cleared,
    required this.floorLabel,
    required this.dealt,
    required this.taken,
    required this.skill,
    required this.look,
    required this.beat,
    required this.beatDuration,
    this.petDash = false,
    this.warning,
    this.guarded = false,
    this.guard,
    this.enraged = false,
    this.stance = false,
    this.aura,
    this.crit = false,
    this.superHit = false,
    this.heals = 0,
    this.healed = 0,
    this.defeated = false,
    this.bossBeat = 0,
    this.hitElement,
    this.heroTint,
    this.foeTint,
    this.hour,
    this.weather,
  });

  final Color? aura;
  final bool crit;
  final bool superHit;

  /// 회복할 때마다 늘어난다 (초록 숫자)
  final int heals;
  final int healed;
  final bool defeated;
  final int bossBeat;
  final Element? hitElement;
  final Color? heroTint;
  final Color? foeTint;
  final int? hour;
  final WeatherKind? weather;

  /// 정령(펫) 스킬: 펫이 몬스터 쪽으로 달려든다
  final bool petDash;

  /// 강한 공격 예고 문구 (막기 시간)
  final String? warning;

  /// 예고에 이미 막기를 눌렀다
  final bool guarded;

  /// 방금 막은 결과
  final GuardResult? guard;

  /// 보스 분노 (붉은 빛)
  final bool enraged;

  /// 방어 태세 중
  final bool stance;

  final Foe foe;
  final bool cleared;
  final String floorLabel;
  final int dealt;
  final int taken;
  final bool skill;
  final HeroLook look;

  /// 바뀔 때마다 한 번의 공격 연출을 처음부터 재생한다
  final int beat;
  final Duration beatDuration;

  @override
  State<_Scene> createState() => _SceneState();
}

/// 한 번의 공격 연출 (0 → 1):
/// 0.00~0.22 각성자가 달려든다 → 0.22 타격 (몬스터 흔들림·번쩍임, 불꽃, 피해 숫자)
/// → 0.22~0.50 제자리로 → 0.50~0.70 몬스터 반격 (각성자 붉게 번쩍, 받은 피해 숫자)
/// 일격은 화면이 흔들리고 금빛 베기가 가로지른다.
class _SceneState extends State<_Scene> with TickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.beatDuration);

  /// 배경 입자·날씨 (늘 돈다)
  late final AnimationController _amb = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  /// 보스 등장 띠
  late final AnimationController _boss = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didUpdateWidget(covariant _Scene old) {
    super.didUpdateWidget(old);
    if (widget.beat != old.beat) {
      // 스킬은 조금 느리게 (슬로모션)
      _c.duration = widget.skill ? widget.beatDuration * 1.6 : widget.beatDuration;
      _c.forward(from: 0);
    }
    if (widget.bossBeat != old.bossBeat) _boss.forward(from: 0);
  }

  @override
  void dispose() {
    _amb.dispose();
    _boss.dispose();
    _c.dispose();
    super.dispose();
  }

  // t 구간 [a, b] 안에서 0 → 1
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final foe = widget.foe;
    final cleared = widget.cleared;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final idle = !_c.isAnimating;
              // 각성자 달려들기: 0→0.22 앞으로, 0.22→0.5 돌아오기
              final lunge = t < 0.22
                  ? Curves.easeIn.transform(_seg(t, 0, 0.22))
                  : 1 - Curves.easeOut.transform(_seg(t, 0.22, 0.5));
              // 달려들어 휘두르는 동안만 공격 자세, 나머지는 대기 자세
              final swinging = !idle && widget.dealt > 0 && t < 0.5;
              // 타격 순간부터
              final hit = _seg(t, 0.22, 0.6);
              final hitting = !idle && t >= 0.22 && widget.dealt > 0;
              // 몬스터 흔들림 (줄어드는 진동)
              final shake = hitting
                  ? math.sin(hit * math.pi * 6) * (1 - hit) * (widget.skill ? 14 : 8)
                  : 0.0;
              final flash = hitting ? (1 - _seg(t, 0.22, 0.42)) : 0.0;
              // 몬스터 반격 (0.5~0.7)
              final counter = widget.taken > 0 && !idle
                  ? math.sin(_seg(t, 0.5, 0.7) * math.pi)
                  : 0.0;
              final hurt = widget.taken > 0 && !idle
                  ? (1 - _seg(t, 0.6, 0.85)) * (t >= 0.6 ? 1 : 0)
                  : 0.0;
              // 일격: 화면 흔들림
              final camera = widget.skill && hitting
                  ? math.sin(hit * math.pi * 8) * (1 - hit) * 6
                  : 0.0;

              final heroW = w * 0.5;
              final monSize = w * 0.38;
              final monLeft = w - monSize - w * 0.05 + shake - counter * w * 0.07;
              final monTop = h * 0.24;
              final hitX = monLeft + monSize * 0.45;
              final hitY = monTop + monSize * 0.45;

              // 치명타·스킬: 살짝 확대 (11-11 #81)
              final punch = !idle && (widget.crit || widget.skill)
                  ? math.sin(_seg(t, 0.15, 0.7) * math.pi) *
                      (widget.skill ? 0.08 : 0.05)
                  : 0.0;
              final critShake = widget.crit && hitting
                  ? math.sin(hit * math.pi * 10) * (1 - hit) * 4
                  : 0.0;
              return Transform.translate(
                offset: Offset(camera + critShake, camera * 0.4),
                child: Transform.scale(
                 scale: 1 + punch,
                 child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset('assets/images/bg_battle.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF1B1840))),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xAA0B0D26)],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    // 시간 색감 · 몬스터 속성 입자 · 비·눈 (11-11 #81)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _amb,
                          builder: (_, __) => CustomPaint(
                            key: const Key('battleAmbient'),
                            painter: _AmbientPainter(
                              t: _amb.value,
                              element: foe.info.element,
                              hour: widget.hour,
                              weather: widget.weather,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 발밑 그림자
                    Positioned(
                      left: w * 0.06 + lunge * w * 0.08,
                      bottom: 20,
                      child: _Shadow(width: heroW * 0.6),
                    ),
                    Positioned(
                      left: monLeft + monSize * 0.15,
                      top: monTop + monSize * 0.88,
                      child: _Shadow(width: monSize * 0.7),
                    ),
                    // 몬스터 (맞으면 흔들리고 하얗게 번쩍, 반격할 때 앞으로)
                    Positioned(
                      left: monLeft,
                      top: monTop - (cleared ? 6 : 0),
                      width: monSize,
                      height: monSize,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: ColorFiltered(
                          key: ValueKey('${foe.monster.name}_$cleared'),
                          colorFilter: ColorFilter.mode(
                              Colors.white.withValues(alpha: flash * 0.75),
                              BlendMode.srcATop),
                          child: Transform.scale(
                            scale: (1 - flash * 0.06 + counter * 0.06) *
                                (widget.enraged ? 1.08 : 1),
                            child: widget.enraged && !cleared
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFFFF3B3B)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 40,
                                            spreadRadius: 6),
                                      ],
                                    ),
                                    child: ColorFiltered(
                                      key: const Key('bossRage'),
                                      colorFilter: ColorFilter.mode(
                                          const Color(0xFFFF2E2E)
                                              .withValues(alpha: 0.35),
                                          BlendMode.srcATop),
                                      child: MonsterPicture(
                                        monster: foe.monster,
                                        size: monSize,
                                      ),
                                    ),
                                  )
                                : _tinted(
                                    widget.foeTint,
                                    MonsterPicture(
                                      monster: foe.monster,
                                      size: monSize,
                                      defeated: cleared,
                                    )),
                          ),
                        ),
                      ),
                    ),
                    // 보스 장비 6개 세트: 각성자 둘레 세트 빛 (11-11 #82)
                    if (widget.aura != null)
                      Positioned(
                        key: const Key('battleAura'),
                        left: w * 0.02 + lunge * w * 0.08 - heroW * 0.1,
                        bottom: 10,
                        width: heroW * 1.2,
                        height: h * 0.62,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [
                                widget.aura!.withValues(
                                    alpha: 0.45 + 0.15 * math.sin(t * math.pi)),
                                widget.aura!.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    // 각성자 (달려들고, 맞으면 붉게 번쩍)
                    Positioned(
                      left: w * 0.02 + lunge * w * 0.08,
                      bottom: 26 + lunge * 6,
                      width: heroW,
                      height: h * 0.52,
                      child: Transform.rotate(
                        angle: lunge * 0.06 - hurt * 0.05,
                        alignment: Alignment.bottomCenter,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                              const Color(0xFFFF4D4D)
                                  .withValues(alpha: hurt * 0.45),
                              BlendMode.srcATop),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            // 쉬는 동안 살짝 숨 쉬듯 늘었다 줄었다 한다
                            child: Transform.scale(
                              scaleY: swinging || cleared
                                  ? 1
                                  : 1 + math.sin(t * math.pi * 2) * 0.015,
                              alignment: Alignment.bottomCenter,
                              child: _tinted(
                                  widget.heroTint,
                                  HeroSprite(
                                      look: widget.look,
                                      pose: cleared
                                          ? HeroPose.victory
                                          : widget.defeated
                                              ? HeroPose.tired
                                              : swinging
                                                  ? HeroPose.attack
                                                  : HeroPose.idle)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 타격 효과
                    if (cleared)
                      Positioned(
                        left: monLeft - 10,
                        top: monTop - 60 - _seg(t, 0, 1) * 20,
                        width: monSize + 20,
                        height: monSize + 80,
                        child: Opacity(
                          opacity: idle ? 1 : _seg(t, 0, 0.3),
                          child: Image.asset('assets/images/fx_purify.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      )
                    else if (hitting && widget.skill)
                      Positioned(
                        left: hitX - w * 0.35 + hit * w * 0.12,
                        top: hitY - w * 0.2,
                        width: w * 0.6,
                        height: w * 0.45,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.4, 0.7),
                          child: Transform.rotate(
                            angle: -0.3 + hit * 0.5,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  _kind(context) == SpiritKind.fire
                                      ? Colors.white
                                      : spiritColor(_kind(context)),
                                  BlendMode.modulate),
                              child: Image.asset('assets/images/fx_slash.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox()),
                            ),
                          ),
                        ),
                      )
                    else if (hitting)
                      Positioned(
                        left: hitX - 45,
                        top: hitY - 40,
                        width: 90,
                        height: 80,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.32, 0.55),
                          child: Transform.scale(
                            scale: 0.5 + _seg(t, 0.22, 0.32) * 0.8,
                            child: _tinted(
                                widget.hitElement == null
                                    ? null
                                    : elementColor(widget.hitElement),
                                Image.asset('assets/images/fx_hit.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox()),
                                alpha: 0.55),
                          ),
                        ),
                      ),
                    // 금빛 불꽃 조각
                    if (hitting)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SparkPainter(
                              origin: Offset(hitX, hitY),
                              progress: _seg(t, 0.22, 0.75),
                              seed: widget.beat,
                              count: widget.skill ? 22 : 12,
                              reach: widget.skill ? 120 : 70,
                            ),
                          ),
                        ),
                      ),
                    // 준 피해: 몬스터 머리 위로 떠오르며 사라진다
                    if (hitting || cleared)
                      Positioned(
                        left: monLeft,
                        width: monSize,
                        top: monTop - 10 - (cleared ? 0 : _seg(t, 0.22, 0.8) * 40),
                        child: Opacity(
                          opacity: cleared ? 1 : 1 - _seg(t, 0.6, 0.9),
                          child: Center(
                            child: Transform.scale(
                              scale: cleared
                                  ? 1
                                  : 0.7 +
                                      Curves.elasticOut
                                              .transform(_seg(t, 0.22, 0.45)) *
                                          0.4,
                              // 피해 숫자 (11-11 #81): 보통 흰색, 치명타 크고 노랑, 약점 빨강
                              child: _Outlined(
                                cleared ? '사냥!' : '-${comma(widget.dealt)}',
                                size: widget.crit || widget.skill ? 38 : 28,
                                color: cleared
                                    ? AppColors.goldBright
                                    : widget.crit || widget.skill
                                        ? const Color(0xFFFFE14D)
                                        : widget.superHit
                                            ? const Color(0xFFFF5A5A)
                                            : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 받은 피해: 각성자 머리 위
                    if (hurt > 0)
                      Positioned(
                        left: w * 0.08,
                        width: heroW * 0.6,
                        bottom: 26 + h * 0.52 - 10 + _seg(t, 0.6, 0.95) * 30,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.8, 0.98),
                          child: Center(
                            // 막으면 파랑, 아니면 흰색
                            child: _Outlined('-${comma(widget.taken)}',
                                size: 22,
                                color: widget.guard != null
                                    ? const Color(0xFF6FB8FF)
                                    : Colors.white),
                          ),
                        ),
                      ),
                    // 일격: 화면 전체가 금빛으로 번쩍
                    if (hitting && widget.skill)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: const Color(0xFFFFF3C8).withValues(
                                alpha: (1 - _seg(t, 0.22, 0.4)) * 0.45),
                          ),
                        ),
                      ),
                    // 방어 태세: 각성자 둘레 푸른 방패
                    if (widget.stance && !cleared)
                      Positioned(
                        left: w * 0.06 + lunge * w * 0.08,
                        bottom: 30,
                        width: heroW * 0.8,
                        height: h * 0.5,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(80),
                              border: Border.all(
                                  color: AppColors.mana.withValues(alpha: 0.7),
                                  width: 3),
                              color: AppColors.mana.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                    // 막기 결과
                    if (widget.guard != null && !idle)
                      Positioned(
                        left: w * 0.1,
                        width: heroW * 0.8,
                        top: h * 0.28 - _seg(t, 0.4, 0.9) * 20,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.75, 0.98),
                          child: Column(children: [
                            Icon(Icons.shield_rounded,
                                size: widget.guard == GuardResult.perfect
                                    ? 64
                                    : 48,
                                color: widget.guard == GuardResult.perfect
                                    ? AppColors.goldBright
                                    : AppColors.mana),
                            _Outlined(
                                widget.guard == GuardResult.perfect
                                    ? '완벽한 막기!'
                                    : '막았다!',
                                size: 22,
                                color: widget.guard == GuardResult.perfect
                                    ? AppColors.goldBright
                                    : Colors.white),
                          ]),
                        ),
                      ),
                    // 강한 공격 예고: 화면을 누르면 막기
                    if (widget.warning != null)
                      Positioned(
                        key: const Key('guardWarning'),
                        left: 0,
                        right: 0,
                        top: monTop - 46,
                        child: IgnorePointer(
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xDDB3261E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white70),
                              ),
                              child: Text('⚠ ${widget.warning}',
                                  style: AppText.title(16,
                                      color: Colors.white)),
                            ),
                          ]),
                        ),
                      ),
                    if (widget.warning != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: h * 0.42,
                        child: IgnorePointer(
                          child: Center(
                            child: _Outlined(
                                widget.guarded ? '막기 준비!' : '화면을 눌러 막기!',
                                size: 20,
                                color: widget.guarded
                                    ? AppColors.mana
                                    : AppColors.goldBright),
                          ),
                        ),
                      ),
                    // 회복: 초록 숫자
                    if (widget.healed > 0)
                      Positioned(
                        left: w * 0.06,
                        width: heroW * 0.7,
                        bottom: h * 0.5,
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('heal_${widget.heals}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            builder: (_, v, __) => Opacity(
                              opacity: (1 - v).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -24 * v),
                                child: Center(
                                  child: _Outlined('+${comma(widget.healed)}',
                                      size: 22,
                                      color: const Color(0xFF6BE38A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 승리: 빛 조각으로 흩어지고 마석·재료가 튀어나온다
                    if (cleared && !idle) ...[
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SparkPainter(
                              origin: Offset(monLeft + monSize / 2,
                                  monTop + monSize / 2),
                              progress: _seg(t, 0, 0.9),
                              seed: widget.beat + 7,
                              count: 28,
                              reach: 140,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          left: monLeft +
                              monSize / 2 -
                              14 +
                              (i - 1) * 30 * _seg(t, 0, 0.5) +
                              _seg(t, 0.5, 1) * w * 0.25,
                          top: monTop +
                              monSize / 2 -
                              math.sin(_seg(t, 0, 0.5) * math.pi) * 60 +
                              _seg(t, 0.5, 1) * h * 0.35,
                          child: Opacity(
                            opacity: 1 - _seg(t, 0.8, 1),
                            child: i == 1
                                ? const GameIcon('mana_stone',
                                    size: 28, fallback: Icons.diamond_rounded)
                                : const Icon(Icons.inventory_2_rounded,
                                    size: 24, color: AppColors.goldBright),
                          ),
                        ),
                    ],
                    // 패배: 화면이 어두워진다
                    if (widget.defeated)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 0.62),
                            duration: const Duration(milliseconds: 700),
                            builder: (_, v, __) => ColoredBox(
                                key: const Key('battleDefeatDim'),
                                color: Colors.black.withValues(alpha: v)),
                          ),
                        ),
                      ),
                    // 보스 등장: 이름 띠
                    AnimatedBuilder(
                      animation: _boss,
                      builder: (_, __) {
                        final b = _boss.value;
                        if (b <= 0 || b >= 1 || !foe.isBoss) {
                          return const SizedBox.shrink();
                        }
                        final a = b < 0.15
                            ? b / 0.15
                            : b > 0.8
                                ? (1 - b) / 0.2
                                : 1.0;
                        return Positioned(
                          left: 0,
                          right: 0,
                          top: h * 0.42,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: a,
                              child: Container(
                                key: const Key('bossIntro'),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: const Color(0xCC1A0B0B),
                                child: Column(children: [
                                  Text('BOSS',
                                      style: AppText.title(14,
                                          color: const Color(0xFFFF8A65))),
                                  Text(foe.name,
                                      style: AppText.title(24,
                                          color: AppColors.goldBright)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // 층 표시
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xCC14173E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: foe.isBoss
                                    ? AppColors.gauge
                                    : AppColors.gold.withValues(alpha: 0.8)),
                          ),
                          child: Text(widget.floorLabel,
                              style: AppText.title(17,
                                  color: foe.isBoss
                                      ? AppColors.gauge
                                      : AppColors.goldBright)),
                        ),
                      ),
                    ),
                    // 정령의 응원
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Row(children: [
                        Transform.translate(
                          offset: Offset(
                              widget.petDash && !idle
                                  ? math.sin(_seg(t, 0, 0.5) * math.pi) *
                                      w *
                                      0.45
                                  : 0,
                              -math.sin(t * math.pi) * 6),
                          child: const CompanionArt(size: 54),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF5E6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                              cleared
                                  ? '잡았어!'
                                  : widget.defeated
                                      ? '괜찮아? 오늘은 좀 쉬자.'
                                  : widget.warning != null
                                      ? '조심해!'
                                      : widget.enraged
                                          ? '화났어, 조심!'
                                  : widget.skill && hitting
                                      ? skillLabel(context)
                                      : '할 수 있어!',
                              style: const TextStyle(
                                  color: AppColors.night,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ],
                 ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// 발밑 타원 그림자
class _Shadow extends StatelessWidget {
  const _Shadow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
            Radius.elliptical(width / 2, width * 0.08)),
        color: const Color(0x66000000),
      ),
    );
  }
}

/// 테두리가 있는 큰 숫자 (어느 배경에서도 읽히게)
class _Outlined extends StatelessWidget {
  const _Outlined(this.text, {required this.size, required this.color});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = AppText.title(size, color: color);
    return Stack(children: [
      Text(text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = const Color(0xFF1B1030),
          )),
      Text(text, style: base),
    ]);
  }
}

/// 타격 지점에서 사방으로 튀는 금빛 불꽃 조각
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.origin,
    required this.progress,
    required this.seed,
    required this.count,
    required this.reach,
  });

  final Offset origin;
  final double progress;
  final int seed;
  final int count;
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rng = math.Random(seed);
    final ease = Curves.easeOut.transform(progress);
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = reach * (0.4 + rng.nextDouble() * 0.6) * ease;
      final fall = 30 * progress * progress; // 살짝 떨어진다
      final p = origin +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist + fall);
      final r = (2 + rng.nextDouble() * 3) * (1 - progress);
      final paint = Paint()
        ..color = Color.lerp(const Color(0xFFFFF3C8), const Color(0xFFF0A93B),
                rng.nextDouble())!
            .withValues(alpha: 1 - progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.progress != progress || old.seed != seed;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.look, this.size = 46});

  final HeroLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2B2F6B),
        border: Border.all(color: AppColors.goldBright, width: 1.6),
      ),
      child: ClipOval(
        child: Image.asset(
          look == HeroLook.female
              ? 'assets/images/portrait_female.png'
              : 'assets/images/portrait_male.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _HpColumn extends StatelessWidget {
  const _HpColumn({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.colors,
    this.note,
    this.alignEnd = false,
    this.nameColor = AppColors.text,
    this.element,
    this.showElement = false,
  });

  /// 몬스터 속성 아이콘 (11-11 #63)
  final Element? element;
  final bool showElement;

  final String name;
  final Color nameColor;
  final int hp;
  final int maxHp;
  final List<Color> colors;
  final String? note;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (showElement) ...[
              ElementIcon(element, size: 16),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: nameColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(note!,
                  style:
                      const TextStyle(color: Color(0xFFE57373), fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        GlowBar(
            ratio: maxHp == 0 ? 0 : hp / maxHp, colors: colors, height: 11),
        const SizedBox(height: 3),
        Text('HP ${comma(hp)} / ${comma(maxHp)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// 둥근 스킬 버튼: 바깥 고리가 충전 정도
class _SkillOrb extends StatelessWidget {
  const _SkillOrb({
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.away = false,
    this.size = 104,
  });

  final double size;
  final double ratio;
  final bool ready;
  final VoidCallback onPressed;

  /// 정령이 원정 중이라 쓸 수 없다
  final bool away;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: ready ? onPressed : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    color: AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                Container(
                  width: size * 0.79,
                  height: size * 0.79,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: ready
                          ? const [Color(0xFFFFF4C8), Color(0xFFE8B04A),
                              Color(0xFF8A5A1C)]
                          : const [Color(0xFF4A4F86), Color(0xFF262A5A),
                              Color(0xFF181B45)],
                    ),
                    border: Border.all(
                        color: AppColors.goldBright, width: ready ? 2 : 1),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.8),
                                blurRadius: 26,
                                spreadRadius: 2),
                          ]
                        : null,
                  ),
                  child: Icon(Icons.flare_rounded,
                      size: size * 0.44,
                      color: ready
                          ? const Color(0xFF5A3410)
                          : AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          key: const Key('skillButton'),
          onTap: ready ? onPressed : null,
          child: Text(
              away
                  ? '원정 중'
                  : ready
                      ? skillLabel(context)
                      : '충전 중',
              style: AppText.title(15,
                  color: ready ? AppColors.goldBright : AppColors.textMuted)),
        ),
      ],
    );
  }
}

/// tired: HP 0으로 싸울 수 없을 때 (11-10)
enum HeroPose { idle, attack, victory, tired }

/// 각성자 SD 그림 (공격·승리 자세). 그림이 없으면 서 있는 그림이나 초상화로 대신한다.
/// 파일 이름: hero_attack_male.png, hero_victory_female.png ...
class HeroSprite extends StatelessWidget {
  const HeroSprite({super.key, required this.look, required this.pose});

  final HeroLook look;
  final HeroPose pose;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/hero_${pose.name}_${look.name}.png',
      fit: BoxFit.contain,
      semanticLabel: '각성자',
      errorBuilder: (_, __, ___) => look == HeroLook.male
          ? Image.asset('assets/images/hero_chibi_male.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  size: 140, color: AppColors.textMuted))
          : const Padding(
              padding: EdgeInsets.only(top: 60),
              child: _Avatar(look: HeroLook.female, size: 120),
            ),
    );
  }
}

/// 몬스터 그림. 그림 파일이 없으면 아이콘으로 대신한다.
class MonsterPicture extends StatelessWidget {
  const MonsterPicture({
    super.key,
    required this.monster,
    this.size = 64,
    this.defeated = false,
  });

  final MonsterId monster;
  final double size;

  /// true 면 쓰러진 모습 (기울어지며 흐려진다, 11-10 사냥)
  final bool defeated;

  /// 그림을 흑백으로 바꾼 뒤 [argb] 색을 입힌다 (투명한 곳은 그대로)
  static ColorFilter tintFilter(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255 * 1.35;
    final g = ((argb >> 8) & 0xFF) / 255 * 1.35;
    final b = (argb & 0xFF) / 255 * 1.35;
    return ColorFilter.matrix([
      0.30 * r, 0.59 * r, 0.11 * r, 0, 0,
      0.30 * g, 0.59 * g, 0.11 * g, 0, 0,
      0.30 * b, 0.59 * b, 0.11 * b, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  static IconData iconOf(MonsterId id) => switch (id) {
        MonsterId.ashSlime => Icons.water_drop_rounded,
        MonsterId.labyrinthBat => Icons.nights_stay_rounded,
        MonsterId.roughWaterSpirit => Icons.waves_rounded,
        MonsterId.shadowButterfly => Icons.flutter_dash_rounded,
        MonsterId.lostStoneSpirit => Icons.landscape_rounded,
        MonsterId.labyrinthWarden => Icons.shield_moon_rounded,
        MonsterId.fireSlimeKing => Icons.local_fire_department_rounded,
        MonsterId.frostWolfKing => Icons.ac_unit_rounded,
        MonsterId.ancientTreant => Icons.park_rounded,
        MonsterId.shadowBatQueen => Icons.dark_mode_rounded,
        MonsterId.thunderGriffin => Icons.bolt_rounded,
        MonsterId.giantRat => Icons.pest_control_rodent_rounded,
        MonsterId.hornRabbit => Icons.cruelty_free_rounded,
        MonsterId.babyBoar => Icons.savings_rounded,
        MonsterId.fireSlime ||
        MonsterId.waterSlime ||
        MonsterId.windSlime ||
        MonsterId.earthSlime ||
        MonsterId.lightSlime ||
        MonsterId.darkSlime ||
        MonsterId.iceSlime ||
        MonsterId.thunderSlime ||
        MonsterId.metalSlime ||
        MonsterId.poisonSlime =>
          Icons.water_drop_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = Monsters.info(monster);
    final picture = Image.asset(
      info.asset,
      width: size,
      height: size,
      semanticLabel: info.name,
      errorBuilder: (_, __, ___) => info.tint != null
          // 속성 슬라임 그림이 오기 전에는 기본 슬라임 그림에 색을 입힌다
          ? ColorFiltered(
              colorFilter: tintFilter(info.tint!),
              child: Image.asset(
                Monsters.info(MonsterId.ashSlime).asset,
                width: size,
                height: size,
                semanticLabel: info.name,
              ),
            )
          : Icon(
              iconOf(monster),
              size: size * 0.7,
              color: info.isBoss && info.element != null
                  ? elementColor(info.element)
                  : const Color(0xFFB8B2C8),
              semanticLabel: info.name,
            ),
    );
    if (!defeated) return picture;
    // 사냥한 몬스터는 쓰러지고 사라진다
    return Opacity(
      opacity: 0.18,
      child: Transform.translate(
        offset: Offset(0, size * 0.12),
        child: Transform.rotate(angle: 0.5, child: picture),
      ),
    );
  }
}

SpiritKind _kind(BuildContext context) =>
    BulssiScope.maybeOf(context)?.kind ?? SpiritKind.fire;


/// 색을 살짝 입힌다 (상태 이상·속성 타격 색)
Widget _tinted(Color? c, Widget child, {double alpha = 0.32}) => c == null
    ? child
    : ColorFiltered(
        colorFilter: ColorFilter.mode(c.withValues(alpha: alpha), BlendMode.srcATop),
        child: child);

/// 상태 이상 (11-11 #81). 그림이 오기 전에는 아이콘.
enum _Status { poison, burn, frozen, dazzle, bound, stance }

extension on _Status {
  String get label => switch (this) {
        _Status.poison => '중독',
        _Status.burn => '화상',
        _Status.frozen => '빙결',
        _Status.dazzle => '눈부심',
        _Status.bound => '묶임',
        _Status.stance => '방어 태세',
      };

  IconData get icon => switch (this) {
        _Status.poison => Icons.bubble_chart_rounded,
        _Status.burn => Icons.local_fire_department_rounded,
        _Status.frozen => Icons.ac_unit_rounded,
        _Status.dazzle => Icons.flare_rounded,
        _Status.bound => Icons.link_rounded,
        _Status.stance => Icons.shield_rounded,
      };

  Color get color => switch (this) {
        _Status.poison => const Color(0xFF7BD86A),
        _Status.burn => const Color(0xFFFF8A4C),
        _Status.frozen => const Color(0xFF8FD3FF),
        _Status.dazzle => const Color(0xFFFFF1A0),
        _Status.bound => const Color(0xFFE0B3FF),
        _Status.stance => const Color(0xFF6FB8FF),
      };

  String get asset => 'assets/images/status_$name.png';
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons(this.list);

  final List<_Status> list;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 4, children: [
        for (final s in list)
          Tooltip(
            message: s.label,
            child: Container(
              key: Key('status_${s.name}'),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF14173E),
                shape: BoxShape.circle,
                border: Border.all(color: s.color, width: 1.4),
              ),
              child: Image.asset(s.asset,
                  errorBuilder: (_, __, ___) =>
                      Icon(s.icon, size: 14, color: s.color)),
            ),
          ),
      ]);
}

/// 배경 위 시간 색감·속성 입자·비·눈 (11-11 #81, 그림 없이 코드로)
class _AmbientPainter extends CustomPainter {
  _AmbientPainter(
      {required this.t, this.element, this.hour, this.weather});

  final double t;
  final Element? element;
  final int? hour;
  final WeatherKind? weather;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 시간 색감: 낮은 그대로, 노을(16~19시)은 주황, 밤(19~6시)은 남색
    final hr = hour;
    if (hr != null) {
      Color? tint;
      if (hr >= 16 && hr < 19) tint = const Color(0x38FF8A3D);
      if (hr >= 19 || hr < 6) tint = const Color(0x5A0B1240);
      if (tint != null) canvas.drawRect(Offset.zero & size, Paint()..color = tint);
    }
    final rng = math.Random(11);
    final p = Paint();
    // 몬스터 속성 입자
    final e = element;
    if (e != null) {
      final c = elementColor(e);
      for (var i = 0; i < 22; i++) {
        final x0 = rng.nextDouble() * w;
        final ph = rng.nextDouble();
        final sp = 0.5 + rng.nextDouble();
        final v = (t * sp + ph) % 1.0;
        final a = math.sin(v * math.pi) * 0.75;
        p.color = c.withValues(alpha: a);
        switch (e) {
          case Element.fire:
            // 불똥이 위로
            canvas.drawCircle(
                Offset(x0 + math.sin(v * 6 + i) * 8, h * (1 - v)), 2.2, p);
          case Element.ice:
            // 눈송이가 아래로
            _flake(canvas, Offset(x0 + math.sin(v * 4 + i) * 10, h * v), 4, p);
          case Element.water || Element.poison:
            // 물방울·기포가 위로
            p
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4;
            canvas.drawCircle(Offset(x0, h * (1 - v)), 3 + (i % 3).toDouble(), p);
            p.style = PaintingStyle.fill;
          case Element.thunder:
            // 번쩍이는 작은 번개
            if (a > 0.55) {
              p.strokeWidth = 2;
              final o = Offset(x0, h * ((ph + i * 0.13) % 1.0));
              canvas.drawLine(o, o + const Offset(5, 8), p);
              canvas.drawLine(o + const Offset(5, 8), o + const Offset(1, 12), p);
            }
          case Element.wind:
            // 옆으로 흐르는 바람 줄
            p.strokeWidth = 1.6;
            final y = h * ((ph + i * 0.07) % 1.0);
            final x = w * v * 1.2 - 40;
            canvas.drawLine(Offset(x, y), Offset(x + 30, y - 2), p);
          case Element.earth || Element.metal:
            // 흙먼지·금속 반짝임이 천천히
            canvas.drawCircle(Offset(x0, h * (0.6 + 0.4 * ((ph + v * 0.2) % 1.0))),
                e == Element.metal ? 1.6 : 2.4, p);
          case Element.light || Element.dark:
            // 빛 알갱이·어둠 안개
            canvas.drawCircle(Offset(x0, h * ((ph - v * 0.3) % 1.0)),
                e == Element.light ? 2.0 : 6.0,
                p..color = c.withValues(alpha: e == Element.dark ? a * 0.35 : a));
        }
      }
    }
    // 비·눈 (실제 날씨)
    final wk = weather;
    if (wk == WeatherKind.rain) {
      p
        ..color = const Color(0x88B8D4FF)
        ..strokeWidth = 1.3;
      for (var i = 0; i < 60; i++) {
        final x = rng.nextDouble() * (w + 40);
        final v = (t * 4 + rng.nextDouble()) % 1.0;
        final y = v * (h + 20) - 20;
        canvas.drawLine(Offset(x, y), Offset(x - 4, y + 14), p);
      }
    } else if (wk == WeatherKind.snow) {
      p.color = const Color(0xCCFFFFFF);
      for (var i = 0; i < 40; i++) {
        final x = rng.nextDouble() * w;
        final v = (t * (0.6 + rng.nextDouble() * 0.6) + rng.nextDouble()) % 1.0;
        canvas.drawCircle(
            Offset(x + math.sin(v * 8 + i) * 6, v * h), 1.6 + (i % 3) * 0.6, p);
      }
    }
  }

  void _flake(Canvas c, Offset o, double r, Paint p) {
    p.strokeWidth = 1.2;
    for (var k = 0; k < 3; k++) {
      final a = k * math.pi / 3;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      c.drawLine(o - d, o + d, p);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.t != t ||
      old.element != element ||
      old.hour != hour ||
      old.weather != weather;
}
