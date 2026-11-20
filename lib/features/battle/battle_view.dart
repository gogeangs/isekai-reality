import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../data/sound/sfx.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart' show PortraitFace;
import '../../theme/ornaments.dart';
import 'auto_use_window.dart';
import 'season_painter.dart';
import 'modifier_view.dart';
import '../bulssi/bulssi_mood.dart';
import '../bulssi/spirit_art.dart';
import 'element_view.dart';
import 'hero_rig.dart';
import '../smithy/set_aura.dart';
import '../jobs/skill_icon.dart';

/// 자동 전투 화면 (목업 구도): 동굴 배경 위 각성자 vs 몬스터,
/// 아래에 체력 막대, 정화 수, 둥근 스킬 버튼 '정령의 일격'.
///
/// 묶음 75 #325: 스킬 숙련도 — 전투 화면이 열릴 때 대기 · 힘을 맞추고, 끝나면(또는 닫히면) 쓴 스킬을 센다.
/// 앱이 한 번 연결한다 (연습 판은 훈련장이 따로 센다)
class SkillMasteryHook {
  SkillMasteryHook._();
  static void Function(Battle b)? setup;
  static void Function(Battle b)? finished;

  static void count(Battle b) {
    if (b.skillsCounted || b.practice) return;
    b.skillsCounted = true;
    if (b.skillUses.isNotEmpty) finished?.call(b);
  }
}

