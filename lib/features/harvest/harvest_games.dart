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
    final size = MediaQuery.sizeOf(context);
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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size.height * 0.6,
            child: _img(_bgOf(widget.kind),
                key: const Key('harvestBg'),
                fit: BoxFit.cover,
                fallback: _img(_bgFallback(widget.kind), fit: BoxFit.cover)),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x66070818),
                      const Color(0x33070818),
                      const Color(0xCC070818),
                      AppColors.deepNight,
                    ],
                    stops: const [0, 0.25, 0.5, 0.62],
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

class _QuitButton extends StatelessWidget {
  const _QuitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('harvestQuit'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0B0D26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.close_rounded, size: 16, color: AppColors.goldBright),
            SizedBox(width: 3),
            Text('그만두기',
                style: TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// 「도구 → 받을 재료」 한 줄 (귀한 재료는 검은 실루엣 + 금빛 테두리)
class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.tool, required this.toolName, required this.base});

  final String? tool;
  final String toolName;
  final MaterialId base;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700);
    return FittedBox(
      key: const Key('harvestToolLine'),
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xAA0B0D26),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (tool != null)
            _img(tool!,
                width: 22,
                height: 22,
                fallback: const Icon(Icons.handyman_rounded,
                    size: 18, color: AppColors.goldBright)),
          const SizedBox(width: 4),
          Text(toolName, style: style),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded,
                size: 15, color: AppColors.goldBright),
          ),
          MaterialIcon(base, size: 22),
          const SizedBox(width: 3),
          Text(Materials.info(base).name, style: style),
          const Text(' · ', style: style),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF07070C),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBright, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.goldBright.withValues(alpha: 0.4),
                    blurRadius: 6),
              ],
            ),
            child: const Text('?',
                style: TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 3),
          const Text('귀한 재료?', style: style),
        ]),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
          decoration: BoxDecoration(
            color: const Color(0x99070818),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text,
            key: const Key('harvestHint'),
            maxLines: 1,
            style: const TextStyle(
                color: Color(0xFFE6DCC4),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ),
      );
}

/// 처음 할 때만: 큰 말풍선 설명 + 「시작!」
class _FirstBubble extends StatelessWidget {
  const _FirstBubble({required this.text, required this.tool, required this.onStart});

  final String text;
  final String? tool;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              key: const Key('harvestFirstBubble'),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E7CC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB08A4A), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 14),
                ],
              ),
              child: Row(children: [
                if (tool != null) ...[
                  _img(tool!, width: 48, height: 48),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: KText(text,
                      style: const TextStyle(
                          color: Color(0xFF3A2614),
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            GoldButton(
                key: const Key('gameStart'), label: '시작!', onPressed: onStart),
          ]),
        ),
      );
}

/// 맞출 때마다 금빛으로 차는 칸 (3번 하는 게임)
class _Cells extends StatelessWidget {
  const _Cells({required this.results});

  /// 칸마다: null 아직 · true 맞춤 · false 놓침
  final List<bool?> results;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('harvestCells'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final r in results)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: r == true
                    ? const LinearGradient(
                        colors: [Color(0xFFFFE7A3), Color(0xFFE0A93A)])
                    : null,
                color: r == true
                    ? null
                    : r == false
                        ? const Color(0xFF3A2A2A)
                        : const Color(0xFF1C1F3A),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: r == true
                        ? const Color(0xFF8A5A14)
                        : AppColors.gold.withValues(alpha: 0.5)),
                boxShadow: r == true
                    ? [
                        BoxShadow(
                            color: AppColors.goldBright.withValues(alpha: 0.6),
                            blurRadius: 8),
                      ]
                    : null,
              ),
            ),
        ],
      );
}

/// 금빛으로 차는 막대 (드러난 정도 · 남은 시간)
class _FillBar extends StatelessWidget {
  const _FillBar({super.key, required this.value, this.gold = true, this.label});

  final double value;
  final bool gold;
  final String? label;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (label != null) ...[
          Text(label!,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F3A),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: gold
                          ? const [Color(0xFFFFE7A3), Color(0xFFE0A93A)]
                          : const [Color(0xFFB9C3E8), Color(0xFF7884B8)]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ]);
}

/// 연속 완벽 불꽃 (숫자 없이, 다섯 개까지)
class _Flames extends StatelessWidget {
  const _Flames(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('harvestFlames'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < math.min(n, 5); i++)
            const Padding(
              padding: EdgeInsets.only(left: 1),
              child: Icon(Icons.local_fire_department_rounded,
                  size: 18,
                  color: Color(0xFFFFB347),
                  shadows: [Shadow(color: Color(0xFFFF7A00), blurRadius: 6)]),
            ),
        ],
      );
}

/// 큰 버튼 (도구 그림 + 「뽑기!」)
class _ActButton extends StatelessWidget {
  const _ActButton(
      {required this.keyName, required this.label, required this.tool, this.onTap});

  final String keyName;
  final String label;
  final String? tool;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GoldButton(
        key: Key(keyName),
        label: label,
        height: 60,
        leading: tool == null
            ? null
            : _img(tool!, width: 34, height: 34),
        onPressed: onTap,
      );
}

/// 버튼 없이 화면을 누르는 게임: 버튼 자리에 할 일 한 줄
class _TaskLine extends StatelessWidget {
  const _TaskLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('harvestTask'),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xCC12142E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(text, style: AppText.title(17)),
          ),
        ),
      );
}

/// 누르고 있는 동안 (나무 톱질 · 물가 줄 잡기)
class _HoldButton extends StatelessWidget {
  const _HoldButton(
      {required this.keyName,
      required this.label,
      required this.tool,
      required this.onDown,
      required this.onUp});

  final String keyName;
  final String label;
  final String? tool;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: Key(keyName),
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3A2E6E), Color(0xFF241B4C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.goldBright, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (tool != null) ...[
              _img(tool!, width: 32, height: 32),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppText.title(19)),
          ]),
        ),
      );
}

