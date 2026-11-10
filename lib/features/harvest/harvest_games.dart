import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rules/harvest_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 채집 미니게임 화면 (11-11 #56). 끝나면 결과(실패·좋음·완벽)를 돌려준다.
class HarvestGameScreen extends StatelessWidget {
  const HarvestGameScreen({super.key, required this.kind});

  final HarvestKind kind;

  @override
  Widget build(BuildContext context) {
    final info = HarvestRules.info(kind);
    void done(HarvestGrade g) => Navigator.of(context).pop(g);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1233),
        body: NightBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${info.name} · ${info.game}',
                      textAlign: TextAlign.center, style: AppText.title(21)),
                  const SizedBox(height: 6),
                  KText(info.gameHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: switch (kind) {
                      HarvestKind.herb => _TimingGame(onDone: done),
                      HarvestKind.ore => _TapRockGame(onDone: done),
                      HarvestKind.wood => _HoldGame(onDone: done),
                      HarvestKind.water => _FishingGame(onDone: done),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

HarvestGrade _grade(int hits, {required int perfect, required int good}) =>
    hits >= perfect
        ? HarvestGrade.perfect
        : hits >= good
            ? HarvestGrade.good
            : HarvestGrade.fail;

String gradeLabel(HarvestGrade g) => switch (g) {
      HarvestGrade.perfect => '완벽해요!',
      HarvestGrade.good => '좋아요!',
      HarvestGrade.fail => '아쉬워요',
      HarvestGrade.quick => '빠른 채집',
    };

/// 결과를 잠깐 보여 주고 끝낸다
mixin _Finish<T extends StatefulWidget> on State<T> {
  HarvestGrade? result;

  void finish(HarvestGrade g, ValueChanged<HarvestGrade> onDone) {
    if (result != null) return;
    setState(() => result = g);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) onDone(g);
    });
  }

  Widget resultText() => result == null
      ? const SizedBox(height: 30)
      : Text(gradeLabel(result!),
          textAlign: TextAlign.center,
          style: AppText.title(26,
              color: result == HarvestGrade.fail
                  ? AppColors.textMuted
                  : AppColors.goldBright));
}

// ───────────── 약초: 타이밍 뽑기

class _TimingGame extends StatefulWidget {
  const _TimingGame({required this.onDone});
  final ValueChanged<HarvestGrade> onDone;
  @override
  State<_TimingGame> createState() => _TimingGameState();
}

class _TimingGameState extends State<_TimingGame>
    with SingleTickerProviderStateMixin, _Finish {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  int tries = 0, hits = 0;
  static const zone = (0.42, 0.58);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap() {
    if (result != null) return;
    final v = _a.value;
    setState(() {
      tries++;
      if (v >= zone.$1 && v <= zone.$2) hits++;
    });
    if (tries >= 3) finish(_grade(hits, perfect: 3, good: 2), widget.onDone);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Spacer(),
        const Icon(Icons.eco_rounded, size: 90, color: Color(0xFF7FD48B)),
        const SizedBox(height: 18),
        SizedBox(
          height: 34,
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => CustomPaint(
              painter: _BarPainter(_a.value, zone.$1, zone.$2),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('${'●' * hits}${'○' * (tries - hits)}${'·' * (3 - tries)}',
            style: const TextStyle(color: AppColors.goldBright, fontSize: 20)),
        resultText(),
        const Spacer(),
        GoldButton(key: const Key('gameTap'), label: '뽑기!', onPressed: _tap),
      ]);
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.lo, this.hi);
  final double v, lo, hi;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1E2250));
    canvas.drawRect(
        Rect.fromLTRB(size.width * lo, 0, size.width * hi, size.height),
        Paint()..color = const Color(0xAA7FD48B));
    final x = size.width * v;
    canvas.drawRect(Rect.fromLTWH(x - 3, -4, 6, size.height + 8),
        Paint()..color = AppColors.goldBright);
    canvas.drawRRect(
        r,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v;
}

// ───────────── 광석: 약한 곳 두드리기

class _TapRockGame extends StatefulWidget {
  const _TapRockGame({required this.onDone});
  final ValueChanged<HarvestGrade> onDone;
  @override
  State<_TapRockGame> createState() => _TapRockGameState();
}

class _TapRockGameState extends State<_TapRockGame> with _Finish {
  final _rng = math.Random();
  int? _glow;
  int hits = 0;
  int left = 50; // 0.1초 단위 (5초)
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        left--;
        if (left % 7 == 0) _glow = _rng.nextInt(9);
      });
      if (left <= 0) {
        _t?.cancel();
        finish(_grade(hits, perfect: 5, good: 3), widget.onDone);
      }
    });
    _glow = _rng.nextInt(9);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('남은 시간 ${(math.max(0, left) / 10).toStringAsFixed(1)}초 · 깬 곳 $hits',
            style: const TextStyle(color: AppColors.text)),
        const SizedBox(height: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < 9; i++)
                  GestureDetector(
                    key: Key('rock_$i'),
                    onTap: () {
                      if (result != null || i != _glow) return;
                      setState(() {
                        hits++;
                        _glow = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B6F80),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: i == _glow ? AppColors.goldBright : const Color(0xFF3A3D4C),
                            width: i == _glow ? 4 : 2),
                        boxShadow: i == _glow
                            ? [BoxShadow(color: AppColors.goldBright.withValues(alpha: 0.6), blurRadius: 14)]
                            : null,
                      ),
                      child: Icon(i == _glow ? Icons.flare_rounded : Icons.terrain_rounded,
                          color: i == _glow ? AppColors.goldBright : const Color(0xFF9EA2B3),
                          size: 34),
                    ),
                  ),
              ],
            ),
          ),
        ),
        resultText(),
      ]);
}