/// [tickInterval] 마다 [Battle.tick] 을 부르고, 끝나면 [onFinished] 를 한 번 부른다.
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onFinished,
    this.tickInterval = const Duration(milliseconds: 900),
    this.playerName = '각성자',
    this.look = HeroLook.male,
    this.heroJob,
    this.vibrate = false,
    this.sound = false,
    this.fast = false,
    this.onFastChanged,
    this.onAutoChanged,
    this.poisonTip = false,
    this.onPoisonTipShown,
    this.aura,
    this.hour,
    this.season,
    this.background,
    this.backgroundOf,
    this.weapon,
    this.onFloor,
    this.jobSkills = const [],
    this.emptySlots = false,
    this.jobMp,
    this.onJobSkill,
    this.onMasterySkill,
    this.fit = false,
    this.floorLabelOf,
    this.counterOf,
    this.allyArts = const [],
    this.practiceHud = false,
    this.elementHints = false,
  });

  /// 묶음 75 #324: 훈련장 연습 — 허수아비 HP 대신 「끝없는 허수아비 ∞」 + 「연습 기록」 한 줄
  final bool practiceHud;

  /// 묶음 75 #324: 칠 때마다 피해 숫자 위 「효과 좋음」 · 「잘 안 들어요」 (속성 허수아비)
  final bool elementHints;

  /// 묶음 33 #202: 화면 남은 높이에 맞춰 전투 장면을 줄인다 (스크롤 없이 한 화면)
  final bool fit;

  /// 묶음 52 #243: 3막 동료 그림 (전신 그림 경로, 없으면 직업 색 동그라미) — battle.allies 순서
  final List<({String? art, String? face, int color})> allyArts;

  /// 묶음 43 훈련장: 층 이름 대신 쓰는 글 (「1판 · 허수아비」 등)
  final String Function(Battle b)? floorLabelOf;

  /// 묶음 43 훈련장: 정화한 수 자리에 쓰는 글 (시련은 「○판」)
  final String Function(Battle b)? counterOf;

  /// 전투 칸의 직업 스킬 (묶음 31 #198): 스킬·MP 비용·단계 세기.
  /// 버튼을 누르면 [onJobSkill] 이 MP를 쓴다. 숙련 스킬 칸은 전투([Battle.masteryActives])에서
  final List<(JobSkill, int, double)> jobSkills;

  /// 묶음 35: 스킬 페이지가 열렸으면 빈 스킬 칸을 btn_skill_empty 로 보여 준다
  final bool emptySlots;

  /// 숙련 스킬을 썼을 때 (장사·의뢰 동전 튕기기 금화 등)
  final Future<void> Function(Mastery)? onMasterySkill;

  /// 지금 MP
  final int Function()? jobMp;

  /// MP를 쓴다 (모자라면 false)
  final Future<bool> Function(JobSkill)? onJobSkill;

  /// 입은 무기 종류 (#81 2단계: 부위 애니메이션 손에 든 무기·공격 동작). 없으면 맨손
  final WeaponKind? weapon;

  /// 층이 바뀔 때 (던전 층별 단서, 묶음 19 #7)
  final ValueChanged<int>? onFloor;

  /// 보스 장비 6개 세트 외형 빛 (11-11 #82)
  final Color? aura;

  /// 지금 시각 (낮·노을·밤 색감, 11-11 #81). 없으면 낮.
  final int? hour;

  /// 계절 (봄 꽃잎·여름 반딧불·가을 낙엽·겨울 눈송이, 묶음 14 A4). 없으면 계절 입자 없음
  final Season? season;

  /// 전투 배경 그림 (묶음 13 C7: 필드는 장소 종류에 맞춰). 없으면 기본
  final String? background;

  /// 층마다 바뀌는 배경 (던전 1~3층·보스 방). 있으면 [background] 보다 먼저
  final String? Function(int floor, Foe foe)? backgroundOf;


  final Battle battle;
  final VoidCallback onFinished;
  final Duration tickInterval;
  final String playerName;
  final HeroLook look;

  /// 묶음 76 #307: 주인공 직업 그림 ('warrior' …, 없으면 맨손 새 주인공)
  final String? heroJob;

  /// 때리고 막을 때 진동 (설정 「진동」, 11-11 #75)
  final bool vibrate;

  /// 효과음 (설정 「효과음」)
  final bool sound;

  /// 2배속으로 시작 (마지막에 고른 속도를 기억한다)
  final bool fast;
  final ValueChanged<bool>? onFastChanged;

  /// 자동 마시기 설정을 바꿨을 때 (가방·설정과 같은 설정, 11-11 #93)
  final void Function(int hp, bool cure)? onAutoChanged;

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

  /// 묶음 73 #306: 동료마다 공격(칸 그림)을 몇 번 했는지 · 마지막 피해 · 스킬(바로)인지
  final Map<int, ({int swing, int dealt, bool now})> _allySwing = {};

  void _allyStruck(int i, int dealt, {bool now = false}) {
    final old = _allySwing[i]?.swing ?? 0;
    _allySwing[i] = (swing: old + 1, dealt: dealt, now: now);
  }

  late bool _fast = widget.fast;

  /// 예고가 뜬 뒤 흐른 실제 시간 (2배속이어도 판정은 실제 시간)
  final _warnClock = Stopwatch();
  bool _warning = false;
  bool _tapped = false;

  bool _tipShown = false;
  bool _tipOpen = false;

  /// 자동 마시기 창이 열린 동안 전투를 멈춘다
  bool _paused = false;

  /// 전투 기록 두 줄
  final List<String> _log = [];

  /// 묶음 34: 분신의 특별한 공격 문장 (몇 박자 동안 위에 띄운다)
  String? _move;
  int _moveBeat = 0;

  /// 보스가 나오는 순간 (이름 띠 + 확대, 11-11 #81)
  int _bossBeat = 0;

  /// 강한 타격 뒤 잠깐 멈춤 (손맛)
  static const _hitStop = Duration(milliseconds: 120);

  Battle get _b => widget.battle;

  bool get _autoOn => _b.autoHp > 0 || _b.autoCure;

  Duration get _interval =>
      _fast ? widget.tickInterval ~/ 2 : widget.tickInterval;

  @override
  void initState() {
    super.initState();
    SkillMasteryHook.setup?.call(_b);
    _afterTick(first: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SkillMasteryHook.count(_b);
    super.dispose();
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _step);
  }

  void _step() {
    if (!mounted || _b.isOver || _tipOpen || _paused) return;
    final floorBefore = _b.floor;
    setState(() {
      final before = _b.ticks;
      _b.tick();
      if (_b.ticks != before) {
        _beat++; // 층이 바뀌는 틱은 연출하지 않는다
        for (var i = 0; i < _b.allies.length; i++) {
          if (_b.allies[i].lastDealt > 0) _allyStruck(i, _b.allies[i].lastDealt);
        }
      }
      if (_b.floor != floorBefore && _b.foe.isBoss) _bossBeat++;
      _record();
      // 묶음 34: 분신의 특별한 공격 문장 (위쪽 띠 + 기록)
      if (_b.lastAllySkill case final s?) _addLog(s);
      if (_b.lastMove case final m?) {
        _addLog(m);
        _move = m;
        _moveBeat = _beat;
      }
      // 자동으로 마시면 전투 기록 한 줄 (11-11 #93)
      if (_b.autoHealed) _addLog('회복 물약을 자동으로 마셨다');
      if (_b.autoCured) _addLog('물약을 자동으로 마셨다');
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
      final window = Battle.guardWindow * _b.guardEase + const Duration(milliseconds: 60);
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
    _addLog(line);
  }

  void _addLog(String line) {
    _log.add(line);
    if (_log.length > 2) _log.removeAt(0);
  }

  /// 자동 마시기 창: 전투를 잠깐 멈추고, 닫으면 이어 간다 (11-11 #93)
  Future<void> _autoWindow() async {
    _timer?.cancel();
    _paused = true;
    await showAutoUseWindow(context,
        hp: _b.autoHp, cure: _b.autoCure, onChanged: (hp, cure) {
      _b
        ..autoHp = hp
        ..autoCure = cure;
      widget.onAutoChanged?.call(hp, cure);
    });
    if (!mounted) return;
    setState(() => _paused = false);
    if (!_b.isOver && !_tipOpen) _afterTick(first: true);
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

  /// 화면 아무 곳이나 누르면 막기 (예고 하나에 한 번만, 일찍 눌러도 벌 없음)
  void _onPointer(PointerDownEvent _) {
    if (!_warning || _tapped || _b.isOver) return;
    final r = Battle.judgeGuard(_warnClock.elapsed, ease: _b.guardEase);
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
                      style: AppText.title(19)),
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

  Future<void> _masterySkill(Mastery m) async {
    if (_b.isOver) return;
    var ok = false;
    setState(() {
      ok = _b.useMasterySkill(m);
      if (ok) _record();
    });
    if (!ok) return;
    await widget.onMasterySkill?.call(m);
    if (widget.vibrate) HapticFeedback.mediumImpact();
    if (mounted) setState(() {});
    _checkEnd();
  }

  Future<void> _jobSkill(JobSkill s, int cost, double power) async {
    if (_b.isOver) return;
    final mp = widget.jobMp?.call() ?? 0;
    if (mp < cost) {
      setState(() => _log.add('MP가 모자라요'));
      return;
    }
    // 쓸 수 없는 때(이미 써 둠·HP 가득 등)에는 MP를 쓰지 않는다
    final probe = _b.phase == BattlePhase.fighting;
    if (!probe) return;
    var ok = false;
    setState(() {
      ok = _b.useJobSkill(s, power: power);
      if (ok) _record();
    });
    if (!ok) return;
    await widget.onJobSkill?.call(s);
    if (widget.vibrate) HapticFeedback.mediumImpact();
    if (mounted) setState(() {});
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

  int _shownFloor = -1;

  @override
  Widget build(BuildContext context) {
    final foe = _b.foe;
    if (_b.floor != _shownFloor && widget.onFloor != null) {
      _shownFloor = _b.floor;
      final f = _b.floor;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFloor!(f);
      });
    }
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
            mainAxisSize: widget.fit ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _fitScene(_Scene(
                height: widget.fit ? null : 380,
                foe: foe,
                cleared: cleared,
                floorLabel: _floorLabel,
                dealt: _b.lastDealt,
                taken: _b.lastTaken,
                skill: _b.lastWasSkill || _b.lastBash,
                petDash: _b.lastWasSkill,
                look: widget.look,
                heroJob: widget.heroJob,
                weapon: widget.weapon,
                beat: _beat,
                beatDuration: _interval * 0.85,
                warning: warning ? (_b.strongLabel ?? '강한 공격!') : null,
                guarded: _tapped && warning,
                guardButton: _b.heroSkills,
                guard: _b.lastGuard,
                guardBroken: _b.lastGuardBroken,
                enraged: _b.enraged,
                stance: _b.stanceTurns > 0,
                aura: widget.aura,
                crit: _b.lastCrit,
                superHit: _b.lastSuper,
                resisted: _b.lastResist,
                elementHints: widget.elementHints,
                heals: _b.heals,
                healed: _b.lastHealed,
                defeated: _b.phase == BattlePhase.failed,
                bossBeat: _bossBeat,
                hitElement: _b.weaponPotion ?? _b.attackElement,
                heroTint: _heroTint,
                foeTint: _foeTint,
                hour: widget.hour,
                season: widget.season,
                background: widget.backgroundOf?.call(_b.floor, _b.foe) ??
                    widget.background,
                allies: [
                  for (var i = 0; i < _b.allies.length; i++)
                    (
                      art: i < widget.allyArts.length ? widget.allyArts[i].art : null,
                      color: i < widget.allyArts.length
                          ? widget.allyArts[i].color
                          : 0xFF9AA6D8,
                      down: _b.allies[i].down,
                      swing: _allySwing[i]?.swing ?? 0,
                      dealt: _allySwing[i]?.dealt ?? 0,
                      now: _allySwing[i]?.now ?? false,
                    ),
                ],
              )),
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
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          key: const Key('battlePotion'),
                          tooltip: '물약 마시기',
                          visualDensity: VisualDensity.compact,
                          onPressed: _potionSheet,
                          icon: Image.asset('assets/images/btn_potion.webp',
                              width: 30,
                              height: 30,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.local_drink_rounded,
                                  color: AppColors.goldBright)),
                        ),
                        // 물약 줄 끝 작은 「자동」 표시 (11-11 #93)
                        GestureDetector(
                          key: const Key('battleAuto'),
                          onTap: _autoWindow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _autoOn
                                      ? AppColors.goldBright
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.5)),
                            ),
                            child: Text(autoUseLabel(_b.autoHp, _b.autoCure),
                                style: TextStyle(
                                    color: _autoOn
                                        ? AppColors.goldBright
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: widget.practiceHud
                          ? _EndlessDummy(beat: _beat, element: foe.element)
                          : _HpColumn(
                              name: foe.name,
                              nameColor: modGradeColor(foe.grade),
                              element: foe.element,
                              showElement: true,
                              hp: _b.foeHp,
                              maxHp: foe.maxHp,
                              // 묶음 59: 레이드 보스 체력은 숫자 없이 (숨은 값)
                              hideNumbers: _b.raidBoss != null || _b.hideFoeNumbers,
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
                  // 묶음 75 #324: 연습 기록 한 줄 (지난 시간 · 1초당 피해 · 합계, 전투 시간 기준)
                  if (widget.practiceHud)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          () {
                            final secs = TrainingRules.practiceSeconds(_b.ticks).round();
                            final dps = TrainingRules.practiceDps(_b.practiceDealt, _b.ticks);
                            return '연습 기록 · ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')} · '
                                '1초당 피해 ${comma(dps)} · 합계 ${comma(_b.practiceDealt)}';
                          }(),
                          key: const Key('practiceLine'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
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
              // 묶음 52 #243: 3막 동료 (HP 막대 + 끼운 스킬 버튼)
              if (_b.allies.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 0; i < _b.allies.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _AllyCard(
                        key: Key('battleAlly_$i'),
                        ally: _b.allies[i],
                        look: i < widget.allyArts.length ? widget.allyArts[i] : null,
                        onSkill: _b.isOver
                            ? null
                            : () {
                                final before = _b.allies[i].lastDealt;
                                if (_b.useAllySkill(i)) {
                                  setState(() {
                                    _allyStruck(i, math.max(0, _b.allies[i].lastDealt - before), now: true);
                                    if (_b.lastAllySkill case final s?) _addLog(s);
                                  });
                                  _checkEnd();
                                }
                              },
                      ),
                    ),
                  ],
                ]),
              ],
              const SizedBox(height: 10),
              // 묶음 33 #202: 버튼은 한 줄에 최대 5개 (강타·방어 태세·스킬 칸 2·펫), 이름까지
              if (_b.heroSkills) ...[
                _counterRow(),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MiniSkill(
                        key: const Key('bashButton'),
                        label: '강타',
                        icon: Icons.gavel_rounded,
                        art: 'btn_strike',
                        ratio: _b.bashRatio,
                        // 묶음 76 #338: 경고 동안 다른 버튼은 쉬고, 눌러도 막기로만 셈
                        ready: _b.bashReady && !_guardTime,
                        onPressed: _bash,
                      ),
                    ),
                    Expanded(
                      // 묶음 76 #338: 경고(강한 공격 예고) 동안 이 자리가 「막기!」
                      child: _guardTime
                          ? _GuardButton(
                              key: const Key('guardButton'),
                              clock: _warnClock,
                              window: Battle.guardWindow * _b.guardEase,
                              perfect: Battle.guardWindow - Battle.perfectFrom,
                              done: _tapped,
                            )
                          : _MiniSkill(
                        key: const Key('stanceButton'),
                        label: _b.stanceTurns > 0 ? '방어 중' : '방어 태세',
                        icon: Icons.shield_rounded,
                        art: 'btn_guard',
                        ratio: _b.stanceTurns > 0 ? 1 : _b.stanceRatio,
                        ready: _b.stanceReady,
                        active: _b.stanceTurns > 0,
                        onPressed: _stance,
                      ),
                    ),
                    // 묶음 31 #198: 전투 칸 2개 (직업 스킬 MP · 숙련 스킬 몇 턴마다)
                    for (final (sk, cost, power) in widget.jobSkills.take(2))
                      Expanded(
                        child: Builder(builder: (context) {
                          final mp = widget.jobMp?.call() ?? 0;
                          return _MiniSkill(
                            key: Key('battleJob_${sk.name}'),
                            label: JobRules.skill(sk).name,
                            sub: 'MP $cost',
                            icon: Icons.bolt_rounded,
                            artFrame: SkillArt.jobIcon(sk,
                                dim: !(mp >= cost &&
                                    !_b.isOver &&
                                    !_b.skillsLocked)),
                            ratio: cost <= 0 ? 1 : (mp / cost).clamp(0.0, 1.0),
                            ready: mp >= cost && !_b.isOver && !_b.skillsLocked && !_guardTime,
                            ringColor: const Color(0xFFB27BFF),
                            onPressed: () => _jobSkill(sk, cost, power),
                          );
                        }),
                      ),
                    for (final m in _b.masteryActives
                        .take(math.max(0, 2 - widget.jobSkills.length)))
                      Expanded(
                        child: _MiniSkill(
                          key: Key('battleMastery_${m.name}'),
                          label: JobRules.masteryActive(m).name,
                          icon: Icons.auto_awesome,
                          artFrame: SkillArt.masteryIcon(m,
                              active: true, dim: !_b.masteryReady(m)),
                          ratio: _b.masteryRatio(m),
                          ready: _b.masteryReady(m) && !_guardTime,
                          onPressed: () => _masterySkill(m),
                        ),
                      ),
                    // 묶음 35: 스킬 페이지가 열렸는데 칸이 비면 빈 칸 그림
                    for (var i = 0;
                        i <
                            (widget.emptySlots
                                ? math.max(
                                    0,
                                    2 -
                                        widget.jobSkills.take(2).length -
                                        _b.masteryActives
                                            .take(math.max(
                                                0, 2 - widget.jobSkills.length))
                                            .length)
                                : 0);
                        i++)
                      Expanded(
                        child: _MiniSkill(
                          key: Key('battleEmpty_$i'),
                          label: '빈 칸',
                          icon: Icons.add_rounded,
                          art: 'btn_skill_empty',
                          ratio: 0,
                          ready: false,
                          onPressed: () {},
                        ),
                      ),
                    Expanded(
                      child: _SkillOrb(
                        ratio: _b.skillRatio,
                        ready: _b.skillReady && !_guardTime,
                        away: _b.skillDisabled,
                        onPressed: _skill,
                        size: 56,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ] else
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
                                  _counter,
                                  style: AppText.title(19,
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
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GameGlyph(
                                        _fast ? Glyph.fast : Glyph.play,
                                        size: 13,
                                        dim: !_fast),
                                    const SizedBox(width: 3),
                                    Text(_fast ? '2배' : '1배',
                                        style: TextStyle(
                                            color: _fast
                                                ? AppColors.goldBright
                                                : AppColors.textMuted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                  ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SkillOrb(
                    ratio: _b.skillRatio,
                    ready: _b.skillReady,
                    away: _b.skillDisabled,
                    onPressed: _skill,
                    size: 104,
                  ),
                ],
              ),
            ],
          ),
          if (_move != null && _beat - _moveBeat < 3 && !_b.isOver)
            Positioned(
              left: 12,
              right: 12,
              top: 34,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    key: const Key('ashMoveBanner'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1424),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB9B2C9)),
                    ),
                    child: Text(_move!,
                        textAlign: TextAlign.center,
                        style: AppText.title(15, color: AppColors.text)),
                  ),
                ),
              ),
            ),
          if (_tipOpen) Positioned.fill(child: _poisonTip()),
        ],
      ),
    );
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
    this.sub,
    this.ringColor,
    this.art,
    this.artFrame,
  });

  /// 묶음 35: 버튼 그림 (btn_○○). 있으면 아이콘 대신 둥근 그림
  final String? art;

  /// 묶음 35: 스킬 그림 (종류 테두리 안 70%). [art] 보다 먼저
  final Widget? artFrame;

  final String label;
  final IconData icon;
  final double ratio;
  final bool ready;
  final bool active;
  final VoidCallback onPressed;

  /// 이름 아래 작은 글 (직업 스킬 MP)
  final String? sub;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final lit = ready || active;
    return GestureDetector(
      onTap: ready ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
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
                    color: active
                        ? AppColors.mana
                        : ringColor ?? AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                if (artFrame != null)
                  // 충전 중·잠김은 어둡게 (게이지는 둘레 고리)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: ready
                          ? [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  blurRadius: 14),
                            ]
                          : null,
                    ),
                    child: artFrame,
                  )
                else if (art != null)
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: ready
                          ? [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  blurRadius: 14),
                            ]
                          : null,
                    ),
                    child: _dimmed(
                        !lit,
                        Image.asset('assets/images/$art.webp',
                            width: 46,
                            height: 46,
                            errorBuilder: (_, __, ___) => Icon(icon,
                                size: 24,
                                color: lit
                                    ? AppColors.goldBright
                                    : AppColors.textMuted))),
                  )
                else
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
            Text(keepAll(label),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: lit ? AppColors.goldBright : AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
            if (sub != null)
              Text(sub!,
                  maxLines: 1,
                  style: TextStyle(
                      color: ringColor ?? AppColors.textMuted,
                      fontSize: 10.5,
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
    this.height = 380,
    required this.foe,
    required this.cleared,
    required this.floorLabel,
    required this.dealt,
    required this.taken,
    required this.skill,
    required this.look,
    this.heroJob,
    required this.beat,
    required this.beatDuration,
    this.petDash = false,
    this.warning,
    this.guarded = false,
    this.guardButton = false,
    this.guard,
    this.guardBroken = false,
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
    this.season,
    this.background,
    this.weapon,
    this.allies = const [],
    this.resisted = false,
    this.elementHints = false,
  });

  /// 묶음 75 #324: 잘 안 들었는지 · 숫자 위 「효과 좋음 / 잘 안 들어요」를 보일지
  final bool resisted;
  final bool elementHints;

  /// 묶음 52: 각성자 뒤에 서는 3막 동료 (그림 · 색 · 쓰러짐)
  /// 묶음 73 #306: [swing] 이 바뀌면 공격 칸 그림을 한 번 (now: 스킬이라 바로), [dealt] 는 4칸에 뜨는 피해
  final List<({String? art, int color, bool down, int swing, int dealt, bool now})> allies;

  /// 장면 높이 (null 이면 주어진 자리만큼)
  final double? height;

  final WeaponKind? weapon;
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
  final Season? season;
  final String? background;

  /// 정령(펫) 스킬: 펫이 몬스터 쪽으로 달려든다
  final bool petDash;

  /// 강한 공격 예고 문구 (막기 시간)
  final String? warning;

  /// 예고에 이미 막기를 눌렀다
  final bool guarded;

  /// 묶음 76 #338: 아래에 「막기!」 버튼이 있음 (안내 글만 바뀜)
  final bool guardButton;

  /// 방금 막은 결과
  final GuardResult? guard;

  /// 묶음 65: 강한 공격을 막지 못함
  final bool guardBroken;

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
  final String? heroJob;

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
    // 묶음 73 #306: 동료 공격 (2→6칸 뒤 1칸). 보통 공격은 각성자가 친 뒤 차례로, 스킬은 바로
    for (var i = 0; i < widget.allies.length; i++) {
      final a = widget.allies[i];
      final before = i < old.allies.length ? old.allies[i].swing : 0;
      if (a.swing == before || AllyAttackSheet.sheetOf(a.art) == null) continue;
      final scale = allyScale;
      final delay = a.now
          ? 0
          : (widget.beatDuration.inMilliseconds * 0.45 + i * 120 * scale).round();
      final total = delay + (AllyAttackSheet.totalMs * scale).round();
      _allyDelay[i] = delay;
      final c = _allyC[i] ??= AnimationController(vsync: this);
      c.duration = Duration(milliseconds: total);
      c.forward(from: 0);
    }
  }

  /// 동료 공격 칸 컨트롤러 · 그 앞에 기다리는 시간(ms)
  final Map<int, AnimationController> _allyC = {};
  final Map<int, int> _allyDelay = {};

  /// 빠르게 보기면 같은 비율로 짧게 (1배 한 틱 765ms 기준)
  double get allyScale =>
      (widget.beatDuration.inMilliseconds / 765).clamp(0.35, 1.0);

  /// 동료 i 의 지금 칸 (0~5)과, 4칸(맞히는 순간)에서 흐른 비율 (그 칸이 아니면 null)
  (int, double?) _allyFrame(int i) {
    final c = _allyC[i];
    if (c == null || !c.isAnimating) return (0, null);
    final ms = c.value * c.duration!.inMilliseconds - (_allyDelay[i] ?? 0);
    return AllyAttackSheet.frameAt(ms / allyScale);
  }

  @override
  void dispose() {
    for (final c in _allyC.values) {
      c.dispose();
    }
    _boss.dispose();
    _c.dispose();
    super.dispose();
  }

  /// 동료 그림 한 칸: 이야기 동료는 공격 칸 그림(640×640), 이름 없는 동료는 통 그림
  Widget _allyArt(int i, ({String? art, int color, bool down, int swing, int dealt, bool now}) a,
      int frame, double s, double h) {
    Widget icon() => Icon(Icons.person_rounded, size: h * 0.3, color: Color(a.color));
    final sheet = AllyAttackSheet.sheetOf(a.art);
    if (sheet != null) {
      return SheetFrame(
          key: Key('allyFrame_${i}_$frame'),
          asset: sheet,
          frames: AllyAttackSheet.frames,
          frame: frame,
          fallback: a.art == null ? icon() : Image.asset(a.art!, fit: BoxFit.contain));
    }
    if (a.art == null) return Align(alignment: Alignment.bottomCenter, child: icon());
    // 통 그림(768×1024)은 몸이 칸의 약 95% → 공격 칸 그림(약 80%)과 같은 키로
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: s * 0.84,
        child: Image.asset(a.art!,
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => icon()),
      ),
    );
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
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: Listenable.merge([_c, ..._allyC.values]),
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

              // 묶음 73 #261: 통 그림 (공격은 여섯 칸)
              final heroPose = cleared
                  ? HeroPose.victory
                  : widget.defeated
                      ? HeroPose.tired
                      : swinging
                          ? HeroPose.attack
                          : HeroPose.idle;
              final attackT = swinging ? _seg(t, 0, 0.5) : 0.0;
              // 묶음 76 #307: 직업 그림 — 대기 = 1칸 + 숨쉬기, 공격 = 2→6칸 (4칸이 0.22 타격 순간)
              var jobFrame = 0;
              if (widget.heroJob != null && !idle && widget.dealt > 0 && !cleared && !widget.defeated) {
                final dur = _c.duration!.inMilliseconds;
                final start = 0.22 * dur -
                    (AllyAttackSheet.durations[0] + AllyAttackSheet.durations[1]) * allyScale;
                jobFrame = AllyAttackSheet.frameAt((t * dur - start) / allyScale).$1;
              }
              // 묶음 73 #260 다듬기: 혼자면 무대 높이의 약 절반(머리가 가운데보다 조금 아래),
              // 동료와 함께면 조금 작게. 그림 칸은 768×1024 (몸은 왼쪽 17%부터)
              final party = widget.allies.isNotEmpty;
              final heroH = h * (party ? 0.5 : 0.58);
              final heroW = math.min(w * 0.5, heroH * 0.75);
              // 뒷줄 동료: 640×640 칸, 주인공보다 왼쪽 · 조금 위, 서로 몸 반 넘게 떨어지게
              final allyS = h * 0.36;
              final allyBottom = h * 0.1;
              final allyLeft0 = -allyS * 0.12;
              final allyStep = allyS * 0.5;
              // 각성자 몸이 시작하는 자리: 혼자면 정령 말풍선 오른쪽, 함께면 뒷줄 동료 얼굴을 가리지 않게
              final bodyStart = party
                  ? allyLeft0 + allyStep * (widget.allies.length - 1) + allyS * 0.74
                  : 128.0;
              final heroLeft = math.max(w * 0.02, bodyStart - heroW * 0.17);
              // (아래 효과 자리들은 「front + w * …」로 각성자를 따라간다)
              final front = heroLeft - w * 0.02;
              // 동료 공격 칸 · 4칸(맞히는 순간)
              final allyFrames = [
                for (var i = 0; i < widget.allies.length; i++)
                  widget.allies[i].down ? (0, null) : _allyFrame(i)
              ];
              var allyShake = 0.0;
              for (final (f, p) in allyFrames) {
                if (f == 3 && p != null) allyShake += math.sin(p * math.pi * 6) * (1 - p) * 4;
              }
              final monSize = w * (party ? 0.34 : 0.38);
              final monLeft = w - monSize - w * 0.02 + shake + allyShake - counter * w * 0.07;
              final monTop = h * 0.24;
              final hitX = monLeft + monSize * 0.45;
              final hitY = monTop + monSize * 0.45;
              // 묶음 76 #315: 방패 자리 — 주인공 그림의 실제 머리 · 발 위치로 (768×1024 칸, 발 바닥 1004)
              final heroLeftNow = front + w * 0.02 + lunge * w * 0.08;
              final heroBottomNow = 8 + lunge * 6;
              final spriteH = heroW * 1024 / 768;
              // 서기 · 공격 그림 모두 몸은 칸 가운데, 키는 칸 높이의 약 68% (640×800 칸이 768×1024 칸 바닥에)
              final feetY = heroBottomNow + spriteH * 22 / 1024; // 무대 아래에서 발까지
              final bodyH = spriteH * 0.68; // 발 → 머리 끝
              final shieldD = bodyH * 0.55;
              final shieldCx = heroLeftNow + heroW * 0.72; // 몸 앞쪽 (몬스터 쪽)
              final shieldCy = feetY + bodyH * 0.62; // 가슴 높이 (아래에서)
              final heroHeadY = feetY + bodyH; // 머리 끝 (아래에서)
              Widget shieldAt(Key key, Widget child, {double scale = 1}) => Positioned(
                    key: key,
                    left: shieldCx - shieldD * scale / 2,
                    bottom: shieldCy - shieldD * scale / 2,
                    width: shieldD * scale,
                    height: shieldD * scale,
                    child: IgnorePointer(child: child),
                  );

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
                      child: Image.asset(
                          widget.background ?? 'assets/images/bg_battle.webp',
                          fit: BoxFit.cover,
                          // 그림이 아직 없으면 비슷한 배경 → 기본 배경 → 색
                          errorBuilder: (_, __, ___) => Image.asset(
                              backgroundFallback(widget.background),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFF1B1840)))),
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
                    // 공격이 오갈 때마다 조금씩 흐른다 (끝없이 도는 애니메이션은 쓰지 않는다)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          key: const Key('battleAmbient'),
                          foregroundPainter: widget.season == null
                              ? null
                              : SeasonPainter(
                                  season: widget.season!,
                                  t: ((widget.beat + t) * 0.06) % 1.0,
                                  few: MediaQuery.maybeDisableAnimationsOf(
                                          context) ??
                                      false),
                          painter: _AmbientPainter(
                            t: ((widget.beat + t) * 0.11) % 1.0,
                            element: foe.info.element,
                            hour: widget.hour,
                          ),
                        ),
                      ),
                    ),
                    // 발밑 그림자
                    Positioned(
                      left: front + w * 0.06 + lunge * w * 0.08,
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
                          key: ValueKey('${foe.monster.name}_${foe.reveal}_$cleared'),
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
                                        reveal: foe.reveal,
                                      ),
                                    ),
                                  )
                                : cleared
                                    // 묶음 18 #149: 정화된 몬스터는 또렷하게
                                    ? PurifiedMonster(
                                        monster: foe.monster,
                                        size: monSize * 0.66)
                                    : _tinted(
                                        widget.foeTint,
                                        MonsterPicture(
                                          monster: foe.monster,
                                          size: monSize,
                                          reveal: foe.reveal,
                                          crystal: foe.monster ==
                                                  MonsterId.dummyElement
                                              ? elementColor(foe.element)
                                              : null,
                                          tint: foe.tint,
                                        )),
                          ),
                        ),
                      ),
                    ),
                    // 보스 장비 6개 세트: 각성자 둘레 세트 빛 (11-11 #82)
                    if (widget.aura != null)
                      Positioned(
                        key: const Key('battleAura'),
                        left: front + w * 0.02 + lunge * w * 0.08 - heroW * 0.1,
                        bottom: 10,
                        width: heroW * 1.2,
                        height: h * 0.62,
                        child: IgnorePointer(
                          child: Stack(fit: StackFit.expand, children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(colors: [
                                  widget.aura!.withValues(
                                      alpha: 0.45 + 0.15 * math.sin(t * math.pi)),
                                  widget.aura!.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                            // 묶음 19 6-3: 세트마다 다른 무늬·반짝임
                            if (SetAuraPattern.ofAura(widget.aura)
                                case final set?)
                              SetAuraPattern(set: set),
                          ]),
                        ),
                      ),
                    // 묶음 52 #243 · 묶음 73 #260/#306: 뒷줄 동료 (이야기 동료는 오른쪽을 본 1칸 + 숨쉬기, 공격하면 2→6칸)
                    for (var i = widget.allies.length - 1; i >= 0; i--)
                      Positioned(
                        key: Key('sceneAlly_$i'),
                        left: allyLeft0 + i * allyStep,
                        bottom: allyBottom,
                        width: allyS,
                        height: allyS,
                        child: Opacity(
                          opacity: widget.allies[i].down ? 0.35 : 0.97,
                          child: Transform.scale(
                            alignment: Alignment.bottomCenter,
                            scaleY: allyFrames[i].$1 != 0 || widget.allies[i].down
                                ? 1
                                : 1 + math.sin((t + i * 0.37) * math.pi * 2) * 0.015,
                            child: _allyArt(i, widget.allies[i], allyFrames[i].$1, allyS, h),
                          ),
                        ),
                      ),
                    // 각성자 (달려들고, 맞으면 붉게 번쩍)
                    Positioned(
                      key: const Key('sceneHero'),
                      left: front + w * 0.02 + lunge * w * 0.08,
                      bottom: 8 + lunge * 6,
                      width: heroW,
                      height: heroH,
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
                              scaleY: swinging || cleared || jobFrame > 0
                                  ? 1
                                  : 1 + math.sin(t * math.pi * 2) * 0.015,
                              alignment: Alignment.bottomCenter,
                              child: _tinted(
                                  widget.heroTint,
                                  HeroSprite(
                                      look: widget.look,
                                      pose: widget.heroJob == null ||
                                              heroPose == HeroPose.victory ||
                                              heroPose == HeroPose.tired
                                          ? heroPose
                                          : jobFrame > 0
                                              ? HeroPose.attack
                                              : HeroPose.idle,
                                      t: attackT,
                                      job: widget.heroJob,
                                      frame: jobFrame)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 묶음 57: 활로 쏘면 화살이 날아감
                    // 묶음 76 #307: 궁수 그림은 4칸에 화살이 이미 있어 코드 화살은 뺀다
                    if (widget.weapon == WeaponKind.bow && swinging && !cleared &&
                        widget.heroJob != JobId.archer.name)
                      Positioned(
                        left: front + w * 0.12 + (hitX - front - w * 0.12) * _seg(t, 0.05, 0.3) - 64,
                        top: hitY - 16,
                        width: 128,
                        height: 32,
                        child: IgnorePointer(
                          child: Opacity(
                            key: const Key('fxArrow'),
                            opacity: 1 - _seg(t, 0.3, 0.38),
                            child: Image.asset('assets/images/fx_arrow.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox()),
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
                          child: Image.asset('assets/images/fx_purify.webp',
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
                              child: Image.asset('assets/images/fx_slash.webp',
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
                            // 속성 타격 그림이 있으면 그것, 없으면 기본 타격에 속성 색
                            child: widget.hitElement == null
                                ? Image.asset('assets/images/fx_hit.webp',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox())
                                : Image.asset(
                                    'assets/images/fx_hit_${widget.hitElement!.name}.webp',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _tinted(
                                        elementColor(widget.hitElement),
                                        Image.asset('assets/images/fx_hit.webp',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox()),
                                        alpha: 0.55)),
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
                          opacity: cleared
                              ? (widget.guard != null && !idle ? _seg(t, 0.42, 0.55) : 1)
                              : 1 - _seg(t, 0.6, 0.9),
                          child: Center(
                            child: Transform.scale(
                              scale: cleared
                                  ? 1
                                  : 0.7 +
                                      Curves.elasticOut
                                              .transform(_seg(t, 0.22, 0.45)) *
                                          0.4,
                              // 피해 숫자 (11-11 #81): 보통 흰색, 치명타 크고 노랑, 약점 빨강
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                // 묶음 75 #324: 속성 허수아비 — 숫자 위 작은 글 (배율은 숨김)
                                if (widget.elementHints && !cleared && (widget.superHit || widget.resisted))
                                  Text(widget.superHit ? '효과 좋음' : '잘 안 들어요',
                                      key: Key(widget.superHit ? 'hintGood' : 'hintBad'),
                                      style: TextStyle(
                                          color: widget.superHit ? AppColors.goldBright : const Color(0xFFB8B8C8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          shadows: const [Shadow(blurRadius: 3)])),
                                _Outlined(
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
                              ]),
                            ),
                          ),
                        ),
                      ),
                    // 받은 피해: 각성자 머리 위
                    if (hurt > 0)
                      Positioned(
                        left: front + w * 0.08,
                        width: heroW * 0.6,
                        bottom: 8 + heroH * 0.85 + _seg(t, 0.6, 0.95) * 30,
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
                    // 방어 태세: 주인공 앞 원형 방패 (fx_guard, 은은히 숨쉬기) — 묶음 76 #315
                    if (widget.stance && !cleared && !(widget.guarded && widget.warning != null && widget.guard == null))
                      shieldAt(
                          const Key('fxStance'),
                          Opacity(
                            opacity: 0.7 + 0.15 * math.sin(t * math.pi * 2).abs(),
                            child: Image.asset('assets/images/fx_guard.webp',
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                          scale: 1 + 0.03 * math.sin(t * math.pi * 2)),
                    // 묶음 65 #256: 막기 준비 (캐릭터 앞 방어막, 은은히 숨 쉬듯)
                    if (widget.guarded && widget.warning != null && widget.guard == null)
                      shieldAt(
                          const Key('fxGuard'),
                          Opacity(
                            opacity: 0.75 + 0.25 * math.sin(t * math.pi * 2).abs(),
                            child: Image.asset('assets/images/fx_guard.webp',
                                errorBuilder: (_, __, ___) => DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.mana.withValues(alpha: 0.7), width: 3),
                                      ),
                                    )),
                          )),
                    // 막기 결과: 막은 순간 방어막이 번쩍 + 「막았다!」(안내 글은 그 뒤에)
                    // 묶음 76 #315: 그 공격으로 몬스터가 쓰러지면 번쩍임은 0.4초 안에 끝내고 승리 자세로,
                    // 글은 「완벽한 막기!」(주인공 위) → 「사냥!」(무대 가운데 위) 차례로
                    if (widget.guard != null && !idle) ...[
                      shieldAt(
                          const Key('fxGuardHit'),
                          Opacity(
                            opacity: cleared ? 1 - _seg(t, 0.15, 0.45) : 1 - _seg(t, 0.55, 0.95),
                            child: Transform.scale(
                              scale: 0.95 + 0.15 * _seg(t, 0.0, 0.2),
                              child: Image.asset('assets/images/fx_guardHit.webp',
                                  errorBuilder: (_, __, ___) => Icon(Icons.shield_rounded,
                                      size: 56,
                                      color: widget.guard == GuardResult.perfect ? AppColors.goldBright : AppColors.mana)),
                            ),
                          ),
                          scale: 1.15),
                      Positioned(
                        key: const Key('guardText'),
                        left: heroLeftNow,
                        width: heroW,
                        // 승리 자세(통 그림)는 키가 더 커서 그 머리 위로
                        bottom: (cleared ? feetY + spriteH * 0.86 : heroHeadY) + 6 + _seg(t, 0.1, 0.6) * 16,
                        child: Opacity(
                          opacity: cleared ? 1 - _seg(t, 0.3, 0.45) : 1 - _seg(t, 0.75, 0.98),
                          child: Center(
                            child: _Outlined(
                                widget.guard == GuardResult.perfect ? '완벽한 막기!' : '막았다!',
                                size: 22,
                                color: widget.guard == GuardResult.perfect ? AppColors.goldBright : Colors.white),
                          ),
                        ),
                      ),
                    ],
                    // 막지 못함: 방어막이 깨짐
                    if (widget.guardBroken && widget.guard == null && !idle)
                      shieldAt(
                          const Key('fxGuardBreak'),
                          Opacity(
                            opacity: 1 - _seg(t, 0.55, 0.95),
                            child: Image.asset('assets/images/fx_guardBreak.webp', errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                          scale: 1.15),
                    // 강한 공격 예고: 화면을 누르면 막기
                    if (widget.warning != null)
                      Positioned(
                        key: const Key('guardWarning'),
                        left: 0,
                        right: 0,
                        // 묶음 65: 위 「BOSS」 · 층 표 아래로 (겹치지 않게)
                        top: math.max(monTop - 46, 50.0),
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
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const GameGlyph(Glyph.warn, size: 16),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(widget.warning!,
                                          style: AppText.title(16,
                                              color: Colors.white)),
                                    ),
                                  ]),
                            ),
                          ]),
                        ),
                      ),
                    // 묶음 76 #338: 무대 아래쪽 가운데 작게 (머리 · 몬스터 · 경고 띠와 안 겹치게)
                    if (widget.warning != null && !(widget.guard != null && !idle))
                      Positioned(
                        key: const Key('guardHint'),
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xB30B0D26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                  widget.guarded
                                      ? '막기 준비!'
                                      : widget.guardButton
                                          ? '아래 「막기!」를 눌러요'
                                          : '화면을 눌러 막기!',
                                  style: TextStyle(
                                      color: widget.guarded ? AppColors.mana : AppColors.goldBright,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    // 회복: 초록 숫자
                    if (widget.healed > 0)
                      Positioned(
                        left: front + w * 0.06,
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
                          // 묶음 76 #315: 보상 아이콘은 무대 안쪽에 (오른쪽 끝에서 잘리지 않게)
                          left: (monLeft +
                                  monSize / 2 -
                                  14 +
                                  (i - 1) * 30 * _seg(t, 0, 0.5) +
                                  _seg(t, 0.5, 1) * w * 0.25)
                              .clamp(4.0, w - 36),
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
                                      style: AppText.title(22,
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
                              style: AppText.title(16,
                                  color: foe.isBoss
                                      ? AppColors.gauge
                                      : AppColors.goldBright)),
                        ),
                      ),
                    ),
                    // 묶음 73 #306: 동료 피해 숫자 (4칸, 맞히는 순간)
                    for (var i = 0; i < widget.allies.length; i++)
                      if (allyFrames[i].$2 case final p? when widget.allies[i].dealt > 0)
                        Positioned(
                          key: Key('allyDealt_$i'),
                          left: monLeft + monSize * (0.05 + i * 0.22),
                          top: monTop - 8 - p * 26,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (1 - p * 0.7).clamp(0.0, 1.0),
                              child: _Outlined('-${comma(widget.allies[i].dealt)}',
                                  size: 20, color: const Color(0xFFE8F0FF)),
                            ),
                          ),
                        ),
                    // 정령의 응원 (묶음 73 #260: 무대 왼쪽 아래 구석, 말풍선은 정령 오른쪽 위 — 누구 발도 덮지 않게)
                    // 펫이면 주인공 발 앞쪽 아래에 서고, 말풍선만 구석에
                    Builder(builder: (context) {
                      final pet = BulssiScope.maybeOf(context)?.petSpecies != null;
                      final petS = h * 0.17;
                      final dash = widget.petDash && !idle
                          ? math.sin(_seg(t, 0, 0.5) * math.pi) * w * 0.3
                          : 0.0;
                      return Positioned(
                        left: pet ? heroLeft + heroW * 0.55 + dash : 4 + dash,
                        bottom: pet ? 0 : 4,
                        child: Transform.translate(
                          offset: Offset(0, -math.sin(t * math.pi) * 6),
                          child: BattleCompanion(
                              key: const Key('battleCompanion'), size: pet ? petS : 44),
                        ),
                      );
                    }),
                    Builder(builder: (context) {
                      final pet = BulssiScope.maybeOf(context)?.petSpecies != null;
                      return Positioned(
                        key: const Key('companionLine'),
                        left: pet ? 6 : 40,
                        bottom: pet ? 6 : 38,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: math.max(80, heroLeft + heroW * 0.17 - (pet ? 14 : 46))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF5E6),
                              borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 11.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      );
                    }),
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
  const _Avatar({required this.look});

  final HeroLook look;
  double get size => 46;

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
        child: PortraitFace(
            look: look,
            fallback: const Icon(Icons.person_rounded, color: AppColors.textMuted)),
      ),
    );
  }
}

