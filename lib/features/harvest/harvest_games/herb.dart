part of '../harvest_games.dart';

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