/// 위쪽 남은 시간 막대 (0.1초 단위 타이머, 멈춤 중엔 안 줄어듦)
mixin _Clock<T extends StatefulWidget> on State<T> {
  late int timeMax;
  late int timeLeft;
  Timer? _clock;
  bool get over;

  void startClock(int ticks, ValueNotifier<bool> paused, VoidCallback onEnd,
      {VoidCallback? onTick}) {
    timeMax = ticks;
    timeLeft = ticks;
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || over || paused.value) return;
      setState(() {
        timeLeft--;
        onTick?.call();
      });
      if (timeLeft <= 0) {
        _clock?.cancel();
        onEnd();
      }
    });
  }

  void stopClock() => _clock?.cancel();

  Widget timeBar() => _FillBar(
      key: const Key('harvestTime'),
      value: timeLeft / timeMax,
      gold: false,
      label: '남은 시간');
}

// ───────────── 약초: 타이밍 뽑기 — 맞출 때마다 약초가 올라와 뿌리가 드러나고 세 번째에 쑥

class _HerbGame extends StatefulWidget {
  const _HerbGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_HerbGame> createState() => _HerbGameState();
}

class _HerbGameState extends State<_HerbGame> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  final _res = <bool>[];
  bool get _over => _res.length >= 3;
  (double, double) get zone =>
      (0.42 - 0.025 * widget.ctl.ease, 0.58 + 0.025 * widget.ctl.ease);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap() {
    if (_over) return;
    final v = _a.value;
    final hit = v >= zone.$1 && v <= zone.$2;
    widget.ctl.feel.tap();
    if (hit) widget.ctl.feel.sfx(SfxKind.pluck);
    setState(() => _res.add(hit));
    if (_over) {
      _a.stop();
      final hits = _res.where((x) => x).length;
      widget.ctl.onDone(HarvestPlay(_grade(hits, perfect: 3, good: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = _res.where((x) => x).length;
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final h = box.maxHeight;
          final w = math.min(box.maxWidth, h * 0.9);
          // 맞출 때마다 조금씩 올라오고, 세 번 다 맞추면 쑥 뽑힘
          final rise = hits >= 3 ? 0.62 : hits * 0.16;
          return Center(
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                AnimatedPositioned(
                  duration: Duration(milliseconds: hits >= 3 ? 420 : 260),
                  curve: hits >= 3 ? Curves.easeOutBack : Curves.easeOut,
                  left: w * 0.18,
                  right: w * 0.18,
                  top: h * (0.30 - rise),
                  height: h * 0.72,
                  child: _img('harvest_herb_plant',
                      key: const Key('herbPlant'),
                      fallback: const _HerbPlantDraw()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: h * 0.40,
                  child: _img('harvest_herb_soil',
                      fit: BoxFit.fill, fallback: const _SoilDraw()),
                ),
              ]),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 30,
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, __) => CustomPaint(
            painter: _BarPainter(_a.value, zone.$1, zone.$2, wood: true),
            size: Size.infinite,
          ),
        ),
      ),
      const SizedBox(height: 10),
      _Cells(results: [for (var i = 0; i < 3; i++) i < _res.length ? _res[i] : null]),
      const SizedBox(height: 12),
      _ActButton(
          keyName: 'gameTap', label: '뽑기!', tool: widget.ctl.tool, onTap: _over ? null : _tap),
    ]);
  }
}

class _HerbPlantDraw extends StatelessWidget {
  const _HerbPlantDraw();
  @override
  Widget build(BuildContext context) => const Column(children: [
        Expanded(
            flex: 5,
            child: FittedBox(
                child: Icon(Icons.eco_rounded, color: Color(0xFF7FD48B)))),
        Expanded(
          flex: 4,
          child: CustomPaint(painter: _RootPainter(), size: Size.infinite),
        ),
      ]);
}

class _RootPainter extends CustomPainter {
  const _RootPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD9C29A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final c = size.width / 2;
    canvas.drawLine(Offset(c, 0), Offset(c, size.height * 0.85), p);
    for (final (dx, y) in [(-0.22, 0.3), (0.2, 0.45), (-0.16, 0.65), (0.14, 0.78)]) {
      canvas.drawLine(Offset(c, size.height * (y - 0.12)),
          Offset(c + size.width * dx, size.height * y), p..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_RootPainter o) => false;
}

class _SoilDraw extends StatelessWidget {
  const _SoilDraw();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF6B4A2E), Color(0xFF3E2A18)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.vertical(top: Radius.elliptical(200, 50)),
        ),
      );
}