/// 묶음 75 #324: 연습 허수아비 — 가득 찬 금빛 줄 「끝없는 허수아비 ∞」 (맞을 때 살짝 번쩍)
class _EndlessDummy extends StatelessWidget {
  const _EndlessDummy({required this.beat, this.element});

  final int beat;
  final Element? element;

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('endlessDummy'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (element != null) ...[
              ElementIcon(element, size: 16),
              const SizedBox(width: 4),
            ],
            const Flexible(
              child: Text('끝없는 허수아비 ∞',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            key: ValueKey(beat),
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 380),
            builder: (context, v, _) => ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: v * 0.55), BlendMode.srcATop),
              child: GlowBar(ratio: 1, colors: BarColors.exp, height: 11),
            ),
          ),
        ],
      );
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
    this.hideNumbers = false,
  });

  final bool hideNumbers;

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
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(note!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        GlowBar(
            ratio: maxHp == 0 ? 0 : hp / maxHp, colors: colors, height: 11),
        if (!hideNumbers) ...[
          const SizedBox(height: 3),
          // 묶음 76 #338: 큰 숫자도 한 줄에 (넘치면 글자를 줄임)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('HP ${comma(hp)} / ${comma(maxHp)}',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

/// 묶음 76 #338: 강한 공격 예고 동안 「방어 태세」 자리의 「막기!」 버튼.
/// 1.15배 · 금빛으로 숨쉬고, 둘레 고리가 예고 시간만큼 차오른다 (끝 완벽한 막기 구간은 금색).
/// 판정은 전투 화면 전체 Listener([_BattleViewState._onPointer])가 한다 — 이 버튼은 누르는 자리일 뿐
class _GuardButton extends StatefulWidget {
  const _GuardButton(
      {super.key, required this.clock, required this.window, required this.perfect, this.done = false});

  final Stopwatch clock;
  final Duration window;

  /// 끝에서 이만큼이 완벽한 막기
  final Duration perfect;

  /// 이미 눌렀음
  final bool done;

  @override
  State<_GuardButton> createState() => _GuardButtonState();
}

class _GuardButtonState extends State<_GuardButton> with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '막기',
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final w = widget.window.inMilliseconds;
            final p = w <= 0 ? 1.0 : (widget.clock.elapsedMilliseconds / w).clamp(0.0, 1.0);
            final perfectFrom = w <= 0 ? 1.0 : 1 - widget.perfect.inMilliseconds / w;
            final glow = widget.done ? 0.3 : 0.45 + 0.4 * _t.value;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.scale(
                scale: 1.15,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: _GuardRingPainter(progress: p, perfectFrom: perfectFrom),
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.goldBright.withValues(alpha: glow), blurRadius: 16, spreadRadius: 1),
                          ],
                        ),
                        child: Image.asset('assets/images/btn_guard.webp',
                            width: 46,
                            height: 46,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.shield_rounded, size: 26, color: AppColors.goldBright)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.done ? '막는 중' : '막기!',
                  style: const TextStyle(
                      color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ]);
          },
        ),
      );
}

