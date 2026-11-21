part of '../harvest_games.dart';

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
                // 묶음 48: 버섯 밭 판 그림의 3×3 빈자리에 버섯을 얹음 (그림 비율 자리)
                LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth, h = box.maxHeight;
                  const xs = [0.285, 0.495, 0.705], ys = [0.35, 0.515, 0.685];
                  final cw = w * 0.2, ch = h * 0.16;
                  return Stack(children: [
                    for (var i = 0; i < 9; i++)
                      Positioned(
                        left: xs[i % 3] * w - cw / 2,
                        top: ys[i ~/ 3] * h - ch * 0.62,
                        width: cw,
                        height: ch,
                        child: _MushroomCell(
                          key: Key('mushroom_$i'),
                          poison: _poison[i],
                          golden: i == _golden,
                          picked: _picked.contains(i),
                          onTap: () => _pick(i),
                        ),
                      ),
                  ]);
                }),
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
