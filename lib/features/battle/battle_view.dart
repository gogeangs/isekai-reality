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

part 'battle_view/buttons.dart';
part 'battle_view/scene.dart';
part 'battle_view/stage_parts.dart';
part 'battle_view/sprites.dart';

part 'battle_view/view_helpers.dart';

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
    this.bar,
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

  /// 묶음 85 #420: 각성 뒤 버튼 줄 4칸 (왼쪽부터 칸 3 · 칸 4 · 칸 1 · 칸 2). 'base:bash' · 'base:stance' ·
  /// 'job:<스킬>' · 'mastery:<숙련도>' · '' (빈 칸). null 이면 예전 줄 (강타 · 방어 태세 · 칸 2 · 펫)
  final List<String>? bar;

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

  /// 자동 마시기 창: 전투를 잠깐 멈추고, 닫으면 이어 간다 (11-11 #93)
  Future<void> _autoWindow() async {
    _timer?.cancel();
    _paused = true;
    await showAutoUseWindow(context,
        hp: _b.autoHp,
        cure: _b.autoCure,
        mp: _b.jobMpMax > 0 ? _b.autoMp : null,
        onMpChanged: (v) {
          _b.autoMp = v;
          _b.onAutoMpChanged?.call(v);
        }, onChanged: (hp, cure) {
      _b
        ..autoHp = hp
        ..autoCure = cure;
      widget.onAutoChanged?.call(hp, cure);
    });
    if (!mounted) return;
    setState(() => _paused = false);
    if (!_b.isOver && !_tipOpen) _afterTick(first: true);
  }

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

  /// 묶음 85 #420: 각성 뒤 칸 하나 (강타 · 방어 태세 · 직업 스킬 · 숙련 스킬 · 빈 칸)
  Widget _barCell(List<String> bar, int i) {
    final e = bar[i];
    Widget guard() => _GuardButton(
          key: const Key('guardButton'),
          clock: _warnClock,
          window: Battle.guardWindow * _b.guardEase,
          perfect: Battle.guardWindow - Battle.perfectFrom,
          done: _tapped,
        );
    // 강한 공격 경고 동안 「막기!」 자리: 방어 태세 칸 → 없으면 첫 칸
    if (_guardTime && (e == 'base:stance' || (!bar.contains('base:stance') && i == 0))) return guard();
    if (e == 'base:bash') {
      return _MiniSkill(
        key: const Key('bashButton'),
        label: '강타',
        icon: Icons.gavel_rounded,
        art: 'btn_strike',
        ratio: _b.bashRatio,
        ready: _b.bashReady && !_guardTime,
        onPressed: _bash,
      );
    }
    if (e == 'base:stance') {
      return _MiniSkill(
        key: const Key('stanceButton'),
        label: _b.stanceTurns > 0 ? '방어 중' : '방어 태세',
        icon: Icons.shield_rounded,
        art: 'btn_guard',
        ratio: _b.stanceTurns > 0 ? 1 : _b.stanceRatio,
        ready: _b.stanceReady,
        active: _b.stanceTurns > 0,
        onPressed: _stance,
      );
    }
    if (e.startsWith('job:')) {
      for (final (sk, cost, power) in widget.jobSkills) {
        if ('job:${sk.name}' != e) continue;
        final mp = widget.jobMp?.call() ?? 0;
        return _MiniSkill(
          key: Key('battleJob_${sk.name}'),
          label: JobRules.skill(sk).name,
          sub: 'MP $cost',
          icon: Icons.bolt_rounded,
          artFrame: SkillArt.jobIcon(sk, dim: !(mp >= cost && !_b.isOver && !_b.skillsLocked)),
          ratio: cost <= 0 ? 1 : (mp / cost).clamp(0.0, 1.0),
          ready: mp >= cost && !_b.isOver && !_b.skillsLocked && !_guardTime,
          ringColor: const Color(0xFFB27BFF),
          onPressed: () => _jobSkill(sk, cost, power),
        );
      }
    }
    if (e.startsWith('mastery:')) {
      for (final m in _b.masteryActives) {
        if ('mastery:${m.name}' != e) continue;
        return _MiniSkill(
          key: Key('battleMastery_${m.name}'),
          label: JobRules.masteryActive(m).name,
          icon: Icons.auto_awesome,
          artFrame: SkillArt.masteryIcon(m, active: true, dim: !_b.masteryReady(m)),
          ratio: _b.masteryRatio(m),
          ready: _b.masteryReady(m) && !_guardTime,
          onPressed: () => _masterySkill(m),
        );
      }
    }
    return _MiniSkill(
      key: Key('battleEmpty_$i'),
      label: '빈 칸',
      icon: Icons.add_rounded,
      art: 'btn_skill_empty',
      ratio: 0,
      ready: false,
      onPressed: () {},
    );
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
                // 묶음 85 #415: 몬스터 HP는 머리 위로
                bossHud: foe.isBoss,
                foeHud: widget.practiceHud
                    ? _EndlessDummy(beat: _beat, element: foe.element)
                    : _FoeHud(
                        name: foe.name,
                        nameColor: modGradeColor(foe.grade),
                        element: foe.element,
                        hp: _b.foeHp,
                        maxHp: foe.maxHp,
                        boss: foe.isBoss,
                        // 묶음 59: 레이드 보스 체력은 숫자 없이 (숨은 값)
                        hideNumbers: _b.raidBoss != null || _b.hideFoeNumbers,
                        status: _foeStatus,
                        // 묶음 77 #346 현자: 몬스터 약점 속성이 늘 보임
                        weak: _b.shownWeakness,
                      ),
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
                  // 묶음 85 #415: 아래 칸은 내 얼굴 · 이름 · HP를 가로 가득 (몬스터 HP는 머리 위로)
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
                  ]),
                  // 다음 줄: 내 상태 이상 · 물약 · 자동 마시기 (HP 숫자를 가리지 않게)
                  if (_heroStatus.isNotEmpty || (_b.potions.isNotEmpty && !_b.isOver))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const SizedBox(width: 52),
                        Expanded(child: _StatusIcons(_heroStatus)),
                        if (_b.potions.isNotEmpty && !_b.isOver) ...[
                          GestureDetector(
                            key: const Key('battlePotion'),
                            onTap: _potionSheet,
                            child: Image.asset('assets/images/btn_potion.webp',
                                width: 30,
                                height: 30,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.local_drink_rounded,
                                    color: AppColors.goldBright)),
                          ),
                          const SizedBox(width: 6),
                          // 물약 줄 끝 작은 「자동」 표시 (11-11 #93)
                          GestureDetector(
                            key: const Key('battleAuto'),
                            onTap: _autoWindow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: _autoOn
                                        ? AppColors.goldBright
                                        : AppColors.textMuted
                                            .withValues(alpha: 0.5)),
                              ),
                              child: Text(autoUseLabel(_b.autoHp, _b.autoCure, mp: _b.jobMpMax > 0 ? _b.autoMp : 0, short: true),
                                  style: TextStyle(
                                      color: _autoOn
                                          ? AppColors.goldBright
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
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
                    if (widget.bar case final bar?)
                      for (var i = 0; i < bar.length; i++) Expanded(child: _barCell(bar, i))
                    else ...[
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
                    ],
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

}

// ───────────────────────────────────────────── 전투 장면