class _GuardRingPainter extends CustomPainter {
  _GuardRingPainter({required this.progress, required this.perfectFrom});

  final double progress;
  final double perfectFrom;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    const start = -math.pi / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x55FFFFFF);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    // 완벽한 막기 구간 (옅은 금색)
    canvas.drawArc(r, start + perfectFrom * math.pi * 2, (1 - perfectFrom) * math.pi * 2, false,
        track..color = AppColors.gold.withValues(alpha: 0.45));
    // 지금까지 찬 만큼 (완벽 구간에 들어가면 금색)
    canvas.drawArc(
        r,
        start,
        progress * math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = progress >= perfectFrom ? AppColors.goldBright : Colors.white);
  }

  @override
  bool shouldRepaint(_GuardRingPainter old) => old.progress != progress || old.perfectFrom != perfectFrom;
}

/// 둥근 스킬 버튼: 바깥 고리가 충전 정도
class _SkillOrb extends StatelessWidget {
  const _SkillOrb({
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.away = false,
    this.size = 104,
    this.compact = false,
  });

  final double size;

  /// 버튼 줄 안 (이름이 잘리지 않게 작은 글씨)
  final bool compact;
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
                  // 묶음 35: 펫 버튼 그림 (충전 중엔 어둡게)
                  child: ClipOval(
                    child: _dimmed(
                        !ready,
                        Image.asset('assets/images/btn_pet.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.flare_rounded,
                                size: size * 0.44,
                                color: ready
                                    ? const Color(0xFF5A3410)
                                    : AppColors.textMuted))),
                  ),
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
              maxLines: compact ? 2 : 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? TextStyle(
                      color: ready ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)
                  : AppText.title(14,
                      color: ready ? AppColors.goldBright : AppColors.textMuted)),
        ),
      ],
    );
  }
}

