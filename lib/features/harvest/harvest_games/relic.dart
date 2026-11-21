part of '../harvest_games.dart';

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
                  // 묶음 48: 흙판 그림(칸 전체)을 구덩이 모양으로 잘라 덮개로 씀
                  child: ClipPath(
                    key: const Key('relicPit'),
                    clipper: _PitClipper(),
                    child: Stack(children: [
                      // 구덩이 바닥 (유물 둘레가 비어 보이지 않게)
                      const Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: RadialGradient(colors: [
                        Color(0xFF6B4A2C),
                        Color(0xFF3A2414),
                      ])))),
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