/// 바늘 막대 (약초는 나무 테두리)
class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.lo, this.hi, {this.wood = false});
  final double v, lo, hi;
  final bool wood;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(
        r, Paint()..color = wood ? const Color(0xFF2A1C10) : AppColors.chipBg);
    canvas.drawRect(
        Rect.fromLTRB(size.width * lo, 2, size.width * hi, size.height - 2),
        Paint()..color = const Color(0xCC7FD48B));
    final x = size.width * v;
    canvas.drawRect(Rect.fromLTWH(x - 3, -4, 6, size.height + 8),
        Paint()..color = AppColors.goldBright);
    canvas.drawRRect(
        r,
        Paint()
          ..color = wood ? const Color(0xFF8A5A2E) : AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = wood ? 4 : 2);
    if (wood) {
      canvas.drawRRect(
          r.deflate(3),
          Paint()
            ..color = const Color(0xFF5A3A1E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v;
}

// ───────────── 꽃: 잎 안 다치게 따기 — 판마다 바람 세기가 달라 흔들림 빠르기가 바뀜

class _FlowerGame extends StatefulWidget {
  const _FlowerGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_FlowerGame> createState() => _FlowerGameState();
}

class _FlowerGameState extends State<_FlowerGame> with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  late int _wind = _rng.nextInt(HarvestRules.flowerWindMs.length);
  late final AnimationController _a = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: HarvestRules.flowerWindMs[_wind]))
    ..repeat(reverse: true);
  final _res = <bool>[];
  bool get _over => _res.length >= 3;

  /// 가운데에서 이만큼 안이면 성공 (-1~1 기준)
  double get _tol => 0.16 + 0.04 * widget.ctl.ease;
  double get _sway => (_a.value * 2 - 1);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap() {
    if (_over) return;
    final hit = _sway.abs() <= _tol;
    widget.ctl.feel.tap();
    if (hit) widget.ctl.feel.sfx(SfxKind.pluck);
    setState(() => _res.add(hit));
    if (_over) {
      _a.stop();
      final hits = _res.where((x) => x).length;
      widget.ctl.onDone(HarvestPlay(_grade(hits, perfect: 3, good: 2)));
      return;
    }
    // 다음 판은 바람이 바뀜
    _wind = _rng.nextInt(HarvestRules.flowerWindMs.length);
    _a.duration = Duration(milliseconds: HarvestRules.flowerWindMs[_wind]);
    _a.repeat(reverse: true);
  }

  String get _windLabel => switch (_wind) {
        0 => '바람 세게',
        1 => '바람 보통',
        _ => '바람 약하게',
      };

  @override
  Widget build(BuildContext context) => Column(children: [
        // 바람 줄기 표시
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3 - _wind; i++)
            const Icon(Icons.air_rounded, size: 20, color: Color(0xFFBFE6FF)),
          const SizedBox(width: 6),
          Text(_windLabel,
              key: const Key('flowerWind'),
              style: const TextStyle(
                  color: Color(0xFFBFE6FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight;
            final band = math.min(box.maxWidth, h) * _tol * 1.2;
            return AnimatedBuilder(
              animation: _a,
              builder: (_, __) =>
                  Stack(alignment: Alignment.bottomCenter, children: [
                // 가운데 금빛 표시
                Positioned(
                  bottom: 0,
                  top: h * 0.05,
                  child: Container(
                    width: band,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.goldBright.withValues(alpha: 0),
                        AppColors.goldBright.withValues(alpha: 0.28),
                        AppColors.goldBright.withValues(alpha: 0),
                      ]),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                        width: 2,
                        color: AppColors.goldBright.withValues(alpha: 0.8)),
                  ),
                ),
                Transform.rotate(
                  angle: _sway * 0.6,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: h * 0.92,
                    width: h * 0.5,
                    child: _img('harvest_flower_stem',
                        key: const Key('flowerStem'),
                        fallback: const Column(children: [
                          Expanded(
                              flex: 2,
                              child: FittedBox(
                                  child: Icon(Icons.local_florist_rounded,
                                      color: Color(0xFFF7A8C8)))),
                          Expanded(
                              flex: 3,
                              child: SizedBox(
                                  width: 6,
                                  child: ColoredBox(color: Color(0xFF6FBF73)))),
                        ])),
                  ),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 10),
        _Cells(results: [for (var i = 0; i < 3; i++) i < _res.length ? _res[i] : null]),
        const SizedBox(height: 12),
        _ActButton(
            keyName: 'gameTap', label: '따기!', tool: widget.ctl.tool, onTap: _over ? null : _tap),
      ]);
}

// ───────────── 버섯: 독버섯 피해 고르기 — 가끔 금빛 버섯 (고르면 귀한 재료 꼭)

class _MushroomGame extends StatefulWidget {
  const _MushroomGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_MushroomGame> createState() => _MushroomGameState();
}

class _MushroomGameState extends State<_MushroomGame> with _Clock {
  final _rng = math.Random();
  late final List<bool> _poison;
  int? _golden;
  final _picked = <int>{};
  int good = 0, bad = 0;
  bool _goldPicked = false;
  @override
  bool over = false;

  @override
  void initState() {
    super.initState();
    // 9개 중 독버섯 4개 (도구가 좋으면 하나씩 줄어든다)
    final n = math.max(2, 4 - widget.ctl.ease);
    final idx = [for (var i = 0; i < 9; i++) i]..shuffle(_rng);
    _poison = List.filled(9, false);
    for (final i in idx.take(n)) {
      _poison[i] = true;
    }
    if (widget.ctl.debugRare ?? _rng.nextDouble() < HarvestRules.goldMushroom) {
      _golden = idx[n + _rng.nextInt(9 - n)];
    }
    startClock(60 + 10 * widget.ctl.ease, widget.ctl.paused, _end);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  void _end() {
    if (over) return;
    stopClock();
    setState(() => over = true);
    final score = good - bad;
    final g = score >= 3
        ? HarvestGrade.perfect
        : score >= 2
            ? HarvestGrade.good
            : HarvestGrade.fail;
    widget.ctl.onDone(HarvestPlay(g, rare: _goldPicked ? true : null));
  }

  void _pick(int i) {
    if (over || _picked.contains(i)) return;
    widget.ctl.feel.tap();
    widget.ctl.feel.sfx(_poison[i] ? SfxKind.harvestFail : SfxKind.pluck,
        volume: _poison[i] ? 0.4 : 0.8);
    setState(() {
      _picked.add(i);
      _poison[i] ? bad++ : good++;
      if (i == _golden) _goldPicked = true;
    });
    if (good >= 3 || bad >= 2) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        timeBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                Positioned.fill(
                  child: _img('harvest_mushroom_bed',
                      fit: BoxFit.cover,
                      fallback: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B3A2A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      )),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: GridView.count(
                    crossAxisCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var i = 0; i < 9; i++)
                        _MushroomCell(
                          key: Key('mushroom_$i'),
                          poison: _poison[i],
                          golden: i == _golden,
                          picked: _picked.contains(i),
                          onTap: () => _pick(i),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _FillBar(value: good / 3),
        const SizedBox(height: 12),
        _TaskLine(over
            ? '다 골랐어요'
            : '버섯을 눌러 ${math.max(1, 3 - good)}개 더 골라요'),
      ]);
}

class _MushroomCell extends StatelessWidget {
  const _MushroomCell({
    super.key,
    required this.poison,
    required this.golden,
    required this.picked,
    required this.onTap,
  });