/// 배경 그림이 없을 때 대신 쓸 그림 (바다 → 물가, 나머지 → 기본)
String backgroundFallback(String? bg) => switch (bg) {
      'assets/images/bg_field_sea.webp' => 'assets/images/bg_field_water.webp',
      _ => 'assets/images/bg_battle.webp',
    };

/// tired: HP 0으로 싸울 수 없을 때 (11-10)
enum HeroPose { idle, attack, victory, tired }

/// 묶음 73 #306: 이야기 동료 공격 그림 (640×640 × 6칸, 발 바닥 약 620)
/// 1 준비 → 2 힘 모으기 → 3 휘두르기 시작 → 4 맞히는 순간 → 5 마무리 → 6 다시 준비(→ 1)
class AllyAttackSheet {
  AllyAttackSheet._();

  static const frames = 6;

  /// 이야기 동료 (이름 없는 동료 ally_job_* 는 통 그림)
  static const story = {'lian', 'garen', 'nia', 'barkan', 'popo', 'sera', 'teo'};

  /// 2~6칸 시간 (ms). 1칸은 기다리는 동안
  static const durations = [100, 80, 160, 100, 120];
  static int get totalMs => durations.fold(0, (a, b) => a + b);

  /// 통 그림 경로 → 공격 칸 그림 (없으면 null)
  static String? sheetOf(String? art) {
    if (art == null) return null;
    final m = RegExp(r'ally_([a-z]+)\.webp$').firstMatch(art);
    if (m == null || !story.contains(m.group(1))) return null;
    return 'assets/images/ally_${m.group(1)}_attack.webp';
  }

