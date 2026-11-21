part of '../harvest_games.dart';

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