  final bool poison, golden, picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final art = golden
        ? _img('mat_moonMushroom', fallback: CustomPaint(painter: _MushroomPainter(false, gold: true)))
        : _img(poison ? 'mat_poisonMushroom' : 'mat_shadeMushroom',
            fallback: CustomPaint(painter: _MushroomPainter(poison)));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(alignment: Alignment.center, children: [
        if (golden && !picked)
          Container(
            key: const Key('goldMushroom'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.goldBright.withValues(alpha: 0.75),
                    blurRadius: 18,
                    spreadRadius: 2),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Opacity(opacity: picked && poison ? 0.45 : 1, child: art),
        ),
        if (picked)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: poison ? AppColors.danger : AppColors.goldBright,
                    width: 3),
              ),
            ),
          ),
        if (picked)
          Positioned(
            right: 2,
            top: 2,
            child: Icon(poison ? Icons.close_rounded : Icons.check_circle_rounded,
                size: 22, color: poison ? AppColors.danger : AppColors.goldBright),
          ),
      ]),
    );
  }
}

class _MushroomPainter extends CustomPainter {
  _MushroomPainter(this.poison, {this.gold = false});
  final bool poison;
  final bool gold;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final r = size.width * 0.3;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + Offset(0, r * 0.7), width: r * 0.7, height: r * 1.1),
            Radius.circular(r * 0.2)),
        Paint()..color = const Color(0xFFF2E6CF));
    final cap = Path()
      ..addArc(Rect.fromCircle(center: c + Offset(0, r * 0.2), radius: r), math.pi, math.pi)
      ..close();
    canvas.drawPath(
        cap,
        Paint()
          ..color = gold
              ? const Color(0xFFFFD36A)
              : poison
                  ? const Color(0xFFD9534F)
                  : const Color(0xFFB88552));
    if (poison) {
      final dot = Paint()..color = Colors.white;
      for (final o in [const Offset(-0.45, -0.25), const Offset(0.1, -0.55), const Offset(0.5, -0.15)]) {
        canvas.drawCircle(c + Offset(o.dx * r, o.dy * r), r * 0.14, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_MushroomPainter o) => o.poison != poison || o.gold != gold;
}

// ───────────── 광석: 약한 곳 두드리기 — 칠 때마다 금이 번지고 돌 조각이 튐, 「쨍!」

class _OreGame extends StatefulWidget {
  const _OreGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_OreGame> createState() => _OreGameState();
}

class _OreGameState extends State<_OreGame> with _Clock {
  final _rng = math.Random();
  int? _glow;
  int hits = 0;
  int _pop = 0; // 「쨍!」·조각 연출 차례
  int? _popAt;
  @override
  bool over = false;
  HarvestGrade? _g;

  @override
  void initState() {
    super.initState();
    _glow = _rng.nextInt(9);
    startClock(50 + 5 * widget.ctl.ease, widget.ctl.paused, _end, onTick: () {
      if (timeLeft % 7 == 0) _glow = _rng.nextInt(9);
    });
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  void _end() {
    if (over) return;
    stopClock();
    _g = _grade(hits, perfect: 5, good: 3);
    setState(() => over = true);
    widget.ctl.onDone(HarvestPlay(_g!));
  }

  void _hit(int i) {
    if (over) return;
    widget.ctl.feel.tap();
    if (i != _glow) return;
    widget.ctl.feel.sfx(SfxKind.ore);
    setState(() {
      hits++;
      _pop++;
      _popAt = i;
      _glow = null;
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        timeBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, box) {
                final s = box.maxWidth;
                final broken = over && _g != HarvestGrade.fail;
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: broken
                          ? _img('harvest_ore_rock_broken',
                              key: const ValueKey('broken'),
                              fallback: _img('harvest_ore_rock',
                                  fallback: const _RockDraw()))
                          : _img('harvest_ore_rock',
                              key: const ValueKey('rock'),
                              fallback: const _RockDraw()),
                    ),
                  ),
                  // 칠 때마다 금이 번짐
                  Positioned.fill(
                    child: IgnorePointer(
                        child: CustomPaint(painter: _CrackSpread(hits))),
                  ),
                  for (var i = 0; i < 9; i++)
                    Positioned(
                      left: (i % 3) * s / 3 + s * 0.04,
                      top: (i ~/ 3) * s / 3 + s * 0.04,
                      width: s / 3 - s * 0.08,
                      height: s / 3 - s * 0.08,
                      child: GestureDetector(
                        key: Key('rock_$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _hit(i),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: i == _glow && !over ? 1 : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.goldBright.withValues(alpha: 0.95),
                                AppColors.goldBright.withValues(alpha: 0.25),
                                Colors.transparent,
                              ]),
                            ),
                            child: const Icon(Icons.flare_rounded,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                  if (_popAt != null)
                    Positioned(
                      left: (_popAt! % 3) * s / 3,
                      top: (_popAt! ~/ 3) * s / 3,
                      width: s / 3,
                      height: s / 3,
                      child: IgnorePointer(
                          child: _Burst(
                              key: ValueKey('chip$_pop'),
                              colors: const [Color(0xFFB9B2A6), Color(0xFF8E8678)],
                              label: '쨍!')),
                    ),
                ]);
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _FillBar(value: hits / 5),
        const SizedBox(height: 12),
        const _TaskLine('빛나는 곳을 두드려요'),
      ]);
}

class _RockDraw extends StatelessWidget {
  const _RockDraw();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
              colors: [Color(0xFF8A8E9E), Color(0xFF4F5363)], radius: 0.8),
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: const Color(0xFF3A3D4C), width: 3),
        ),
      );
}

/// 맞힌 수만큼 금이 번진다
class _CrackSpread extends CustomPainter {
  _CrackSpread(this.n);
  final int n;
  @override
  void paint(Canvas canvas, Size size) {
    if (n <= 0) return;
    final rng = math.Random(7);
    final p = Paint()
      ..color = const Color(0xCC1A1A22)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < n * 2; i++) {
      var a = rng.nextDouble() * math.pi * 2;
      var pt = c;
      final path = Path()..moveTo(pt.dx, pt.dy);
      for (var k = 0; k < 4; k++) {
        a += (rng.nextDouble() - 0.5) * 0.9;
        pt += Offset(math.cos(a), math.sin(a)) * size.width * 0.07;
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_CrackSpread o) => o.n != n;
}

/// 조각이 튀고 글자가 떠오름 (한 번)
class _Burst extends StatelessWidget {
  const _Burst({super.key, required this.colors, this.label});