  /// 공격 시작부터 [ms] 뒤의 칸 (0~5)과, 4칸부터 흐른 비율 (0~1, 그 전이면 null)
  static (int, double?) frameAt(double ms) {
    if (ms < 0 || ms >= totalMs) return (0, null);
    var at = 0;
    for (var k = 0; k < durations.length; k++) {
      if (ms < at + durations[k]) {
        final hitAt = durations[0] + durations[1]; // 4칸이 시작하는 때
        return (k + 1, ms >= hitAt ? (ms - hitAt) / (totalMs - hitAt) : null);
      }
      at += durations[k];
    }
    return (0, null);
  }
}

/// 가로로 이어 붙인 정사각 칸 그림에서 한 칸만 (칸 바닥에 맞춰)
class SheetFrame extends StatelessWidget {
  const SheetFrame(
      {super.key, required this.asset, required this.frames, required this.frame, this.fallback});

  final String asset;
  final int frames;
  final int frame;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: s,
            height: s,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: s * frames,
                maxWidth: s * frames,
                child: Transform.translate(
                  offset: Offset(-frame * s, 0),
                  child: Image.asset(asset,
                      width: s * frames,
                      height: s,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => SizedBox(
                          width: s * frames,
                          height: s,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(width: s, height: s, child: fallback)))),
                ),
              ),
            ),
          ),
        );
      });
}

