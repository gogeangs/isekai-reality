import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/rules/harvest_rules.dart';
import '../../core/rules/materials.dart';
import '../../data/sound/sfx.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';

part 'harvest_games/widgets.dart';
part 'harvest_games/herb.dart';
part 'harvest_games/flower.dart';
part 'harvest_games/mushroom.dart';
part 'harvest_games/ore.dart';
part 'harvest_games/gem.dart';
part 'harvest_games/wood.dart';
part 'harvest_games/water.dart';
part 'harvest_games/relic.dart';
part 'harvest_games/result_fx.dart';

/// 미니게임이 정한 것: 결과 + 귀한 재료 (금빛 버섯 · 큰 물고기 그림자. null 이면 보통처럼)
class HarvestPlay {
  const HarvestPlay(this.grade, {this.rare});

  final HarvestGrade grade;
  final bool? rare;
}

/// 미니게임 화면을 닫을 때 돌려주는 것
class HarvestGameResult {
  const HarvestGameResult(this.grade, {this.mats, this.quit = false});

  final HarvestGrade grade;

  /// 받은 재료 (화면 안에서 채집을 마쳤으면)
  final Map<MaterialId, int>? mats;

  /// 「그만두기」 → 빠른 채집으로
  final bool quit;
}

String gradeLabel(HarvestGrade g) => switch (g) {
      HarvestGrade.perfect => '완벽해요!',
      HarvestGrade.good => '좋아요!',
      HarvestGrade.fail => '아쉬워요',
      HarvestGrade.quick => '빠른 채집',
    };

/// 그림 (없으면 [fallback] — 그림이 올라오면 같은 이름으로 저절로 바뀐다)
Widget _img(String name,
        {BoxFit fit = BoxFit.contain,
        Widget fallback = const SizedBox.shrink(),
        Key? key,
        double? width,
        double? height}) =>
    Image.asset('assets/images/$name.webp',
        key: key,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            SizedBox(width: width, height: height, child: fallback));

/// 묶음 46 #234: 자리 풍경 배경 (새 그림이 오기 전엔 지금 배경)
String _bgOf(HarvestKind k) => 'bg_harvest_${k.name}';
String _bgFallback(HarvestKind k) => switch (k) {
      HarvestKind.herb ||
      HarvestKind.flower ||
      HarvestKind.mushroom ||
      HarvestKind.wood =>
        'bg_field_forest',
      HarvestKind.ore || HarvestKind.gem => 'bg_field_mountain',
      HarvestKind.water => 'bg_field_water',
      HarvestKind.relic => 'bg_dungeon_1',
    };

/// 처음 뒤에 보이는 짧은 한 줄 설명
String harvestShortHint(HarvestKind k) => switch (k) {
      HarvestKind.herb => '바늘이 초록 칸에 올 때 눌러요. 세 번!',
      HarvestKind.flower => '꽃이 금빛 줄에 올 때 눌러요. 바람을 봐요!',
      HarvestKind.mushroom => '점박이 독버섯은 피해서 세 개!',
      HarvestKind.ore => '빛나는 곳을 시간 안에 두드려요',
      HarvestKind.gem => '금을 숫자 차례대로 눌러요',
      HarvestKind.wood => '누르고 있다가 초록 칸에서 떼요',
      HarvestKind.water => '퐁당! 하면 당기고, 줄 힘을 초록 칸에',
      HarvestKind.relic => '문질러서 흙을 털어요',
    };

/// 손맛: 진동(전투와 같은 설정) · 소리(설정 「소리」, 무음이면 안 남)
class _Feel {
  const _Feel({required this.vibrate, required this.sound});

  final bool vibrate;
  final bool sound;

  /// 누를 때 짧게
  void tap() {
    if (vibrate) HapticFeedback.selectionClick();
  }

  void sfx(SfxKind k, {double volume = 0.8}) {
    if (sound) Sfx.play(k, volume: volume);
  }

  /// 결과: 좋음 한 번 · 완벽 두 번
  void result(HarvestGrade g) {
    if (g == HarvestGrade.perfect) {
      sfx(SfxKind.harvestPerfect);
      if (vibrate) {
        HapticFeedback.mediumImpact();
        Future<void>.delayed(
            const Duration(milliseconds: 140), HapticFeedback.mediumImpact);
      }
    } else if (g == HarvestGrade.good) {
      sfx(SfxKind.harvestPerfect, volume: 0.5);
      if (vibrate) HapticFeedback.mediumImpact();
    } else {
      sfx(SfxKind.harvestFail, volume: 0.6);
    }
  }
}