  final List<Color> colors;
  final String? label;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        builder: (context, k, _) => Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: CustomPaint(painter: _ChipsPainter(k, colors)),
          ),
          if (label != null)
            Align(
              alignment: Alignment(0, -0.2 - k * 0.6),
              child: Opacity(
                opacity: (1 - k).clamp(0.0, 1.0),
                child: Text(label!,
                    style: AppText.title(20, color: Colors.white).copyWith(
                        shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
              ),
            ),
        ]),
      );
}

class _ChipsPainter extends CustomPainter {
  _ChipsPainter(this.k, this.colors);
  final double k;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(3);
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 9; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = size.width * (0.2 + rng.nextDouble() * 0.4) * k;
      final pos = c + Offset(math.cos(a), math.sin(a)) * d + Offset(0, k * k * size.height * 0.25);
      canvas.drawCircle(
          pos,
          3 + rng.nextDouble() * 3,
          Paint()
            ..color = colors[i % colors.length].withValues(alpha: (1 - k).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_ChipsPainter o) => o.k != k;
}

// ───────────── 보석: 금 따라 깎기 — 숫자 차례로, 깎을수록 원석이 밝아짐

class _GemGame extends StatefulWidget {
  const _GemGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_GemGame> createState() => _GemGameState();
}

class _GemGameState extends State<_GemGame> with _Clock {
  final _rng = math.Random();
  late final List<Offset> _pts;
  int next = 0, misses = 0;
  @override
  bool over = false;

  @override
  void initState() {
    super.initState();
    // 원석 둘레를 도는 금 6점
    final start = _rng.nextDouble() * math.pi * 2;
    _pts = [
      for (var i = 0; i < 6; i++)
        Offset(
            0.5 + math.cos(start + i * math.pi / 3) * (0.33 + _rng.nextDouble() * 0.06),
            0.5 + math.sin(start + i * math.pi / 3) * (0.33 + _rng.nextDouble() * 0.06)),
    ];
    startClock(60 + 10 * widget.ctl.ease, widget.ctl.paused, _end);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  void _end() {
    if (over) return;
    stopClock();
    setState(() => over = true);
    final done = next - misses;
    widget.ctl.onDone(HarvestPlay(done >= 6
        ? HarvestGrade.perfect
        : done >= 4
            ? HarvestGrade.good
            : HarvestGrade.fail));
  }

  void _tap(int i) {
    if (over) return;
    widget.ctl.feel.tap();
    setState(() {
      if (i == next) {
        next++;
        widget.ctl.feel.sfx(SfxKind.gem);
      } else if (i > next) {
        misses++;
      }
    });
    if (next >= _pts.length || misses >= 3) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        timeBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                final r = 22.0 + 4 * widget.ctl.ease;
                final light = next / _pts.length;
                return Stack(children: [
                  Positioned.fill(
                    child: _img('harvest_gem_wall',
                        fit: BoxFit.cover,
                        fallback: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A5F78),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        )),
                  ),
                  // 가운데 원석: 깎을수록 밝아짐
                  Center(
                    child: Container(
                      width: w * 0.44,
                      height: h * 0.44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFBFE6FF).withValues(alpha: 0.7 * light),
                              blurRadius: 30 * light + 1,
                              spreadRadius: 6 * light),
                        ],
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_brighten(0.55 + 0.45 * light)),
                        child: _img('mat_roughGem',
                            key: const Key('gemRough'),
                            fallback: const Icon(Icons.diamond_rounded,
                                size: 80, color: Color(0xFFBFE6FF))),
                      ),
                    ),
                  ),
                  Positioned.fill(child: CustomPaint(painter: _CrackPainter(_pts, next))),
                  for (var i = 0; i < _pts.length; i++)
                    Positioned(
                      left: _pts[i].dx * w - r,
                      top: _pts[i].dy * h - r,
                      width: r * 2,
                      height: r * 2,
                      child: GestureDetector(
                        key: Key('crack_$i'),
                        onTap: () => _tap(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < next
                                ? const Color(0x33FFFFFF)
                                : i == next
                                    ? const Color(0xEEF5DC94)
                                    : const Color(0x88F5DC94),
                            border: Border.all(color: const Color(0xFF6A4410), width: 1.5),
                            boxShadow: i == next
                                ? [const BoxShadow(color: Color(0xAAF5DC94), blurRadius: 14)]
                                : null,
                          ),
                          child: i < next
                              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                              : Text('${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.goldInk,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _FillBar(value: next / _pts.length),
        const SizedBox(height: 12),
        _TaskLine(over ? '다 깎았어요' : '${next + 1}번 금을 눌러요'),
      ]);
}

/// 밝기 배율 행렬
List<double> _brighten(double k) => [
      k, 0, 0, 0, 0, //
      0, k, 0, 0, 0, //
      0, 0, k, 0, 0, //
      0, 0, 0, 1, 0,
    ];

class _CrackPainter extends CustomPainter {
  _CrackPainter(this.pts, this.done);
  final List<Offset> pts;
  final int done;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < pts.length - 1; i++) {
      p.color = i < done - 1 ? const Color(0xFFF5DC94) : const Color(0xFF2A2D3E);
      canvas.drawLine(Offset(pts[i].dx * size.width, pts[i].dy * size.height),
          Offset(pts[i + 1].dx * size.width, pts[i + 1].dy * size.height), p);
    }
  }

  @override
  bool shouldRepaint(_CrackPainter o) => o.done != done;
}

// ───────────── 나무: 톱질 — 누르고 있으면 오른쪽 막대가 차고 초록 칸에서 떼기, 톱밥이 날림

class _WoodGame extends StatefulWidget {
  const _WoodGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_WoodGame> createState() => _WoodGameState();
}

