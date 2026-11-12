import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rules/harvest_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 채집 미니게임 화면 (11-11 #56). 끝나면 결과(실패·좋음·완벽)를 돌려준다.
class HarvestGameScreen extends StatelessWidget {
  const HarvestGameScreen({super.key, required this.kind, this.ease = 0});

  final HarvestKind kind;

  /// 도구 등급 (0~3): 높을수록 판정이 넉넉하다 (11-11 #83, 숨김)
  final int ease;

  @override
  Widget build(BuildContext context) {
    final info = HarvestRules.info(kind);
    void done(HarvestGrade g) => Navigator.of(context).pop(g);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${info.name} · ${info.game}',
                      textAlign: TextAlign.center, style: AppText.title(22)),
                  const SizedBox(height: 6),
                  KText(info.gameHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: switch (kind) {
                      HarvestKind.herb => _TimingGame(onDone: done, ease: ease),
                      HarvestKind.ore => _TapRockGame(onDone: done, ease: ease),
                      HarvestKind.wood => _HoldGame(onDone: done, ease: ease),
                      HarvestKind.water => _FishingGame(onDone: done),
                      HarvestKind.mushroom =>
                        _MushroomGame(onDone: done, ease: ease),
                      HarvestKind.flower => _FlowerGame(onDone: done, ease: ease),
                      HarvestKind.gem => _CrackGame(onDone: done, ease: ease),
                      HarvestKind.relic => _BrushGame(onDone: done, ease: ease),
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
  const _TimingGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_TimingGame> createState() => _TimingGameState();
}

class _TimingGameState extends State<_TimingGame>
    with SingleTickerProviderStateMixin, _Finish {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  int tries = 0, hits = 0;
  (double, double) get zone =>
      (0.42 - 0.025 * widget.ease, 0.58 + 0.025 * widget.ease);

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
        GlyphDots(filled: hits, total: tries, blank: 3 - tries, size: 18),
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
    canvas.drawRRect(r, Paint()..color = AppColors.chipBg);
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
  const _TapRockGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_TapRockGame> createState() => _TapRockGameState();
}

class _TapRockGameState extends State<_TapRockGame> with _Finish {
  final _rng = math.Random();
  int? _glow;
  int hits = 0;
  late int left = 50 + 5 * widget.ease; // 0.1초 단위 (5초, 도구가 좋으면 더)
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
  const _HoldGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_HoldGame> createState() => _HoldGameState();
}

class _HoldGameState extends State<_HoldGame>
    with SingleTickerProviderStateMixin, _Finish {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  int tries = 0, hits = 0;
  (double, double) get zone =>
      (0.70 - 0.025 * widget.ease, 0.86 + 0.025 * widget.ease);

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
        GlyphDots(filled: hits, total: tries, blank: 3 - tries, size: 18),
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
            child: Text('누르고 있다가 떼기', style: AppText.title(19)),
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
            style: AppText.title(19)),
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
            child: Text(phase < 2 ? '당기기!' : '눌러 잡기', style: AppText.title(19)),
          ),
        ),
      ]);
}


// ───────────── 버섯: 독버섯 피해 고르기 (11-11 #83)

class _MushroomGame extends StatefulWidget {
  const _MushroomGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_MushroomGame> createState() => _MushroomGameState();
}

