part of '../harvest_games.dart';

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