/// 각성자 그림 (묶음 73 #261: 맨손 새 주인공).
/// 서기·승리·지침은 768×1024 한 장, 공격은 640×800 여섯 칸을 [t](0~1)에 따라 넘긴다.
/// 두 그림 모두 발끝이 아래에서 20px 위라서, 768×1024 칸 바닥에 맞춰 그린다.
class HeroSprite extends StatelessWidget {
  const HeroSprite(
      {super.key, required this.look, required this.pose, this.t = 0, this.job, this.frame});

  final HeroLook look;
  final HeroPose pose;

  /// 묶음 76 #307: 직업 그림 ('warrior' …). 서기 · 공격은 hero_<job>_attack 여섯 칸
  /// (대기 = 1칸), 승리 · 지침은 그대로
  final String? job;

  /// 직업 그림 공격 칸 (0~5). 없으면 [t] 로 정한다
  final int? frame;

  /// 공격 동작 진행 (0~1). 공격이 아니면 쓰지 않는다
  final double t;

  static const attackFrames = 6;

  /// 공격 [t] 에서 보여 줄 칸 (0~5)
  static int frameAt(double t) =>
      (t.clamp(0.0, 1.0) * attackFrames).floor().clamp(0, attackFrames - 1);

  bool get _jobSheet => job != null && (pose == HeroPose.attack || pose == HeroPose.idle);

  String get _asset => _jobSheet
      ? 'assets/images/hero_${job}_attack_${look.name}.webp'
      : 'assets/images/hero_${pose.name}_${look.name}.webp';

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object __, StackTrace? ___) =>
        const Icon(Icons.person_rounded, size: 140, color: AppColors.textMuted);
    if (!_jobSheet && pose != HeroPose.attack) {
      return Image.asset(_asset,
          fit: BoxFit.contain, semanticLabel: '각성자', errorBuilder: fallback);
    }
    final frame = _jobSheet
        ? (pose == HeroPose.idle ? 0 : (this.frame ?? frameAt(t)))
        : frameAt(t);
    return AspectRatio(
      aspectRatio: 768 / 1024,
      child: LayoutBuilder(builder: (context, box) {
        final fw = box.maxWidth * 640 / 768;
        final fh = box.maxHeight * 800 / 1024;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: Key('heroFrame_$frame'),
            width: fw,
            height: fh,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: fw * attackFrames,
                maxWidth: fw * attackFrames,
                child: Transform.translate(
                  offset: Offset(-frame * fw, 0),
                  child: Image.asset(_asset,
                      width: fw * attackFrames,
                      height: fh,
                      fit: BoxFit.fill,
                      semanticLabel: '각성자',
                      errorBuilder: fallback),
                ),
              ),
            ),
          ),
        );
      }),
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
    this.reveal,
    this.crystal,
    this.tint,
  });

  final MonsterId monster;
  final double size;

  /// 묶음 50 석상 병사: 섬 속성 색을 살짝 입힌다 (ARGB)
  final int? tint;

  /// 묶음 43 속성 허수아비: 가슴 수정에 그 속성 색
  final Color? crystal;

  /// 묶음 34 잿빛 군주: 안개 판 위에 얼굴 판을 겹친다 (0 안개 ~ 1 얼굴)
  final double? reveal;

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
        MonsterId.ashSlime || MonsterId.slime => Icons.water_drop_rounded,
        MonsterId.ashRage => Icons.local_fire_department_rounded,
        MonsterId.ashSorrow => Icons.water_rounded,
        MonsterId.ashGreed => Icons.diamond_rounded,
        MonsterId.ashFear => Icons.dark_mode_rounded,
        MonsterId.ashLonely => Icons.air_rounded,
        MonsterId.ashKing => Icons.cloud_rounded,
        MonsterId.dummy ||
        MonsterId.dummyHard ||
        MonsterId.dummyElement =>
          Icons.sports_martial_arts_rounded,
        MonsterId.trainingGolem => Icons.smart_toy_rounded,
        MonsterId.guardWind => Icons.air_rounded,
        MonsterId.guardThunder => Icons.bolt_rounded,
        MonsterId.guardLight => Icons.wb_sunny_rounded,
        MonsterId.guardIce => Icons.ac_unit_rounded,
        MonsterId.guardWater => Icons.waves_rounded,
        MonsterId.stoneSoldier => Icons.shield_rounded,
        // 묶음 69 #281: Lv.50 지도 몬스터 (그림이 오기 전 아이콘)
        MonsterId.doppelganger || MonsterId.dullahan || MonsterId.deathKnight => Icons.nights_stay_rounded,
        MonsterId.arachne || MonsterId.basilisk => Icons.bug_report_rounded,
        MonsterId.sphinx => Icons.help_rounded,
        MonsterId.clockworkKnight => Icons.settings_rounded,
        MonsterId.centaur || MonsterId.owlbear => Icons.forest_rounded,
        MonsterId.kelpie || MonsterId.naga => Icons.waves_rounded,
        MonsterId.roc => Icons.flight_rounded,
        MonsterId.werewolf => Icons.pets_rounded,
        MonsterId.goblinRaider => Icons.hardware_rounded,
        MonsterId.skeletonGuard => Icons.shield_moon_rounded,
        MonsterId.harpy => Icons.air_rounded,
        MonsterId.ogre => Icons.landscape_rounded,
        MonsterId.ashHounds => Icons.pets_rounded,
        MonsterId.ashArmor => Icons.security_rounded,
        MonsterId.ashWolfAlpha => Icons.nights_stay_rounded,
        MonsterId.partyGolem => Icons.terrain_rounded,
        MonsterId.partyHydra => Icons.waves_rounded,
        MonsterId.partyWyvern => Icons.flight_rounded,
        MonsterId.partyKraken => Icons.water_rounded,
        // 묶음 57: 지역 2~5 (그림이 있어 아이콘은 거의 안 씀)
        MonsterId.orcMerc ||
        MonsterId.koboldMiner ||
        MonsterId.gargoyle ||
        MonsterId.livingArmor ||
        MonsterId.orcCaptain ||
        MonsterId.ashCart ||
        MonsterId.metalColossus =>
          Icons.hardware_rounded,
        MonsterId.treant ||
        MonsterId.giantSpider ||
        MonsterId.dryad ||
        MonsterId.woodWolf ||
        MonsterId.spiderQueen ||
        MonsterId.ashElder ||
        MonsterId.ashTortoise =>
          Icons.forest_rounded,
        MonsterId.vampireBat ||
        MonsterId.wraith ||
        MonsterId.ghoul ||
        MonsterId.cultZealot ||
        MonsterId.cultPriests ||
        MonsterId.ashCaptain ||
        MonsterId.ashBeasts =>
          Icons.nights_stay_rounded,
        MonsterId.salamander ||
        MonsterId.ifrit ||
        MonsterId.koboldrake ||
        MonsterId.cultFlamePriest ||
        MonsterId.youngRedDragon ||
        MonsterId.orben ||
        MonsterId.orbenAsh ||
        MonsterId.phoenixMother ||
        MonsterId.raidDragon =>
          Icons.local_fire_department_rounded,
        MonsterId.raidGiant => Icons.wb_sunny_rounded,
        MonsterId.raidLich => Icons.dangerous_rounded,
        MonsterId.raidTortoise => Icons.landscape_rounded,
        MonsterId.wildGriffin || MonsterId.wildKnightCaptain => Icons.flare_rounded,
        MonsterId.wildTroll || MonsterId.wildRuneGolem => Icons.hardware_rounded,
        MonsterId.wildBoar || MonsterId.wildElfArcher => Icons.forest_rounded,
        MonsterId.wildLizardman || MonsterId.wildBanshee => Icons.nights_stay_rounded,
        MonsterId.wildLavaGolem || MonsterId.wildDragonCaptain => Icons.local_fire_department_rounded,
        MonsterId.garrisonClone ||
        MonsterId.blackGuard ||
        MonsterId.blackCaptain ||
        MonsterId.cloneWarrior ||
        MonsterId.cloneKnight ||
        MonsterId.cloneArcher ||
        MonsterId.cloneMage ||
        MonsterId.clonePriest ||
        MonsterId.cloneRogue =>
          Icons.shield_rounded,
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
    final r = reveal;
    if (r != null && !defeated) {
      final k = r.clamp(0.0, 1.0);
      return SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          Opacity(
            opacity: 1 - 0.7 * k,
            child: Image.asset(info.asset,
                width: size,
                height: size,
                semanticLabel: info.name,
                errorBuilder: (_, __, ___) => Icon(iconOf(monster),
                    size: size * 0.7, color: const Color(0xFFB8B2C8))),
          ),
          Opacity(
            key: const Key('ashKingFace'),
            opacity: 0.12 + 0.88 * k,
            child: Image.asset(
                'assets/images/monster_${monster.name}_face.webp',
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ]),
      );
    }
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
    if (!defeated && tint != null) {
      return ColorFiltered(
        key: const Key('monsterTint'),
        colorFilter: ColorFilter.mode(
            Color(tint!).withValues(alpha: 0.38), BlendMode.srcATop),
        child: picture,
      );
    }
    if (!defeated && crystal != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          picture,
          // 묶음 75 #323: 실제 가슴 수정 자리 (가운데 0.453, 0.551 · 지름 0.17)
          Positioned(
            key: const Key('dummyCrystal'),
            left: size * 0.368,
            top: size * 0.466,
            width: size * 0.17,
            height: size * 0.17,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.9),
                    crystal!.withValues(alpha: 0.85),
                    crystal!.withValues(alpha: 0),
                  ], stops: const [0, 0.45, 1]),
                ),
              ),
            ),
          ),
        ]),
      );
    }
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