class _MushroomGameState extends State<_MushroomGame> with _Finish {
  final _rng = math.Random();
  late final List<bool> _poison;
  final _picked = <int>{};
  int good = 0, bad = 0;
  late int left = 60 + 10 * widget.ease; // 0.1초 단위
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // 9개 중 독버섯 4개 (도구가 좋으면 하나씩 줄어든다)
    final n = math.max(2, 4 - widget.ease);
    final idx = [for (var i = 0; i < 9; i++) i]..shuffle(_rng);
    _poison = List.filled(9, false);
    for (final i in idx.take(n)) {
      _poison[i] = true;
    }
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _end();
    });
  }

  void _end() {
    _t?.cancel();
    final score = good - bad;
    finish(
        score >= 3
            ? HarvestGrade.perfect
            : score >= 2
                ? HarvestGrade.good
                : HarvestGrade.fail,
        widget.onDone);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _pick(int i) {
    if (result != null || _picked.contains(i)) return;
    setState(() {
      _picked.add(i);
      _poison[i] ? bad++ : good++;
    });
    if (good >= 3 || bad >= 2) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('남은 시간 ${(math.max(0, left) / 10).toStringAsFixed(1)}초 · 고른 버섯 $good',
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
                    key: Key('mushroom_$i'),
                    onTap: () => _pick(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _picked.contains(i)
                            ? const Color(0xFF15183A)
                            : const Color(0xFF2B3A2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF4C6B47), width: 2),
                      ),
                      child: _picked.contains(i)
                          ? Icon(_poison[i] ? Icons.close_rounded : Icons.check_rounded,
                              color: _poison[i] ? AppColors.danger : AppColors.goldBright,
                              size: 36)
                          : CustomPaint(painter: _MushroomPainter(_poison[i])),
                    ),
                  ),
              ],
            ),
          ),
        ),
        resultText(),
      ]);
}

class _MushroomPainter extends CustomPainter {
  _MushroomPainter(this.poison);
  final bool poison;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final r = size.width * 0.28;
    // 기둥
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + Offset(0, r * 0.7), width: r * 0.7, height: r * 1.1),
            Radius.circular(r * 0.2)),
        Paint()..color = const Color(0xFFF2E6CF));
    // 갓
    final cap = Path()
      ..addArc(Rect.fromCircle(center: c + Offset(0, r * 0.2), radius: r), math.pi, math.pi)
      ..close();
    canvas.drawPath(
        cap,
        Paint()
          ..color = poison ? const Color(0xFFD9534F) : const Color(0xFFB88552));
    // 독버섯은 흰 점박이
    if (poison) {
      final dot = Paint()..color = Colors.white;
      for (final o in [Offset(-0.45, -0.25), Offset(0.1, -0.55), Offset(0.5, -0.15)]) {
        canvas.drawCircle(c + Offset(o.dx * r, o.dy * r), r * 0.14, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_MushroomPainter o) => o.poison != poison;
}

// ───────────── 꽃: 잎 안 다치게 따기 (흔들리는 꽃이 가운데일 때)

class _FlowerGame extends StatefulWidget {
  const _FlowerGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_FlowerGame> createState() => _FlowerGameState();
}

class _FlowerGameState extends State<_FlowerGame>
    with SingleTickerProviderStateMixin, _Finish {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);
  int tries = 0, hits = 0;

  /// 가운데에서 이만큼 안이면 성공 (-1~1 기준)
  double get _tol => 0.16 + 0.04 * widget.ease;

  double get _sway => (_a.value * 2 - 1);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap() {
    if (result != null) return;
    setState(() {
      tries++;
      if (_sway.abs() <= _tol) hits++;
    });
    if (tries >= 3) finish(_grade(hits, perfect: 3, good: 2), widget.onDone);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Spacer(),
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Stack(alignment: Alignment.bottomCenter, children: [
              // 가운데 표시
              Positioned(
                bottom: 0,
                child: Container(
                  width: 200 * _tol * 2,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0x337FD48B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Transform.rotate(
                angle: _sway * 0.6,
                alignment: Alignment.bottomCenter,
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_florist_rounded, size: 72, color: Color(0xFFF7A8C8)),
                  SizedBox(width: 6, height: 100, child: ColoredBox(color: Color(0xFF6FBF73))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        GlyphDots(filled: hits, total: tries, blank: 3 - tries, size: 18),
        resultText(),
        const Spacer(),
        GoldButton(key: const Key('gameTap'), label: '따기!', onPressed: _tap),
      ]);
}

// ───────────── 보석: 금 따라 깎기 (빛나는 점을 차례로)

class _CrackGame extends StatefulWidget {
  const _CrackGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_CrackGame> createState() => _CrackGameState();
}

class _CrackGameState extends State<_CrackGame> with _Finish {
  final _rng = math.Random();
  late final List<Offset> _pts;
  int next = 0, misses = 0;
  late int left = 60 + 10 * widget.ease;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // 왼쪽 위에서 오른쪽 아래로 꺾이는 금 6점
    _pts = [
      for (var i = 0; i < 6; i++)
        Offset(0.12 + i * 0.152, 0.2 + (i.isEven ? 0.12 : 0.5) + _rng.nextDouble() * 0.15),
    ];
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _end();
    });
  }

  void _end() {
    _t?.cancel();
    final done = next - misses;
    finish(
        done >= 6
            ? HarvestGrade.perfect
            : done >= 4
                ? HarvestGrade.good
                : HarvestGrade.fail,
        widget.onDone);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _tap(int i) {
    if (result != null) return;
    setState(() {
      if (i == next) {
        next++;
      } else {
        misses++;
      }
    });
    if (next >= _pts.length || misses >= 3) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('남은 시간 ${(math.max(0, left) / 10).toStringAsFixed(1)}초',
            style: const TextStyle(color: AppColors.text)),
        const SizedBox(height: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final r = 22.0 + 4 * widget.ease;
              return Stack(children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5F78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF8E93AB), width: 2),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrackPainter(_pts, next),
                  ),
                ),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < next
                              ? const Color(0x33FFFFFF)
                              : i == next
                                  ? const Color(0xCCF5DC94)
                                  : const Color(0x55F5DC94),
                          boxShadow: i == next
                              ? [const BoxShadow(color: Color(0xAAF5DC94), blurRadius: 14)]
                              : null,
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
        ),
        resultText(),
      ]);
}

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