/// 채집 미니게임 화면 (11-11 #56 · 묶음 46 #233·#234). 끝나면 결과 연출 뒤 닫힌다.
class HarvestGameScreen extends StatefulWidget {
  const HarvestGameScreen({
    super.key,
    required this.kind,
    this.ease = 0,
    this.toolAsset,
    this.toolName,
    this.base,
    this.first = false,
    this.streak = 0,
    this.vibrate = true,
    this.sound = true,
    this.onStart,
    this.resolve,
    this.debugRare,
    this.debugResult,
    this.debugMats,
    this.debugHold = false,
  });

  /// 미리보기용: 결과 연출 뒤에도 닫지 않음
  @visibleForTesting
  final bool debugHold;

  /// 미리보기(시험·캡처)용: 금빛 버섯 · 큰 물고기 그림자를 꼭 (null 이면 보통)
  @visibleForTesting
  final bool? debugRare;

  /// 미리보기용: 시작하자마자 이 결과 연출 (받은 재료 [debugMats])
  @visibleForTesting
  final HarvestPlay? debugResult;
  @visibleForTesting
  final Map<MaterialId, int>? debugMats;

  final HarvestKind kind;

  /// 도구 등급 (0~3): 높을수록 판정이 넉넉하다 (11-11 #83, 숨김)
  final int ease;

  /// 지금 가진 도구 그림 (tool_○○_○○) · 이름 (「철 낫」)
  final String? toolAsset;
  final String? toolName;

  /// 받을 기본 재료 (없으면 그 자리 기본 재료)
  final MaterialId? base;

  /// 이 게임을 처음 하는지 (처음만 큰 설명)
  final bool first;

  /// 같은 종류 완벽 연속 (불꽃)
  final int streak;

  final bool vibrate;
  final bool sound;

  /// 게임을 시작할 때 (처음 설명을 본 것으로)
  final VoidCallback? onStart;

  /// 결과로 채집을 마친다 (받은 재료). 없으면 연출만
  final Future<Map<MaterialId, int>?> Function(HarvestPlay play)? resolve;

  @override
  State<HarvestGameScreen> createState() => _HarvestGameScreenState();
}

class _HarvestGameScreenState extends State<HarvestGameScreen> {
  late bool _started = !widget.first;
  final _paused = ValueNotifier<bool>(false);
  HarvestPlay? _play;
  Map<MaterialId, int>? _mats;
  bool _resolved = false, _fxDone = false, _closed = false;

  late final _feel = _Feel(vibrate: widget.vibrate, sound: widget.sound);