class _WoodGameState extends State<_WoodGame> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  final _res = <bool>[];
  bool get _over => _res.length >= 3;
  Timer? _sawSound;
  (double, double) get zone =>
      (0.70 - 0.025 * widget.ctl.ease, 0.86 + 0.025 * widget.ctl.ease);

  @override
  void dispose() {
    _sawSound?.cancel();
    _a.dispose();
    super.dispose();
  }

  void _down() {
    if (_over || _a.isAnimating) return;
    widget.ctl.feel.tap();
    widget.ctl.feel.sfx(SfxKind.saw, volume: 0.6);
    _sawSound?.cancel();
    _sawSound = Timer.periodic(const Duration(milliseconds: 360), (_) {
      if (mounted && _a.isAnimating) widget.ctl.feel.sfx(SfxKind.saw, volume: 0.6);
    });
    _a.forward(from: 0).then((_) => _release());
    setState(() {});
  }

  void _release() {
    _sawSound?.cancel();
    if (_over || (!_a.isAnimating && _a.value == 0)) return;
    final v = _a.value;
    _a.stop();
    final hit = v >= zone.$1 && v <= zone.$2;
    setState(() => _res.add(hit));
    _a.value = 0;
    if (_over) {
      final hits = _res.where((x) => x).length;
      widget.ctl.onDone(HarvestPlay(_grade(hits, perfect: 3, good: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = _res.where((x) => x).length;
    return Column(children: [
      Expanded(
        child: Row(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              return AnimatedBuilder(
                animation: _a,
                builder: (_, __) {
                  final sawing = _a.isAnimating;
                  final t = DateTime.now().millisecondsSinceEpoch / 140.0;
                  return Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h * 0.32,
                      height: h * 0.5,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _over && hits >= 2
                            ? _img('harvest_wood_log_split',
                                key: const ValueKey('split'),
                                fallback: _img('harvest_wood_log',
                                    fallback: const _LogDraw()))
                            : _img('harvest_wood_log',
                                key: const ValueKey('log'),
                                fallback: const _LogDraw()),
                      ),
                    ),
                    // 톱: 누르는 동안 앞뒤로
                    Positioned(
                      left: w * 0.22 + (sawing ? math.sin(t) * w * 0.06 : 0),
                      top: h * 0.06 + h * 0.18 * _a.value,
                      width: w * 0.56,
                      height: h * 0.36,
                      child: _img('harvest_wood_saw',
                          key: const Key('woodSaw'),
                          fallback: const FittedBox(
                              child: Icon(Icons.carpenter_rounded,
                                  color: Color(0xFFD9DCE6)))),
                    ),
                    if (sawing)
                      Positioned(
                        left: w * 0.3,
                        top: h * 0.45,
                        width: w * 0.4,
                        height: h * 0.3,
                        child: IgnorePointer(
                            child: CustomPaint(painter: _SawdustPainter(t))),
                      ),
                  ]);
                },
              );
            }),
          ),
          const SizedBox(width: 10),
          // 오른쪽 세로 막대 (초록 칸에서 떼기)
          SizedBox(
            width: 30,
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, __) => CustomPaint(
                key: const Key('woodBar'),
                painter: _VBarPainter(_a.value, zone.$1, zone.$2),
                size: Size.infinite,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _Cells(results: [for (var i = 0; i < 3; i++) i < _res.length ? _res[i] : null]),
      const SizedBox(height: 12),
      _HoldButton(
          keyName: 'gameHold',
          label: '누르고 있다가 떼기',
          tool: widget.ctl.tool,
          onDown: _down,
          onUp: _release),
    ]);
  }
}

class _LogDraw extends StatelessWidget {
  const _LogDraw();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB07A44), Color(0xFF6E4524)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF4A2E16), width: 3),
        ),
      );
}

class _SawdustPainter extends CustomPainter {
  _SawdustPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random((t * 3).floor());
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
          1.5 + rng.nextDouble() * 2,
          Paint()..color = const Color(0xCCE8C99A));
    }
  }

  @override
  bool shouldRepaint(_SawdustPainter o) => o.t != t;
}

class _VBarPainter extends CustomPainter {
  _VBarPainter(this.v, this.lo, this.hi);
  final double v, lo, hi;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(r, Paint()..color = AppColors.chipBg);
    double y(double f) => size.height * (1 - f);
    canvas.drawRect(Rect.fromLTRB(2, y(hi), size.width - 2, y(lo)),
        Paint()..color = const Color(0xCC7FD48B));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(4, y(v), size.width - 4, size.height - 2),
            const Radius.circular(8)),
        Paint()..color = AppColors.goldBright.withValues(alpha: 0.85));
    canvas.drawRRect(
        r,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_VBarPainter o) => o.v != v;
}

// ───────────── 물가: 찌 당기기 — 물 아래 그림자 크기로 귀한 재료를 짐작

class _WaterGame extends StatefulWidget {
  const _WaterGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_WaterGame> createState() => _WaterGameState();
}

class _WaterGameState extends State<_WaterGame> {
  final _rng = math.Random();
  Timer? _t;

  /// 시작할 때 정함: 큰 그림자 = 귀한 재료 (놓치면 없음)
  late final bool _big = widget.ctl.debugRare ??
      _rng.nextDouble() < HarvestRules.waterRareChance(widget.ctl.ease);

  /// 0 기다림, 1 찌가 가라앉음, 2 줄 잡기
  int phase = 0;
  int ticks = 0, age = 0;
  double tension = 0.5;
  bool holding = false;
  int inZone = 0; // 0.1초 단위
  bool _over = false;
  late int _dipAt = 15 + _rng.nextInt(20);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _finish(HarvestGrade g) {
    if (_over) return;
    _over = true;
    _t?.cancel();
    setState(() {});
    widget.ctl.onDone(HarvestPlay(g, rare: _big && g != HarvestGrade.fail));
  }

  void _tick() {
    if (!mounted || _over || widget.ctl.paused.value) return;
    setState(() {
      ticks++;
      age++;
      if (phase == 0 && ticks >= _dipAt) {
        phase = 1;
        ticks = 0;
        widget.ctl.feel.sfx(SfxKind.drop);
      } else if (phase == 1 && ticks > 9) {
        _finish(HarvestGrade.fail); // 놓쳤다
      } else if (phase == 2) {
        tension += holding ? 0.06 : -0.05;
        tension += (_rng.nextDouble() - 0.5) * 0.04;
        tension = tension.clamp(0.0, 1.0);
        if (tension > 0.35 && tension < 0.75) inZone++;
        if (tension >= 1) {
          _finish(inZone >= 12 ? HarvestGrade.good : HarvestGrade.fail);
        } else if (ticks >= 40) {
          _finish(inZone >= 25
              ? HarvestGrade.perfect
              : inZone >= 12
                  ? HarvestGrade.good
                  : HarvestGrade.fail);
        }
      }
    });
  }