// ───────────── 유물: 붓으로 흙 털기 (문질러서 칸을 털기)

class _BrushGame extends StatefulWidget {
  const _BrushGame({required this.onDone, this.ease = 0});
  final ValueChanged<HarvestGrade> onDone;
  final int ease;
  @override
  State<_BrushGame> createState() => _BrushGameState();
}

class _BrushGameState extends State<_BrushGame> with _Finish {
  static const n = 5; // 5 × 5 칸
  final _dust = List<int>.filled(n * n, 3); // 칸마다 세 번 털면 깨끗
  late int left = 70 + 10 * widget.ease;
  Timer? _t;
  int get _clean => _dust.where((d) => d <= 0).length;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _end();
    });
  }

  void _end() {
    _t?.cancel();
    final c = _clean;
    finish(
        c >= n * n - 2
            ? HarvestGrade.perfect
            : c >= n * n * 0.6
                ? HarvestGrade.good
                : HarvestGrade.fail,
        widget.onDone);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _brush(Offset local, Size size) {
    if (result != null) return;
    final cx = (local.dx / size.width * n).floor();
    final cy = (local.dy / size.height * n).floor();
    if (cx < 0 || cy < 0 || cx >= n || cy >= n) return;
    final i = cy * n + cx;
    if (_dust[i] <= 0) return;
    setState(() => _dust[i] -= 1 + (widget.ease >= 2 ? 1 : 0));
    if (_clean >= n * n) _end();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('남은 시간 ${(math.max(0, left) / 10).toStringAsFixed(1)}초 · 털어 낸 곳 $_clean / ${n * n}',
            style: const TextStyle(color: AppColors.text)),
        const SizedBox(height: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                key: const Key('brushArea'),
                onPanUpdate: (d) => _brush(d.localPosition, size),
                onTapDown: (d) => _brush(d.localPosition, size),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(children: [
                    // 묻혀 있던 유물
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0xFFCDB58A),
                        child: Icon(Icons.account_balance_rounded,
                            size: 120, color: Color(0xFF8A6A3E)),
                      ),
                    ),
                    for (var i = 0; i < n * n; i++)
                      Positioned(
                        left: (i % n) * size.width / n,
                        top: (i ~/ n) * size.height / n,
                        width: size.width / n + 0.5,
                        height: size.height / n + 0.5,
                        child: ColoredBox(
                          color: const Color(0xFF6B4E2E)
                              .withValues(alpha: (_dust[i].clamp(0, 3)) / 3),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ),
        ),
        resultText(),
      ]);
}
