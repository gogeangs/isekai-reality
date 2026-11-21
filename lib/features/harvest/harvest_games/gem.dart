part of '../harvest_games.dart';

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
    // 원석 둘레를 도는 금 6점 (묶음 48: 광맥 벽 금빛 테 위)
    final start = _rng.nextDouble() * math.pi * 2;
    _pts = [
      for (var i = 0; i < 6; i++)
        Offset(
            0.5 + math.cos(start + i * math.pi / 3) * (0.21 + _rng.nextDouble() * 0.04),
            0.507 + math.sin(start + i * math.pi / 3) * (0.21 + _rng.nextDouble() * 0.04)),
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
                  // 가운데 원석: 깎을수록 밝아짐. 묶음 48: 광맥 벽 금빛 테 안 빈 홈에 얹음
                  Positioned(
                    left: w * (0.5 - 0.135),
                    top: h * (0.507 - 0.135),
                    width: w * 0.27,
                    height: h * 0.27,
                    child: Container(
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