  void _down() {
    if (_over) return;
    widget.ctl.feel.tap();
    if (phase == 0) {
      // 너무 일찍 누르면 다시 기다린다
      setState(() {
        ticks = 0;
        _dipAt = 15 + _rng.nextInt(20);
      });
    } else if (phase == 1) {
      setState(() {
        phase = 2;
        ticks = 0;
      });
    }
    holding = true;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(
            switch (phase) {
              0 => '찌를 지켜봐요…',
              1 => '퐁당! 지금 당기기!',
              _ => '줄이 끊기지 않게 눌러 잡아요',
            },
            key: const Key('waterLine'),
            style: AppText.title(19,
                color: phase == 1 ? AppColors.goldBright : AppColors.text)),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final bob = math.sin(age / 4) * 4;
            final fishX = 0.5 + math.sin(age / 13) * 0.25;
            final fishW = w * (_big ? 0.46 : 0.22);
            return Stack(clipBehavior: Clip.none, children: [
              // 물 아래 물고기 그림자
              Positioned(
                left: w * fishX - fishW / 2,
                top: h * 0.58,
                width: fishW,
                height: fishW * 0.45,
                child: Opacity(
                  opacity: 0.55,
                  child: _img('harvest_water_fish',
                      key: Key(_big ? 'fishBig' : 'fishSmall'),
                      fallback: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1A2A),
                          borderRadius: BorderRadius.circular(fishW),
                        ),
                      )),
                ),
              ),
              // 물결
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.42,
                height: 3,
                child: ColoredBox(color: const Color(0x667FD8FF)),
              ),
              // 찌 (가라앉으면 아래로)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                left: w * 0.5 - h * 0.11,
                top: h * (phase == 1 ? 0.36 : 0.26) + bob,
                width: h * 0.22,
                height: h * 0.22,
                child: _img('harvest_water_bobber',
                    key: const Key('waterBobber'),
                    fallback: const FittedBox(
                        child: Icon(Icons.radio_button_checked_rounded,
                            color: Color(0xFFE85C5C)))),
              ),
              if (phase == 1)
                Positioned(
                  left: w * 0.5 - h * 0.2,
                  top: h * 0.3,
                  width: h * 0.4,
                  height: h * 0.25,
                  child: const IgnorePointer(
                    child: _Burst(
                        key: ValueKey('splash'),
                        colors: [Color(0xFFBFE6FF), Color(0xFF7FD8FF)],
                        label: '퐁당!'),
                  ),
                ),
            ]);
          }),
        ),
        if (phase == 2)
          SizedBox(
            height: 26,
            child: CustomPaint(
              key: const Key('waterTension'),
              painter: _BarPainter(tension, 0.35, 0.75),
              size: Size.infinite,
            ),
          )
        else
          const SizedBox(height: 26),
        const SizedBox(height: 10),
        _FillBar(value: phase == 2 ? inZone / 25 : 0, label: '줄 힘'),
        const SizedBox(height: 12),
        _HoldButton(
            keyName: 'gameFish',
            label: phase < 2 ? '당기기!' : '눌러 잡기',
            tool: widget.ctl.tool,
            onDown: _down,
            onUp: () => holding = false),
      ]);
}

// ───────────── 유물: 흙 털기 — 문지른 곳의 흙이 지워지고 옛 글씨가 금빛으로

class _RelicGame extends StatefulWidget {
  const _RelicGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_RelicGame> createState() => _RelicGameState();
}

class _RelicGameState extends State<_RelicGame> with _Clock {
  static const n = 5; // 5 × 5 칸
  final _dust = List<int>.filled(n * n, 3); // 칸마다 세 번 털면 깨끗
  int get _clean => _dust.where((d) => d <= 0).length;
  @override
  bool over = false;
  int _lastSound = 0;