// ───────────── 나무: 톱질 맞추기 (누르고 있다가 떼기)

class _HoldGame extends StatefulWidget {
  const _HoldGame({required this.onDone});
  final ValueChanged<HarvestGrade> onDone;
  @override
  State<_HoldGame> createState() => _HoldGameState();
}

class _HoldGameState extends State<_HoldGame>
    with SingleTickerProviderStateMixin, _Finish {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  int tries = 0, hits = 0;
  static const zone = (0.70, 0.86);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _release() {
    if (result != null || !_a.isAnimating && _a.value == 0) return;
    final v = _a.value;
    _a.stop();
    setState(() {
      tries++;
      if (v >= zone.$1 && v <= zone.$2) hits++;
    });
    _a.value = 0;
    if (tries >= 3) finish(_grade(hits, perfect: 3, good: 2), widget.onDone);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Spacer(),
        const Icon(Icons.forest_rounded, size: 90, color: Color(0xFFC98A4B)),
        const SizedBox(height: 18),
        SizedBox(
          height: 34,
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => CustomPaint(
              painter: _BarPainter(_a.value, zone.$1, zone.$2),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('${'●' * hits}${'○' * (tries - hits)}${'·' * (3 - tries)}',
            style: const TextStyle(color: AppColors.goldBright, fontSize: 20)),
        resultText(),
        const Spacer(),
        GestureDetector(
          key: const Key('gameHold'),
          onTapDown: (_) {
            if (result == null) _a.forward(from: 0).then((_) => _release());
          },
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2E6E),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.goldBright, width: 2),
            ),
            child: Text('누르고 있다가 떼기', style: AppText.title(18)),
          ),
        ),
      ]);
}

// ───────────── 물가: 찌 당기기

class _FishingGame extends StatefulWidget {
  const _FishingGame({required this.onDone});
  final ValueChanged<HarvestGrade> onDone;
  @override
  State<_FishingGame> createState() => _FishingGameState();
}

class _FishingGameState extends State<_FishingGame> with _Finish {
  final _rng = math.Random();
  Timer? _t;

  /// 0 기다림, 1 찌가 가라앉음, 2 줄 잡기
  int phase = 0;
  int ticks = 0;
  double tension = 0.5;
  bool holding = false;
  int inZone = 0; // 0.1초 단위
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

  void _tick() {
    if (!mounted || result != null) return;
    setState(() {
      ticks++;
      if (phase == 0 && ticks >= _dipAt) {
        phase = 1;
        ticks = 0;
      } else if (phase == 1 && ticks > 9) {
        // 놓쳤다
        _t?.cancel();
        finish(HarvestGrade.fail, widget.onDone);
      } else if (phase == 2) {
        tension += holding ? 0.06 : -0.05;
        tension += (_rng.nextDouble() - 0.5) * 0.04;
        tension = tension.clamp(0.0, 1.0);
        if (tension > 0.35 && tension < 0.75) inZone++;
        if (tension >= 1) {
          _t?.cancel();
          finish(inZone >= 12 ? HarvestGrade.good : HarvestGrade.fail, widget.onDone);
        } else if (ticks >= 40) {
          _t?.cancel();
          finish(
              inZone >= 25
                  ? HarvestGrade.perfect
                  : inZone >= 12
                      ? HarvestGrade.good
                      : HarvestGrade.fail,
              widget.onDone);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Spacer(),
        Icon(phase == 1 ? Icons.arrow_downward_rounded : Icons.water_rounded,
            size: 90,
            color: phase == 1 ? AppColors.goldBright : const Color(0xFF5CC8E0)),
        const SizedBox(height: 8),
        Text(
            switch (phase) {
              0 => '찌를 지켜보세요…',
              1 => '지금이에요!',
              _ => '줄이 끊기지 않게 눌러 잡아요',
            },
            style: AppText.title(20)),
        const SizedBox(height: 14),
        if (phase == 2)
          SizedBox(
            height: 30,
            child: CustomPaint(
              painter: _BarPainter(tension, 0.35, 0.75),
              size: Size.infinite,
            ),
          ),
        resultText(),
        const Spacer(),
        GestureDetector(
          key: const Key('gameFish'),
          onTapDown: (_) {
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
          },
          onTapUp: (_) => holding = false,
          onTapCancel: () => holding = false,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5A),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.goldBright, width: 2),
            ),
            child: Text(phase < 2 ? '당기기!' : '눌러 잡기', style: AppText.title(18)),
          ),
        ),
      ]);
}