  @override
  void initState() {
    super.initState();
    if (_started) widget.onStart?.call();
    final d = widget.debugResult;
    if (d != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _done(d);
      });
    }
  }

  @override
  void dispose() {
    _paused.dispose();
    super.dispose();
  }

  void _done(HarvestPlay p) {
    if (_play != null) return;
    _feel.result(p.grade);
    setState(() => _play = p);
    final r = widget.debugResult != null
        ? (HarvestPlay _) async => widget.debugMats
        : widget.resolve;
    if (r == null) {
      _resolved = true;
    } else {
      r(p).then((m) {
        if (!mounted) return;
        setState(() {
          _mats = m;
          _resolved = true;
        });
        _maybeClose();
      });
    }
    Future<void>.delayed(HarvestRules.resultFx, () {
      _fxDone = true;
      _maybeClose();
    });
  }

  void _maybeClose() {
    if (!mounted || _closed || !_fxDone || !_resolved || widget.debugHold) return;
    _closed = true;
    Navigator.of(context).pop(HarvestGameResult(_play!.grade, mats: _mats));
  }

  /// 연출을 눌러서 넘김
  void _skip() {
    _fxDone = true;
    _maybeClose();
  }

  Future<void> _quit() async {
    if (_play != null) return;
    _paused.value = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('그만둘까요?', style: AppText.title(19)),
        content: const KText('그만두면 이번 채집은 빠른 채집으로 해요.',
            style: TextStyle(color: AppColors.text, fontSize: 14)),
        actions: [
          TextButton(
              key: const Key('harvestQuitNo'),
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('계속하기')),
          TextButton(
              key: const Key('harvestQuitYes'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('빠른 채집으로')),
        ],
      ),
    );
    _paused.value = false;
    if (ok == true && mounted && _play == null) {
      _closed = true;
      Navigator.of(context)
          .pop(const HarvestGameResult(HarvestGrade.quick, quit: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = HarvestRules.info(widget.kind);
    final ctl = _GameCtl(
        ease: widget.ease,
        feel: _feel,
        paused: _paused,
        streak: widget.streak,
        tool: widget.toolAsset,
        debugRare: widget.debugRare,
        onDone: _done);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.deepNight,
        body: Stack(children: [
          // 위쪽 60%: 그 자리 풍경, 아래로 갈수록 어둡게
          // 묶음 48: 새 배경(세로 2:3, 위 풍경 · 아래 땅)은 화면 전체에.
          // 아래 40% 땅 위에 버튼·막대가 온다
          Positioned.fill(
            child: _img(_bgOf(widget.kind),
                key: const Key('harvestBg'),
                fit: BoxFit.cover,
                fallback: _img(_bgFallback(widget.kind), fit: BoxFit.cover)),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x88070818),
                      Color(0x22070818),
                      Color(0x33070818),
                      Color(0x99070818),
                    ],
                    stops: [0, 0.25, 0.6, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _QuitButton(onTap: _quit),
                    const Spacer(),
                    if (widget.streak > 0) _Flames(widget.streak),
                  ]),
                  const SizedBox(height: 2),
                  Text('${info.name} · ${info.game}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(20)),
                  const SizedBox(height: 4),
                  _ToolLine(
                      tool: widget.toolAsset,
                      toolName: widget.toolName ?? info.toolName,
                      base: widget.base ?? info.base),
                  if (_started) ...[
                    const SizedBox(height: 4),
                    _HintLine(harvestShortHint(widget.kind)),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: _started
                        ? switch (widget.kind) {
                            HarvestKind.herb => _HerbGame(ctl: ctl),
                            HarvestKind.flower => _FlowerGame(ctl: ctl),
                            HarvestKind.mushroom => _MushroomGame(ctl: ctl),
                            HarvestKind.ore => _OreGame(ctl: ctl),
                            HarvestKind.gem => _GemGame(ctl: ctl),
                            HarvestKind.wood => _WoodGame(ctl: ctl),
                            HarvestKind.water => _WaterGame(ctl: ctl),
                            HarvestKind.relic => _RelicGame(ctl: ctl),
                          }
                        : _FirstBubble(
                            text: info.gameHint,
                            tool: widget.toolAsset,
                            onStart: () {
                              widget.onStart?.call();
                              setState(() => _started = true);
                            }),
                  ),
                ],
              ),
            ),
          ),
          if (_play != null)
            Positioned.fill(
              child: _ResultFx(
                grade: _play!.grade,
                mats: _mats,
                onTap: _skip,
              ),
            ),
        ]),
      ),
    );
  }
}

/// 게임마다 넘겨 주는 것
class _GameCtl {
  const _GameCtl({
    required this.ease,
    required this.feel,
    required this.paused,
    required this.streak,
    required this.tool,
    required this.onDone,
    this.debugRare,
  });

  final bool? debugRare;
  final int ease;
  final _Feel feel;
  final ValueNotifier<bool> paused;
  final int streak;
  final String? tool;
  final ValueChanged<HarvestPlay> onDone;
}

HarvestGrade _grade(int hits, {required int perfect, required int good}) =>
    hits >= perfect
        ? HarvestGrade.perfect
        : hits >= good
            ? HarvestGrade.good
            : HarvestGrade.fail;

// ───────────── 공통 조각

// ───────────── 약초: 타이밍 뽑기 — 맞출 때마다 약초가 올라와 뿌리가 드러나고 세 번째에 쑥

// ───────────── 꽃: 잎 안 다치게 따기 — 판마다 바람 세기가 달라 흔들림 빠르기가 바뀜

// ───────────── 버섯: 독버섯 피해 고르기 — 가끔 금빛 버섯 (고르면 귀한 재료 꼭)

// ───────────── 광석: 약한 곳 두드리기 — 칠 때마다 금이 번지고 돌 조각이 튐, 「쨍!」

// ───────────── 보석: 금 따라 깎기 — 숫자 차례로, 깎을수록 원석이 밝아짐

// ───────────── 나무: 톱질 — 누르고 있으면 오른쪽 막대가 차고 초록 칸에서 떼기, 톱밥이 날림

// ───────────── 물가: 찌 당기기 — 물 아래 그림자 크기로 귀한 재료를 짐작

// ───────────── 유물: 흙 털기 — 문지른 곳의 흙이 지워지고 옛 글씨가 금빛으로

// ───────────── 결과 연출 (약 1초, 눌러서 넘김)