  @override
  void initState() {
    super.initState();
    startClock(70 + 10 * widget.ctl.ease, widget.ctl.paused, _end);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  void _end() {
    if (over) return;
    stopClock();
    setState(() => over = true);
    final c = _clean;
    widget.ctl.onDone(HarvestPlay(c >= n * n - 2
        ? HarvestGrade.perfect
        : c >= n * n * 0.6
            ? HarvestGrade.good
            : HarvestGrade.fail));
  }

  void _brush(Offset local, Size size) {
    if (over) return;
    final cx = (local.dx / size.width * n).floor();
    final cy = (local.dy / size.height * n).floor();
    if (cx < 0 || cy < 0 || cx >= n || cy >= n) return;
    final i = cy * n + cx;
    if (_dust[i] <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSound > 220) {
      _lastSound = now;
      widget.ctl.feel.tap();
      widget.ctl.feel.sfx(SfxKind.brush, volume: 0.6);
    }
    setState(() => _dust[i] -= 1 + (widget.ctl.ease >= 2 ? 1 : 0));
    if (_clean >= n * n) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        timeBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                final cw = size.width / n, ch = size.height / n;
                return GestureDetector(
                  key: const Key('brushArea'),
                  onPanUpdate: (d) => _brush(d.localPosition, size),
                  onTapDown: (d) => _brush(d.localPosition, size),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(children: [
                      // 묻혀 있던 유물 + 옛 글씨 (금빛)
                      Positioned.fill(
                        child: _img('harvest_relic_pot',
                            fit: BoxFit.cover,
                            fallback: const ColoredBox(
                              color: Color(0xFFCDB58A),
                              child: Icon(Icons.account_balance_rounded,
                                  size: 120, color: Color(0xFF8A6A3E)),
                            )),
                      ),
                      Positioned.fill(
                          child: CustomPaint(painter: _GlyphPainter())),
                      // 칸마다 흙 (털면 지워짐)
                      for (var i = 0; i < n * n; i++)
                        if (_dust[i] > 0)
                          Positioned(
                            left: (i % n) * cw,
                            top: (i ~/ n) * ch,
                            width: cw + 0.5,
                            height: ch + 0.5,
                            child: Opacity(
                              opacity: (_dust[i].clamp(0, 3)) / 3,
                              child: ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.topLeft,
                                  minWidth: size.width,
                                  maxWidth: size.width,
                                  minHeight: size.height,
                                  maxHeight: size.height,
                                  child: Transform.translate(
                                    offset: Offset(-(i % n) * cw, -(i ~/ n) * ch),
                                    child: _img('harvest_relic_dirt',
                                        fit: BoxFit.cover,
                                        width: size.width,
                                        height: size.height,
                                        fallback: const ColoredBox(
                                            color: Color(0xFF6B4E2E))),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _FillBar(
            key: const Key('relicReveal'),
            value: _clean / (n * n),
            label: '드러난 정도'),
        const SizedBox(height: 12),
        const _TaskLine('흙을 문질러 털어요'),
      ]);
}

/// 유물 위 옛 글씨 (금빛, 흙을 털면 드러남)
class _GlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final p = Paint()
      ..color = const Color(0xFFFFD36A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final o = Offset(size.width * (0.18 + col * 0.21),
            size.height * (0.3 + row * 0.2));
        final s = size.width * 0.06;
        final path = Path()..moveTo(o.dx, o.dy - s);
        for (var k = 0; k < 3; k++) {
          path.relativeLineTo((rng.nextDouble() - 0.5) * s * 1.6,
              rng.nextDouble() * s * 0.9);
        }
        canvas.drawPath(path, p);
        if (rng.nextBool()) canvas.drawCircle(o + Offset(s * 0.5, 0), s * 0.25, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter o) => false;
}

// ───────────── 결과 연출 (약 1초, 눌러서 넘김)

class _ResultFx extends StatelessWidget {
  const _ResultFx({required this.grade, required this.mats, required this.onTap});

  final HarvestGrade grade;
  final Map<MaterialId, int>? mats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fail = grade == HarvestGrade.fail;
    final perfect = grade == HarvestGrade.perfect;
    final glow = perfect
        ? const Color(0xFFFFD36A)
        : fail
            ? const Color(0xFF9A8466)
            : const Color(0xFFDDE4F5);
    return GestureDetector(
      key: const Key('harvestFx'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: HarvestRules.resultFx,
        builder: (context, k, _) {
          final burst = Curves.easeOut.transform(math.min(1, k * 1.8));
          return LayoutBuilder(builder: (context, box) {
            final c = Offset(box.maxWidth / 2, box.maxHeight * 0.42);
            // 가방 쪽(오른쪽 위)으로 날아감
            final fly = Curves.easeInCubic.transform(((k - 0.45) / 0.55).clamp(0.0, 1.0));
            final target = Offset(box.maxWidth - 40, 40);
            final list = (mats ?? const {}).entries.toList();
            return Stack(children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.6 * burst)),
              ),
              // 금빛·은빛 터짐 (실패는 부드럽게 흩어짐)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FxPainter(
                      k: k, center: c, color: glow, fail: fail, burst: burst),
                ),
              ),
              // 가운데: 결과 + 받은 재료 줄
              Positioned(
                left: 20,
                right: 20,
                top: c.dy - 80,
                child: Opacity(
                  opacity: burst,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * burst,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(gradeLabel(grade),
                          key: const Key('harvestFxLabel'),
                          textAlign: TextAlign.center,
                          style: AppText.title(34,
                                  color: fail ? const Color(0xFFD8CBB4) : glow)
                              .copyWith(shadows: [
                            const Shadow(color: Colors.black, blurRadius: 6),
                            Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 18),
                          ])),
                      if (list.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          key: const Key('harvestFxMats'),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0B0D26),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: glow.withValues(alpha: 0.8)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              for (final e in list)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  MaterialIcon(e.key, size: 30),
                                  const SizedBox(width: 4),
                                  Text('${Materials.info(e.key).name} +${e.value}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
              // 받은 재료 아이콘이 튀어나와 가방 쪽(오른쪽 위)으로 날아감
              if (!fail || list.isNotEmpty)
                for (final (i, e) in list.indexed)
                  if (fly > 0)
                    Positioned(
                      left: Offset.lerp(
                                  c + Offset((i - (list.length - 1) / 2) * 56, 40),
                                  target,
                                  fly)!
                              .dx -
                          22,
                      top: Offset.lerp(
                                  c + Offset((i - (list.length - 1) / 2) * 56, 40),
                                  target,
                                  fly)!
                              .dy -
                          22,
                      child: Opacity(
                        opacity: (1 - fly * 0.4).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1 - fly * 0.4,
                          child: MaterialIcon(e.key, size: 44),
                        ),
                      ),
                    ),
            ]);
          });
        },
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(
      {required this.k,
      required this.center,
      required this.color,
      required this.fail,
      required this.burst});

  final double k, burst;
  final Offset center;
  final Color color;
  final bool fail;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - k).clamp(0.0, 1.0);
    if (!fail) {
      canvas.drawCircle(
          center,
          size.width * 0.45 * burst,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: 0.75 * fade),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: center, radius: size.width * 0.45 * burst + 1)));
    }
    final rng = math.Random(5);
    for (var i = 0; i < (fail ? 14 : 22); i++) {
      final a = rng.nextDouble() * math.pi * 2;
      if (fail) {
        // 잎·돌가루가 흩어지며 천천히 떨어짐
        final pos = center +
            Offset(math.cos(a) * size.width * 0.25 * burst,
                -20 + k * size.height * 0.18 + rng.nextDouble() * 40 * k);
        canvas.drawCircle(
            pos,
            2.5 + rng.nextDouble() * 2.5,
            Paint()
              ..color = (i.isEven ? const Color(0xFF8FA36A) : const Color(0xFFA08C70))
                  .withValues(alpha: 0.8 * fade));
      } else {
        final d = size.width * (0.15 + rng.nextDouble() * 0.35) * burst;
        final pos = center + Offset(math.cos(a), math.sin(a)) * d;
        canvas.drawCircle(pos, 2 + rng.nextDouble() * 3,
            Paint()..color = color.withValues(alpha: fade));
      }
    }
  }

  @override
  bool shouldRepaint(_FxPainter o) => o.k != k;
}