/// 사냥 결과의 몬스터 (묶음 18 #149): 흐리지 않고 원래 색 그대로, 뒤로 따뜻한
/// 정화 빛이 번지고 천천히 숨 쉬듯 움직인다 (편안해진 느낌). 모든 몬스터에 쓴다.
class PurifiedMonster extends StatefulWidget {
  const PurifiedMonster({super.key, required this.monster, this.size = 140});

  final MonsterId monster;
  final double size;

  @override
  State<PurifiedMonster> createState() => _PurifiedMonsterState();
}

class _PurifiedMonsterState extends State<PurifiedMonster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true, count: 4);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final s = widget.size;
    return SizedBox(
      key: const Key('purifiedMonster'),
      width: s * 1.5,
      height: s * 1.25,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = still ? 0.5 : Curves.easeInOut.transform(_a.value);
          return Stack(alignment: Alignment.center, children: [
            // 따뜻한 정화 빛
            Container(
              width: s * (1.35 + 0.08 * t),
              height: s * (1.35 + 0.08 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFFF4D2).withValues(alpha: 0.75),
                  const Color(0xFFFFC96B).withValues(alpha: 0.35),
                  const Color(0x00FFC96B),
                ], stops: const [0, 0.5, 1]),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -3 * t),
              child: Transform.scale(
                scale: 1 + 0.025 * t,
                child: MonsterPicture(monster: widget.monster, size: s),
              ),
            ),
          ]);
        },
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

  String get asset => 'assets/images/status_$name.webp';
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

/// 배경 위 시간 색감·속성 입자·밤 반딧불 (11-11 #81, 그림 없이 코드로)
class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, this.element, this.hour});

  final double t;
  final Element? element;
  final int? hour;

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
    // 밤에는 반딧불 (기기 시간, 날씨는 쓰지 않는다)
    if (hr != null && (hr >= 19 || hr < 6)) {
      for (var i = 0; i < 14; i++) {
        final x0 = rng.nextDouble() * w;
        final y0 = h * (0.25 + rng.nextDouble() * 0.6);
        final ph = rng.nextDouble();
        final v = (t * (0.4 + rng.nextDouble() * 0.4) + ph) % 1.0;
        final a = (math.sin(v * math.pi * 2) * 0.5 + 0.5) * 0.85;
        final o = Offset(x0 + math.sin(v * 6.28 + i) * 10,
            y0 + math.cos(v * 6.28 + i * 0.7) * 8);
        canvas.drawCircle(
            o, 5, p..color = Color.fromRGBO(220, 255, 140, a * 0.25));
        canvas.drawCircle(
            o, 1.8, p..color = Color.fromRGBO(240, 255, 170, a));
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
      old.hour != hour;
}


/// 충전 중·잠긴 버튼 그림은 어둡게 (묶음 35)
Widget _dimmed(bool dim, Widget child) => dim
    ? ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.25, 0.25, 0.25, 0, 0, //
          0.25, 0.25, 0.25, 0, 0, //
          0.30, 0.30, 0.30, 0, 0, //
          0, 0, 0, 0.85, 0,
        ]),
        child: child)
    : child;


/// 묶음 52 #243: 전투 화면 동료 칸 — 얼굴 · 이름 · HP 막대 · 끼운 스킬 버튼(게이지가 차면 누름)
class _AllyCard extends StatelessWidget {
  const _AllyCard({super.key, required this.ally, this.look, this.onSkill});

  final BattleAlly ally;
  final ({String? art, String? face, int color})? look;
  final VoidCallback? onSkill;

  @override
  Widget build(BuildContext context) {
    final a = ally;
    final color = Color(look?.color ?? 0xFF9AA6D8);
    final face = look?.face;
    return Opacity(
      opacity: a.down ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14163A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          ClipOval(
            child: Container(
              width: 30,
              height: 30,
              color: color.withValues(alpha: 0.35),
              child: face == null
                  ? Icon(Icons.person_rounded, size: 22, color: color)
                  : Image.asset(face,
                      fit: BoxFit.cover,
                      alignment: face.contains('ally_job_')
                          ? const Alignment(0, -0.8)
                          : Alignment.center,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.person_rounded, size: 22, color: color)),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                GlowBar(
                    key: Key('allyHp_${a.id}'),
                    ratio: a.maxHp == 0 ? 0 : a.hp / a.maxHp,
                    colors: BarColors.hp,
                    height: 7),
              ],
            ),
          ),
          if (a.skill case final s?) ...[
            const SizedBox(width: 5),
            GestureDetector(
              key: Key('allySkill_${a.id}'),
              onTap: a.ready ? onSkill : null,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: a.ratio,
                    strokeWidth: 3,
                    color: a.ready ? AppColors.goldBright : color,
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                  Icon(Icons.auto_awesome_rounded,
                      size: 18,
                      color: a.ready ? AppColors.goldBright : AppColors.textMuted),
                ]),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(s.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: a.ready ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 9.5,
                      height: 1.1,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}
